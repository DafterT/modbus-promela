def prepare_files(folder: Path) -> tuple[Path, Path, list[str]]:
    for filename in ("modbus.pml", "properties.pml", "config.json"):
        shutil.copy2(ROOT / filename, folder / filename)
    config = json.loads((folder / "config.json").read_text(encoding="utf-8"))
    spin = Path(os.path.expandvars(config["spin"]))
    cc = Path(os.path.expandvars(config["cc"]))
    os.environ["PATH"] = str(cc.parent) + os.pathsep + os.environ.get("PATH", "")
    source = (folder / "properties.pml").read_text(encoding="utf-8")
    properties = re.findall(r"^ltl\s+(\w+)\s*\{", source, re.MULTILINE)
    if not properties:
        raise RuntimeError("В properties.pml не найдены LTL-свойства")
    return spin, cc, properties
