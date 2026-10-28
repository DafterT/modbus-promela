"""Проверить модель и все LTL-свойства: python verify.py."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent
SPIN = Path(os.path.expandvars(r"%LOCALAPPDATA%/Programs/Spin/spin.exe"))
CC = Path("C:/msys64/ucrt64/bin/gcc.exe")


def run(command: list[str], folder: Path, log_name: str) -> str:
    """Выполнить команду, показать её и сохранить полный вывод."""
    command_text = subprocess.list2cmdline(command)
    print(f"$ {command_text}", flush=True)
    log_path = folder / log_name
    try:
        result = subprocess.run(
            command, cwd=folder, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", timeout=180,
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        log_path.write_text(command_text + "\n" + output + "\nTIMEOUT", encoding="utf-8")
        raise RuntimeError(f"Команда не закончилась за 180 с: {log_path}") from error
    except OSError as error:
        log_path.write_text(command_text + "\n" + str(error), encoding="utf-8")
        raise RuntimeError(f"Не удалось запустить команду: {log_path}") from error

    log_path.write_text(command_text + "\n\n" + result.stdout, encoding="utf-8")
    if result.returncode != 0:
        raise RuntimeError(f"Код завершения {result.returncode}: {log_path}")
    return result.stdout


def verify(name: str, command: list[str], folder: Path) -> tuple[str, str]:
    """Отличить успех, нарушение свойства и незавершённую проверку."""
    try:
        output = run(command, folder, name + ".log")
        errors = re.search(r"\berrors:\s*(\d+)", output)
        limits = (
            "max search depth too small", "depth limit reached", "out of memory",
            "cannot allocate", "vectorsz is too small", "time limit reached",
        )
        if not errors or any(text in output.lower() for text in limits):
            raise RuntimeError("Нет полного результата или достигнут предел ресурсов")
        if "Full statespace search for:" not in output:
            raise RuntimeError("SPIN не подтвердил полный поиск состояний")
        if name != "structure":
            if not re.search(r"never claim\s+\+", output):
                raise RuntimeError("LTL-проверка отключена")
            if not re.search(r"acceptance\s+cycles\s+\+", output):
                raise RuntimeError("Поиск принимающих циклов отключён")
        elif not re.search(r"invalid end states\s+\+", output):
            raise RuntimeError("Проверка конечных состояний отключена")

        if int(errors.group(1)) > 0:
            trail = folder / "properties.pml.trail"
            if not trail.exists():
                raise RuntimeError("SPIN сообщил ошибку, но не сохранил контрпример")
            saved_trail = folder / (name + ".trail")
            trail.rename(saved_trail)
            run(
                [str(SPIN), "-t", "-p", "-g", "-l", "-k", saved_trail.name,
                 "properties.pml"],
                folder, name + "_trace.log",
            )
            return "FAIL", f"Найден контрпример: {name}_trace.log"
        if "search not completed" in output.lower():
            raise RuntimeError("Поиск не завершён")

        states = re.search(r"([\d.e+]+) states, stored", output)
        depth = re.search(r"depth reached (\d+)", output)
        if not states or not depth:
            raise RuntimeError("Не удалось прочитать статистику поиска")
        return "PASS", f"состояний {states.group(1)}, глубина {depth.group(1)}, ошибок 0"
    except (OSError, RuntimeError) as error:
        return "ERROR", f"{error}; см. {name}.log"


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    # GCC нужны DLL из его каталога, в том числе при запуске дочерних программ.
    os.environ["PATH"] = str(CC.parent) + os.pathsep + os.environ.get("PATH", "")
    results = ROOT / "verification_results"
    results.mkdir(exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix="run_", dir=results))
    print(f"Результаты: {folder}", flush=True)

    try:
        # Каждый запуск получает свои копии исходников, логи и контрпримеры.
        for filename in ("modbus.pml", "properties.pml"):
            shutil.copy2(ROOT / filename, folder / filename)
        properties = re.findall(
            r"^ltl\s+(\w+)\s*\{",
            (folder / "properties.pml").read_text(encoding="utf-8"), re.MULTILINE,
        )
        if not properties:
            raise RuntimeError("В properties.pml не найдены LTL-свойства")

        print(run([str(SPIN), "-V"], folder, "spin_version.log").strip())
        run([str(CC), "--version"], folder, "gcc_version.log")
        run([str(SPIN), "-a", "properties.pml"], folder, "generate.log")
        run(
            [str(CC), "-O2", "-DCOLLAPSE", "-DSAFETY", "-DNOCLAIM",
             "-o", "pan_safety.exe", "pan.c"], folder, "compile_safety.log",
        )
        run(
            [str(CC), "-O2", "-DCOLLAPSE", "-o", "pan_ltl.exe", "pan.c"],
            folder, "compile_ltl.log",
        )
    except (OSError, RuntimeError) as error:
        message = f"ERROR: подготовка проверки не удалась: {error}"
        print(message)
        (folder / "report.txt").write_text(message + "\n", encoding="utf-8")
        return 2

    checks = [
        ("structure", [str(folder / "pan_safety.exe"), "-m10000", "-w22", "-q", "-b"])
    ]
    for name in properties:
        checks.append((name, [str(folder / "pan_ltl.exe"), "-a", "-N", name,
                              "-m10000", "-w22", "-b"]))

    counts = {"PASS": 0, "FAIL": 0, "ERROR": 0}
    lines = []
    for number, (name, command) in enumerate(checks, start=1):
        print(f"\nПроверка {number}/{len(checks)}: {name}", flush=True)
        status, detail = verify(name, command, folder)
        counts[status] += 1
        line = f"[{status}] {name}: {detail}"
        lines.append(line)
        print(line, flush=True)

    summary = (f"ИТОГ: всего {len(checks)}; PASS={counts['PASS']}, "
               f"FAIL={counts['FAIL']}, ERROR={counts['ERROR']}.")
    lines.append(summary)
    (folder / "report.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\n{summary}\nОтчёт: {folder / 'report.txt'}")
    if counts["ERROR"]:
        return 2
    return 1 if counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
