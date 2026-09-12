#!/usr/bin/env python3
"""Bounded, non-playing Classic AirPlay OPTIONS probe for OpenRC."""
from pathlib import Path
import socket
import sys
import time


def probe(host="127.0.0.1", port=5000, timeout=3):
    deadline = time.monotonic() + timeout
    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            sock.sendall(b"OPTIONS * RTSP/1.0\r\nCSeq: 1\r\n"
                         b"User-Agent: Multiroom-Healthcheck\r\n\r\n")
            response = b""
            while b"\r\n\r\n" not in response and len(response) < 8192:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return False
                sock.settimeout(remaining)
                chunk = sock.recv(1024)
                if not chunk:
                    return False
                response += chunk
            lines = response.split(b"\r\n")
            return (b"\r\n\r\n" in response
                    and lines[0] == b"RTSP/1.0 200 OK"
                    and any(line.lower() == b"cseq: 1" for line in lines[1:]))
    except OSError:
        return False


def has_active_session(port=5000, tables=("/proc/net/tcp", "/proc/net/tcp6")):
    """Classic Shairport rejects even OPTIONS connections while a sender is active.

    Read kernel socket state without opening or consuming the PCM pipe. Shairport's
    session timeout/TCP keepalive and OpenRC process supervision remain responsible
    for abandoned sessions and crashed processes.
    """
    for table in tables:
        try:
            lines = Path(table).read_text().splitlines()[1:]
        except OSError:
            continue
        for line in lines:
            fields = line.split()
            if len(fields) < 4 or fields[3] != "01":  # TCP_ESTABLISHED
                continue
            try:
                if int(fields[1].rsplit(":", 1)[1], 16) == port:
                    return True
            except (ValueError, IndexError):
                continue
    return False


def healthy(check=probe, sleep=time.sleep, active=has_active_session):
    for attempt in range(3):
        # Recheck after a failed probe in case a sender connected during it.
        if active() or check() or active():
            return True
        if attempt < 2:
            sleep(5)
    return False


if __name__ == "__main__":
    if healthy():
        sys.exit(0)
    print("Multiroom: three consecutive idle AirPlay OPTIONS failures", file=sys.stderr)
    sys.exit(1)
