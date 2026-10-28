ltl p02_absent_slave {
    [] ((finished && slave_address == 4) ->
        (master_state == MASTER_TIMEOUT &&
            responses_sent == 0 && no_writes && all_unchanged))
}
