#include "modbus.pml"

// Транзакция завершилась
#define finished (master_state == MASTER_RESPONSE || master_state == MASTER_TIMEOUT || master_state == MASTER_BROADCAST_DONE)
// Любое состояние кроме подготовки новой транзакции
#define active (master_state == MASTER_WAITING || finished)
// Сущестует конкретный slave
#define addressed (slave_address >= 1 && slave_address <= 3)
// Посылка корректна (адрес не проверяет)
#define valid_write (crc_ok && function_code == FC06 && register_address <= 1)
// Записи на текущей транзакции не было
#define no_writes (!slave_write_performed[1] && !slave_write_performed[2] && !slave_write_performed[3])
// Регистры Slave с address = s не менялись
#define unchanged(s) (holding_register_0[s] == previous_register_0[s] && \
    holding_register_1[s] == previous_register_1[s])
// Регистры Slave не менялись
#define all_unchanged (unchanged(1) && unchanged(2) && unchanged(3))
// У Slave с address = s записан корректный регистр, второй не менялся
#define written(s) ( \
    (register_address == 0 && holding_register_0[s] == register_value && \
        holding_register_1[s] == previous_register_1[s]) || \
    (register_address == 1 && holding_register_1[s] == register_value && \
        holding_register_0[s] == previous_register_0[s]))
// Запрос не тронул лишние регистры у slave с address = s
#define isolated(s) ( \
    (slave_address == s || (!slave_write_performed[s] && unchanged(s))) && \
    (slave_address != s || \
        (register_address == 0 && holding_register_1[s] == previous_register_1[s]) || \
        (register_address == 1 && holding_register_0[s] == previous_register_0[s]) || \
        (register_address > 1 && unchanged(s))))
// Если Slave выполнил запись, запрос корректен и адресован ему или всем
#define authorized(s) (!slave_write_performed[s] || (valid_write && (slave_address == 0 || slave_address == s)))
// Master получил правильно оформленный ответ с указанным кодом ошибки.
#define exception_response(code) (master_state == MASTER_RESPONSE && \
    responses_sent == 1 && response_slave_address == slave_address && \
    response_function_code == function_code + 128 && \
    response_register_address == 0 && response_register_value == 0 && \
    response_exception_code == code)

// 1. Ошибочная CRC: нет записи и ответа, Master получает тайм-аут
ltl p01_crc_ignored {
    [] ((finished && !crc_ok) ->
        (master_state == MASTER_TIMEOUT && responses_sent == 0 && no_writes && all_unchanged))
}

// 2. Отсутсвующий slave 4: нет записи и ответа, Master получает тайм-аут
ltl p02_absent_slave {
    [] ((finished && slave_address == 4) ->
        (master_state == MASTER_TIMEOUT && responses_sent == 0 && no_writes && all_unchanged))
}

// 3. На broadcast никто не отвечает
ltl p03_broadcast_silent {
    [] ((active && slave_address == 0) ->
        (responses_sent == 0 && len(slave_responses) == 0))
}

// 4. Broadcast записан всеми тремя Slave
ltl p04_broadcast_written {
    [] ((finished && slave_address == 0) ->
        (master_state == MASTER_BROADCAST_DONE && valid_write &&
            slave_write_performed[1] && slave_write_performed[2] && slave_write_performed[3] && 
            written(1) && written(2) && written(3)))
}

// 5. Правильный адресный 0x06 действительно записан и завершён успешно
ltl p05_addressed_write {
    [] ((finished && addressed && valid_write) ->
        (master_state == MASTER_RESPONSE && response_exception_code == 0 &&
            ((slave_address == 1 && slave_write_performed[1] && written(1)) ||
             (slave_address == 2 && slave_write_performed[2] && written(2)) ||
             (slave_address == 3 && slave_write_performed[3] && written(3)))))
}

// 6. Адресный запрос не меняет чужие или невыбранные регистры
ltl p06_write_isolation {
    [] ((finished && addressed) -> (isolated(1) && isolated(2) && isolated(3)))
}

// 7. Нормальный ответ возможен только на правильную запись и повторяет её
ltl p07_normal_response {
    [] ((master_state == MASTER_RESPONSE && response_exception_code == 0) ->
        (addressed && valid_write && responses_sent == 1 &&
            response_slave_address == slave_address && response_function_code == FC06 &&
            response_register_address == register_address &&
            response_register_value == register_value))
}

// 8. Неподдерживаемая функция: исключение 1, никаких изменений регистров
ltl p08_illegal_function {
    [] ((finished && addressed && crc_ok && function_code != FC06) ->
        (exception_response(1) && no_writes && all_unchanged))
}

// 9. Несуществующий регистр: исключение 2, никаких изменений регистров
ltl p09_illegal_register {
    [] ((finished && addressed && crc_ok && function_code == FC06 &&
            register_address > 1) ->
        (exception_response(2) && no_writes && all_unchanged))
}

// 10. Каждый Slave выполняет запись только по корректному запросу, адресованному ему или всем
ltl p10_write_authorized {
    [] (active -> (authorized(1) && authorized(2) && authorized(3)))
}

// 11. За одну транзакцию отправляется не более одного ответа
ltl p11_single_response {
    [] (active -> (responses_sent <= 1))
}

// 12. Начатая транзакция достигает результата без новой подготовки между ними
ltl p12_transaction_progress {
    [] ((master_state == MASTER_WAITING) -> ((master_state == MASTER_WAITING) U finished))
}

// 13. Результат фиксируется после всех обработчиков, каналы уже пусты
ltl p14_completion_clean {
    [] (finished ->
        (slave_processed[1] && slave_processed[2] && slave_processed[3] &&
            len(slave_requests[0]) == 0 && len(slave_requests[1]) == 0 &&
            len(slave_requests[2]) == 0 && len(slave_done) == 0 &&
            len(slave_responses) == 0))
}
