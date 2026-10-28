atomic {
    slave_processed[slave_id] = true;
    request_slave_address = 0;
    request_function_code = 0;
    request_register_address = 0;
    request_register_value = 0;
    request_crc_ok = false;
    exception_code = 0;
    slave_done!true;
}
