import os
import time

POLL_TIMEOUT = int(os.getenv("POLL_TIMEOUT", "60"))
HEARTBEAT_FILE = os.getenv("HEARTBEAT_FILE", "/tmp/worker-heartbeat")


def write_heartbeat():
    with open(HEARTBEAT_FILE, "w", encoding="utf-8") as heartbeat:
        heartbeat.write(str(int(time.time())))


if __name__ == "__main__":
    print("worker mvp", flush=True)
    write_heartbeat()
    while True:
        write_heartbeat()
        time.sleep(POLL_TIMEOUT)
