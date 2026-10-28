ltl p06_write_isolation {
    [] ((finished && addressed) -> (isolated(1) && isolated(2) && isolated(3)))
}
