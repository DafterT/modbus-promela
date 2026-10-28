chan slave_requests[3] = [1] of { byte, byte, byte, byte, bool };
chan slave_responses = [1] of { byte, byte, byte, byte, byte };
chan slave_done = [3] of { bool };

init
{
    atomic {
        run Slave(1);
        run Slave(2);
        run Slave(3);
        run Master();
    }
}
