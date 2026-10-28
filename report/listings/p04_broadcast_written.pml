ltl p04_broadcast_written {
    [] ((finished && slave_address == 0 && valid_write) ->
        (master_state == MASTER_BROADCAST_DONE &&
            slave_write_performed[1] && slave_write_performed[2] && slave_write_performed[3] && 
            written(1) && written(2) && written(3)))
}
