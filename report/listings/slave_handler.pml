if
:: (request_slave_address == slave_id || request_slave_address == 0) ->
    if
    :: request_crc_ok ->
        if
        :: (request_function_code != FC06) -> exception_code = 1
        :: else ->
            if
            :: (request_register_address > 1) -> exception_code = 2
            :: else ->
                atomic {
                    if
                    :: (request_register_address == 0) ->
                        holding_register_0[slave_id] = request_register_value
                    :: else ->
                        holding_register_1[slave_id] = request_register_value
                    fi;
                    slave_write_performed[slave_id] = true;
                }
            fi
        fi;
        if
        :: (request_slave_address == 0) -> skip
        :: else ->
            if
            :: (exception_code == 0) ->
                atomic {
                    slave_responses!slave_id, request_function_code,
                        request_register_address, request_register_value, 0;
                    responses_sent++;
                }
            :: else ->
                atomic {
                    slave_responses!slave_id, (request_function_code + 128),
                        0, 0, exception_code;
                    responses_sent++;
                }
            fi
        fi
    :: else -> skip
    fi
:: else -> skip
fi;
