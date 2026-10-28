import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent


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


def prepare_files(folder: Path) -> tuple[Path, Path, list[str]]:
    """Скопировать входные файлы, прочитать пути к программам и имена свойств."""
    # Копирывание исходников
    for filename in ("modbus.pml", "properties.pml", "config.json"):
        shutil.copy2(ROOT / filename, folder / filename)

    config = json.loads((folder / "config.json").read_text(encoding="utf-8"))
    spin = Path(os.path.expandvars(config["spin"]))
    cc = Path(os.path.expandvars(config["cc"]))

    # Обновление path
    os.environ["PATH"] = str(cc.parent) + os.pathsep + os.environ.get("PATH", "")

    # Чтение ltl
    source = (folder / "properties.pml").read_text(encoding="utf-8")
    # Поиск всех ltl формул
    properties = re.findall(r"^ltl\s+(\w+)\s*\{", source, re.MULTILINE)
    if not properties:
        raise RuntimeError("В properties.pml не найдены LTL-свойства")
    return spin, cc, properties


def build_verifiers(folder: Path, spin: Path, cc: Path) -> None:
    """Сгенерировать pan.c и собрать программы для структурной и LTL-проверок."""
    # Запись версий в логи
    run([str(spin), "-V"], folder, "spin_version.log") # spin -V
    run([str(cc), "--version"], folder, "gcc_version.log") # gcc --version
    # Создание SPIN верификатора
    run([str(spin), "-a", "properties.pml"], folder, "generate.log") # spin -a properties.pml
    # Компиляция для проверки конечных состояний
    run( # gcc -O2 -DCOLLAPSE -DSAFETY -DNOCLAIM -o pan_safety.exe pan.c
        [str(cc), "-O2", "-DCOLLAPSE", "-DSAFETY", "-DNOCLAIM",
         "-o", "pan_safety.exe", "pan.c"], folder, "compile_safety.log",
    )
    # Компиляция для проверки ltl свойств
    run( # gcc -O2 -DCOLLAPSE -o pan_ltl.exe pan.c
        [str(cc), "-O2", "-DCOLLAPSE", "-o", "pan_ltl.exe", "pan.c"],
        folder, "compile_ltl.log",
    )


def check_search_output(name: str, output: str) -> int:
    """Проверить режим поиска и прочитать число найденных нарушений."""
    errors = re.search(r"\berrors:\s*(\d+)", output)
    limits = (
        "max search depth too small", "depth limit reached", "out of memory",
        "cannot allocate", "vectorsz is too small", "time limit reached",
    )
    # Ноль ошибок ещё не означает успех, если поиск упёрся в предел ресурсов.
    if not errors or any(text in output.lower() for text in limits):
        raise RuntimeError("Нет полного результата или достигнут предел ресурсов")
    if "Full statespace search for:" not in output:
        raise RuntimeError("SPIN не подтвердил полный поиск состояний")

    if name == "structure":
        if not re.search(r"invalid end states\s+\+", output):
            raise RuntimeError("Проверка конечных состояний отключена")
    else:
        if not re.search(r"never claim\s+\+", output):
            raise RuntimeError("LTL-проверка отключена")
        if not re.search(r"acceptance\s+cycles\s+\+", output):
            raise RuntimeError("Поиск принимающих циклов отключён")
    return int(errors.group(1))


def save_counterexample(name: str, folder: Path, spin: Path) -> None:
    """Сохранить контрпример под именем проверки и получить пошаговый разбор."""
    trail = folder / "properties.pml.trail"
    if not trail.exists():
        raise RuntimeError("SPIN сообщил ошибку, но не сохранил контрпример")

    # Иначе следующая неудачная проверка перезапишет тот же файл .trail.
    saved_trail = folder / (name + ".trail")
    trail.rename(saved_trail)
    run(
        [str(spin), "-t", "-p", "-g", "-l", "-k", saved_trail.name,
         "properties.pml"],
        folder, name + "_trace.log",
    )


def verify(name: str, command: list[str], folder: Path, spin: Path) -> tuple[str, str]:
    """Вернуть PASS (успех), FAIL (нарушение) или ERROR (сбой проверки)."""
    try:
        output = run(command, folder, name + ".log")
        error_count = check_search_output(name, output)

        # Найденного контрпримера достаточно для FAIL: обходить весь граф не нужно.
        if error_count > 0:
            save_counterexample(name, folder, spin)
            return "FAIL", f"Найден контрпример: {name}_trace.log"
        if "search not completed" in output.lower():
            raise RuntimeError("Поиск не завершён")

        # PASS выдаём только после завершённого поиска без нарушений.
        states = re.search(r"([\d.e+]+) states, stored", output)
        depth = re.search(r"depth reached (\d+)", output)
        if not states or not depth:
            raise RuntimeError("Не удалось прочитать статистику поиска")
        return "PASS", f"состояний {states.group(1)}, глубина {depth.group(1)}, ошибок 0"
    except (OSError, RuntimeError) as error:
        return "ERROR", f"{error}; см. {name}.log"


def run_checks(folder: Path, spin: Path, properties: list[str]) -> int:
    """Выполнить проверки по очереди, показать результаты и записать общий отчёт."""
    # Подготовка проверок
    checks = [ # Проверка блокировок модели
        # pan_safety.exe -m1000000 -w22 -q -b
        ("structure", [str(folder / "pan_safety.exe"), "-m1000000", "-w22", "-q", "-b"])
    ]
    for name in properties: # Проверки ltl
        # pan_ltl.exe -a -N name -m1000000 -w22 -b
        checks.append((name, [str(folder / "pan_ltl.exe"), "-a", "-N", name,
                              "-m1000000", "-w22", "-b"]))

    counts = {"PASS": 0, "FAIL": 0, "ERROR": 0}
    lines = []
    for number, (name, command) in enumerate(checks, start=1):
        print(f"\nПроверка {number}/{len(checks)}: {name}", flush=True)
        status, detail = verify(name, command, folder, spin)
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
    if counts["FAIL"]:
        return 1
    return 0


def main() -> int:
    """Подготовить отдельную папку запуска, собрать верификаторы и начать проверки."""
    sys.stdout.reconfigure(encoding="utf-8")
    # Подготовка папки
    results = ROOT / "verification_results"
    results.mkdir(exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix="run_", dir=results))
    print(f"Результаты: {folder}", flush=True)

    try:
        spin, cc, properties = prepare_files(folder)
        build_verifiers(folder, spin, cc)
    except (OSError, RuntimeError, ValueError, KeyError, TypeError) as error:
        message = f"ERROR: подготовка проверки не удалась: {error}"
        print(message)
        (folder / "report.txt").write_text(message + "\n", encoding="utf-8")
        return 2

    return run_checks(folder, spin, properties)


if __name__ == "__main__":
    sys.exit(main())
