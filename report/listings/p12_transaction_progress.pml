ltl p12_transaction_progress {
    [] ((master_state == MASTER_WAITING) -> ((master_state == MASTER_WAITING) U finished))
}
