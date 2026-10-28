ltl p07_normal_response {
    [] ((master_state == MASTER_RESPONSE && response_exception_code == 0) ->
        (addressed && valid_write && responses_sent == 1 &&
            response_slave_address == slave_address &&
            response_function_code == FC06 &&
            response_register_address == register_address &&
            response_register_value == register_value))
}
