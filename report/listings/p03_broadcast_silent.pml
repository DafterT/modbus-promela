ltl p03_broadcast_silent {
    [] ((active && slave_address == 0) ->
        (responses_sent == 0 && len(slave_responses) == 0))
}
