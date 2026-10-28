ltl p01_crc_ignored {
    [] ((finished && !crc_ok) ->
        (responses_sent == 0 && no_writes && all_unchanged &&
            ((slave_address == 0 && master_state == MASTER_BROADCAST_DONE) ||
             (slave_address != 0 && master_state == MASTER_TIMEOUT))))
}
