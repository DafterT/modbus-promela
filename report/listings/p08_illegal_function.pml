ltl p08_illegal_function {
    [] ((finished && addressed && crc_ok && function_code != FC06) ->
        (exception_response(1) && no_writes && all_unchanged))
}
