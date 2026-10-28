#define valid_write (crc_ok && function_code == FC06 && register_address <= 1)

#define written(s) ( \
    (register_address == 0 && \
        holding_register_0[s] == register_value && \
        holding_register_1[s] == previous_register_1[s]) || \
    (register_address == 1 && \
        holding_register_1[s] == register_value && \
        holding_register_0[s] == previous_register_0[s]))
