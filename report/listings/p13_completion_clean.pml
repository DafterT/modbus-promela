ltl p13_completion_clean {
    [] (finished ->
        (slave_processed[1] &&
            slave_processed[2] &&
            slave_processed[3] &&
            len(slave_requests[0]) == 0 &&
            len(slave_requests[1]) == 0 &&
            len(slave_requests[2]) == 0 &&
            len(slave_done) == 0 && len(slave_responses) == 0))
}
