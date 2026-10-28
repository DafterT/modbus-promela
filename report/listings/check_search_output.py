def check_search_output(name: str, output: str) -> int:
    errors = re.search(r"\berrors:\s*(\d+)", output)
    limits = (
        "max search depth too small", "depth limit reached", "out of memory",
        "cannot allocate", "vectorsz is too small", "time limit reached",
    )
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
