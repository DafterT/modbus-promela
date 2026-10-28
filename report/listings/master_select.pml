if
:: slave_address = 0
:: slave_address = 1
:: slave_address = 2
:: slave_address = 3
:: slave_address = 4
fi;
if
:: register_address = 0
:: register_address = 1
fi;
if
:: register_value = 1
:: register_value = 2
fi;
function_code = FC06;
crc_ok = true;
if
:: skip
:: crc_ok = false
:: register_address = 2
:: function_code = FC03
fi;
