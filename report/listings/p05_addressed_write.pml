ltl p05_addressed_write {
    [] ((finished && addressed && valid_write) ->
        (master_state == MASTER_RESPONSE && response_exception_code == 0 &&
            ((slave_address == 1 && slave_write_performed[1] && written(1)) ||
             (slave_address == 2 && slave_write_performed[2] && written(2)) ||
             (slave_address == 3 && slave_write_performed[3] && written(3)))))
}
