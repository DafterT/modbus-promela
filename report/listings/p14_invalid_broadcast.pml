ltl p14_invalid_broadcast {
    [] ((finished && slave_address == 0 && !valid_write) ->
        (master_state == MASTER_BROADCAST_DONE && responses_sent == 0 &&
            len(slave_responses) == 0 && no_writes && all_unchanged))
}
