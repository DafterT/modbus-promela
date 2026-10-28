def verify(name: str, command: list[str], folder: Path, spin: Path) -> tuple[str, str]:
    try:
        output = run(command, folder, name + ".log")
        error_count = check_search_output(name, output)
        if error_count > 0:
            save_counterexample(name, folder, spin)
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
