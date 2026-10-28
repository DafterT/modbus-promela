#define FC06 6
#define FC03 3
mtype = {
    MASTER_PREPARING, MASTER_WAITING, MASTER_RESPONSE,
    MASTER_TIMEOUT, MASTER_BROADCAST_DONE
};
mtype master_state = MASTER_PREPARING;

byte slave_address;
byte function_code;
byte register_address;
byte register_value;
bool crc_ok;
byte holding_register_0[4];
byte holding_register_1[4];
bool slave_write_performed[4];
