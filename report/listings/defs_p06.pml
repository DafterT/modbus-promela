#define isolated(s) ( \
    (slave_address == s || (!slave_write_performed[s] && unchanged(s))) && \
    (slave_address != s || \
        (register_address == 0 && holding_register_1[s] == previous_register_1[s]) || \
        (register_address == 1 && holding_register_0[s] == previous_register_0[s]) || \
        (register_address > 1 && unchanged(s))))
