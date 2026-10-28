slave_done?true;
slave_done?true;
slave_done?true;
if
:: (slave_address == 0) ->
    master_state = MASTER_BROADCAST_DONE;
:: else ->
    if
    :: (len(slave_responses) > 0) ->
        slave_responses?response_slave_address, response_function_code,
            response_register_address, response_register_value,
            response_exception_code;
        master_state = MASTER_RESPONSE;
    :: else ->
        master_state = MASTER_TIMEOUT;
    fi
fi;
