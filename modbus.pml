/* Modbus RTU: один Master и три Slave на общей шине RS-485.
 * Моделируются целые сообщения, а не биты UART и физическое время.
 */
#define TRANSACTION_COUNT 3
#define FC06 6 /* Write Single Register: 0x06. */
#define FC03 3 /* Read Holding Registers: 0x03, не реализована. */

mtype = {
    MASTER_PREPARING, MASTER_WAITING, MASTER_RESPONSE,
    MASTER_TIMEOUT, MASTER_BROADCAST_DONE
};
mtype master_state = MASTER_PREPARING;
byte transaction_number = 0;

/* Текущий запрос Master. CRC представлен признаком корректности. */
byte slave_address;
byte function_code;
byte register_address;
byte register_value;
bool crc_ok;

/* Индексы 1, 2, 3 совпадают с адресами Slave; индекс 0 не используется. */
byte holding_register_0[4];
byte holding_register_1[4];
bool slave_write_performed[4]; /* Была ли запись в текущей транзакции. */

/* Наблюдательные данные для проверки свойств: на протокол не влияют. */
byte previous_register_0[4]; /* Значения регистров перед текущим запросом. */
byte previous_register_1[4];
bool slave_processed[4];    /* Закончил ли Slave обработку текущего запроса. */
byte responses_sent;       /* Сколько ответов отправлено в этой транзакции. */

/* Последний принятый ответ; master_state показывает результат транзакции. */
byte response_slave_address;
byte response_function_code;
byte response_register_address;
byte response_register_value;
byte response_exception_code; /* 0 — нормальный ответ, 1 или 2 — исключение. */

/* Один запрос доставляется каждому Slave в отдельной копии.
 * Поля: адрес Slave, функция, адрес регистра, значение, корректность CRC.
 */
chan slave_requests[3] = [1] of { byte, byte, byte, byte, bool };

/* Поля ответа: адрес Slave, функция, адрес регистра, значение, исключение.
 * У исключения поля регистра и значения равны 0: в реальном кадре их нет.
 * Одновременно отвечать может только один адресованный Slave.
 */
chan slave_responses = [1] of { byte, byte, byte, byte, byte };

/* Служебные уведомления модели, НЕ сообщения Modbus на шине.
 * Каждый Slave сообщает о завершении, даже если запрос был проигнорирован.
 */
chan slave_done = [3] of { bool };

proctype Master()
{
    do
    :: (transaction_number < TRANSACTION_COUNT) ->
        master_state = MASTER_PREPARING;
        transaction_number++;

        /* Сбрасываем сведения о предыдущей транзакции, но не регистры. */
        response_slave_address = 0;
        response_function_code = 0;
        response_register_address = 0;
        response_register_value = 0;
        response_exception_code = 0;
        slave_write_performed[1] = false;
        slave_write_performed[2] = false;
        slave_write_performed[3] = false;
        slave_processed[1] = false;
        slave_processed[2] = false;
        slave_processed[3] = false;
        responses_sent = 0;

        /* Снимок позволяет проверить сохранность остальных регистров. */
        previous_register_0[1] = holding_register_0[1];
        previous_register_0[2] = holding_register_0[2];
        previous_register_0[3] = holding_register_0[3];
        previous_register_1[1] = holding_register_1[1];
        previous_register_1[2] = holding_register_1[2];
        previous_register_1[3] = holding_register_1[3];

        /* Сначала выбираем параметры корректного адресного FC06. */
        if
        :: slave_address = 1
        :: slave_address = 2
        :: slave_address = 3
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

        /* Все шесть ветвей доступны при каждой транзакции. */
        if
        :: skip                       /* Корректная адресная запись. */
        :: crc_ok = false             /* Ошибка CRC. */
        :: slave_address = 4          /* Отсутствующий Slave. */
        :: register_address = 2       /* Несуществующий регистр. */
        :: function_code = FC03       /* Неподдерживаемая функция. */
        :: slave_address = 0          /* Корректная broadcast-запись. */
        fi;

        printf("Master: transaction=%d slave=%d FC=%d register=%d value=%d CRC=%d\n",
            transaction_number, slave_address, function_code,
            register_address, register_value, crc_ok);

        /* Один логический шаг доставки общего кадра всем трём Slave.
         * После этого Slave обрабатывают свои копии независимо.
         */
        atomic {
            master_state = MASTER_WAITING;
            slave_requests[0]!slave_address, function_code,
                register_address, register_value, crc_ok;
            slave_requests[1]!slave_address, function_code,
                register_address, register_value, crc_ok;
            slave_requests[2]!slave_address, function_code,
                register_address, register_value, crc_ok;
        }

        /* Логическое ожидание обработки вместо отсчёта реального времени.
         * До следующего запроса должны завершиться ВСЕ три Slave.
         */
        slave_done?true;
        slave_done?true;
        slave_done?true;

        if
        :: (slave_address == 0) ->
            master_state = MASTER_BROADCAST_DONE;
            printf("Master: broadcast completed, no response expected\n");
        :: else ->
            if
            :: (len(slave_responses) > 0) ->
                slave_responses?response_slave_address, response_function_code,
                    response_register_address, response_register_value,
                    response_exception_code;
                master_state = MASTER_RESPONSE;
                printf("Master: response slave=%d FC=%d register=%d value=%d exception=%d\n",
                    response_slave_address, response_function_code,
                    response_register_address, response_register_value,
                    response_exception_code);
            :: else ->
                /* Все Slave завершились: поздний ответ уже невозможен. */
                master_state = MASTER_TIMEOUT;
                printf("Master: timeout (no response)\n");
            fi
        fi;

        printf("Registers: Slave 1=(%d,%d) Slave 2=(%d,%d) Slave 3=(%d,%d)\n",
            holding_register_0[1], holding_register_1[1],
            holding_register_0[2], holding_register_1[2],
            holding_register_0[3], holding_register_1[3]);
    :: else -> break
    od
}

proctype Slave(byte slave_id)
{
    /* Локальная копия запроса не меняется при работе других Slave. */
    byte request_slave_address;
    byte request_function_code;
    byte request_register_address;
    byte request_register_value;
    bool request_crc_ok;
    byte exception_code;

    /* Ожидание нового запроса — допустимое конечное состояние Slave. */
end_slave_wait:
    do
    :: slave_requests[slave_id - 1]?request_slave_address, request_function_code,
            request_register_address, request_register_value, request_crc_ok ->
        exception_code = 0;
        if
        :: (request_slave_address == slave_id || request_slave_address == 0) ->
            if
            :: request_crc_ok ->
                if
                :: (request_function_code != FC06) -> exception_code = 1
                :: else ->
                    if
                    :: (request_register_address > 1) -> exception_code = 2
                    :: else ->
                        /* Запись и её признак — один логический шаг. */
                        atomic {
                            if
                            :: (request_register_address == 0) ->
                                holding_register_0[slave_id] = request_register_value
                            :: else ->
                                holding_register_1[slave_id] = request_register_value
                            fi;
                            slave_write_performed[slave_id] = true;
                        }
                        printf("Slave %d: write register[%d]=%d\n",
                            slave_id, request_register_address, request_register_value);
                    fi
                fi;

                /* На broadcast не отправляется никакой ответ. */
                if
                :: (request_slave_address == 0) -> skip
                :: else ->
                    if
                    :: (exception_code == 0) ->
                        atomic {
                            slave_responses!slave_id, request_function_code,
                                request_register_address, request_register_value, 0;
                            responses_sent++;
                        }
                    :: else ->
                        /* Прибавляем 128 (0x80): старший бит функции. */
                        atomic {
                            slave_responses!slave_id, (request_function_code + 128),
                                0, 0, exception_code;
                            responses_sent++;
                        }
                    fi
                fi
            :: else ->
                printf("Slave %d: ignored (bad CRC)\n", slave_id)
            fi
        :: else -> skip /* Запрос адресован другому Slave. */
        fi;

        /* Уведомление идёт ПОСЛЕ записи или помещения ответа в канал. */
        atomic {
            slave_processed[slave_id] = true;
            slave_done!true;
        }
    od
}

init
{
    atomic {
        run Slave(1);
        run Slave(2);
        run Slave(3);
        run Master();
    }
}
