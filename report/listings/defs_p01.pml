#define finished (master_state == MASTER_RESPONSE || master_state == MASTER_TIMEOUT || master_state == MASTER_BROADCAST_DONE)
#define no_writes (!slave_write_performed[1] && !slave_write_performed[2] && !slave_write_performed[3])
#define unchanged(s) (holding_register_0[s] == previous_register_0[s] && \
    holding_register_1[s] == previous_register_1[s])
#define all_unchanged (unchanged(1) && unchanged(2) && unchanged(3))
