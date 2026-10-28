ltl p09_illegal_register {
    [] (
        (finished && addressed && crc_ok &&
            function_code == FC06 && register_address > 1) ->
        (exception_response(2) && no_writes && all_unchanged)
    )
}
