#define authorized(s) ( \
    !slave_write_performed[s] || \
    (valid_write && (slave_address == 0 || slave_address == s)))
