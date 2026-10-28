#define exception_response(code) (master_state == MASTER_RESPONSE && \
    responses_sent == 1 && response_slave_address == slave_address && \
    response_function_code == function_code + 128 && \
    response_register_address == 0 && response_register_value == 0 && \
    response_exception_code == code)
