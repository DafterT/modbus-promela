#define FC06 6 // Write Single Register: 0x06. 
#define FC03 3 // Read Holding Registers: 0x03. Не реализована

mtype = {
    MASTER_PREPARING, MASTER_WAITING, MASTER_RESPONSE,
    MASTER_TIMEOUT, MASTER_BROADCAST_DONE
};
mtype master_state = MASTER_PREPARING;

// Текущий запрос мастера
byte slave_address;     // Адрес получателя
byte function_code;     // Функция запроса
byte register_address;  // Адрес регистра
byte register_value;    // Значение регистра
bool crc_ok;            // Корректность crc

// Память Slave
// Адресуется по индексу, нулевой не используется
byte holding_register_0[4];     // Регистр 0
byte holding_register_1[4];     // Регистр 1
bool slave_write_performed[4];  // Флаг: была ли запись в текущей транзакции

// Наблюдательные данные для проверки свойств. Память Slave.
byte previous_register_0[4];    // Значения регистра 0 перед запросом
byte previous_register_1[4];    // Значения регистра 1 перед запросом
bool slave_processed[4];        // Флаг: закончил ли slave запрос
byte responses_sent;            // Количество отправленных ответов за транзакцию

// Ответ от Slave
byte response_slave_address;    // Адрес Slave
byte response_function_code;    // Функция ответа
byte response_register_address; // Адрес регистра
byte response_register_value;   // Значение регистра
byte response_exception_code;   // 0 — нормальный ответ, 1 или 2 — исключение

// Один запрос доставляется каждому Slave в отдельной копии.
// Поля: адрес Slave, функция, адрес регистра, значение, корректность CRC.
chan slave_requests[3] = [1] of { byte, byte, byte, byte, bool };

// Поля: адрес Slave, функция, адрес регистра, значение, исключение.
// Одновременно отвечать может только один адресованный Slave.
chan slave_responses = [1] of { byte, byte, byte, byte, byte };

// Служебные уведомления модели о завершении обработки slave
chan slave_done = [3] of { bool };

proctype Master()
{
    do
    :: true ->
        master_state = MASTER_PREPARING;

        atomic {
            // Сбрасываем сведения о предыдущем обмене
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

            // Снимок для проверки сохранности регистров
            previous_register_0[1] = holding_register_0[1];
            previous_register_0[2] = holding_register_0[2];
            previous_register_0[3] = holding_register_0[3];
            previous_register_1[1] = holding_register_1[1];
            previous_register_1[2] = holding_register_1[2];
            previous_register_1[3] = holding_register_1[3];

            // Выбираем получателя
            if
            :: slave_address = 0        // Broadcast
            :: slave_address = 1
            :: slave_address = 2
            :: slave_address = 3
            :: slave_address = 4        // Отсутствующий Slave
            fi;
            // Подготавливаем корректную запись FC06
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

            // Оставляем запрос корректным или добавляем одну ошибку.
            if
            :: skip                     // Без ошибки
            :: crc_ok = false           // Ошибка CRC
            :: register_address = 2     // Несуществующий регистр
            :: function_code = FC03     // Неподдерживаемая функция
            fi;

            printf("Master: request slave=%d FC=%d register=%d value=%d CRC=%d\n",
                slave_address, function_code, register_address, register_value, crc_ok);

            master_state = MASTER_WAITING;

            // Одна копия общего кадра для каждого Slave
            slave_requests[0]!slave_address, function_code,
                register_address, register_value, crc_ok;
            slave_requests[1]!slave_address, function_code,
                register_address, register_value, crc_ok;
            slave_requests[2]!slave_address, function_code,
                register_address, register_value, crc_ok;
        }

        // Ожидание завершения трех slave
        slave_done?true;
        slave_done?true;
        slave_done?true;

        if
        :: (slave_address == 0) ->  // Был выбран broadcast
            master_state = MASTER_BROADCAST_DONE;
            printf("Master: broadcast completed, no response expected\n");
        :: else ->                  // Был выбран не broadcast
            if
            :: (len(slave_responses) > 0) ->    // Есть ответ от slave
                // Извлекаем сообщение
                slave_responses?response_slave_address, response_function_code,
                    response_register_address, response_register_value,
                    response_exception_code;

                master_state = MASTER_RESPONSE;

                printf("Master: response slave=%d FC=%d register=%d value=%d exception=%d\n",
                    response_slave_address, response_function_code,
                    response_register_address, response_register_value,
                    response_exception_code);
            :: else ->                          // Имитация timeout (нет ответа от slave)
                master_state = MASTER_TIMEOUT;
                printf("Master: timeout (no response)\n");
            fi
        fi;

        printf("Registers: Slave 1=(%d,%d) Slave 2=(%d,%d) Slave 3=(%d,%d)\n",
            holding_register_0[1], holding_register_1[1],
            holding_register_0[2], holding_register_1[2],
            holding_register_0[3], holding_register_1[3]);
    od
}

proctype Slave(byte slave_id) // slave_id - собственный адрес устройства
{
    // Локальная копия запроса
    byte request_slave_address;     // Адрес получателя
    byte request_function_code;     // Код функции
    byte request_register_address;  // Адрес регистра
    byte request_register_value;    // Значение регистра
    bool request_crc_ok;            // Признак корректности crc
    byte exception_code;            // Локальный результат проверок

    // Slave построянно ожидает новые запросы
    do
    :: slave_requests[slave_id - 1]?request_slave_address, request_function_code,
            request_register_address, request_register_value, request_crc_ok ->
        exception_code = 0; // Ошибок изначально нет
        if
        // Пакет предназначается нам
        :: (request_slave_address == slave_id || request_slave_address == 0) ->
            if
            // crc корректно
            :: request_crc_ok ->
                if
                // Код не 0x06
                :: (request_function_code != FC06) -> exception_code = 1 // Ошибка - неверный код
                :: else ->
                    if
                    // Регистр больше существующих
                    :: (request_register_address > 1) -> exception_code = 2 // Ошибка - неверный регистр
                    :: else ->
                        // Все хорошо, запись в регистры
                        atomic {
                            if
                            :: (request_register_address == 0) ->   // Запись в первый регистр
                                holding_register_0[slave_id] = request_register_value
                            :: else ->                              // Запись во второй регистр
                                holding_register_1[slave_id] = request_register_value
                            fi;
                            // Установка флага что была запись в регистр
                            slave_write_performed[slave_id] = true;
                        }
                        printf("Slave %d: write register[%d]=%d\n",
                            slave_id, request_register_address, request_register_value);
                    fi
                fi;
                // Формирование ответа
                if
                // Если запрос - broadcast, молчим
                :: (request_slave_address == 0) -> skip
                // Если заполс не broadcast формируем ответ
                :: else ->
                    if
                    // Если в ответе нет ошибки
                    :: (exception_code == 0) ->
                        atomic {
                            slave_responses!slave_id, request_function_code,
                                request_register_address, request_register_value, 0;
                            responses_sent++;
                        }
                    // Если в ответе есть ошибка
                    :: else ->
                        atomic {
                            slave_responses!slave_id, (request_function_code + 128),
                                0, 0, exception_code;
                            responses_sent++;
                        }
                    fi
                fi
            // crc не коррктно
            :: else ->
                printf("Slave %d: ignored (bad CRC)\n", slave_id)
            fi
        // Пакет предназначется не нам
        :: else -> skip
        fi;

        // В конце обработки уведомляем о завершении
        atomic {
            slave_processed[slave_id] = true;
            // Обнуляем локальное состояние
            request_slave_address = 0;
            request_function_code = 0;
            request_register_address = 0;
            request_register_value = 0;
            request_crc_ok = false;
            exception_code = 0;
            // Сообщаем о завершении обработки
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
