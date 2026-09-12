import importlib.util
from pathlib import Path
import socket
import tempfile
import threading
import time
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location(
    "healthcheck", Path(__file__).resolve().parents[1] / "shairport-healthcheck.py")
healthcheck = importlib.util.module_from_spec(spec)
spec.loader.exec_module(healthcheck)


class HealthcheckTests(unittest.TestCase):
    def check_response(self, chunks, delay=0):
        with socket.socket() as server:
            server.bind(("127.0.0.1", 0))
            server.listen()
            def respond():
                conn, _ = server.accept()
                with conn:
                    conn.recv(4096)
                    for chunk in chunks:
                        conn.sendall(chunk)
                    time.sleep(delay)
            thread = threading.Thread(target=respond)
            thread.start()
            result = healthcheck.probe(port=server.getsockname()[1], timeout=0.1)
            thread.join()
            return result

    def test_success_and_fragmentation(self):
        self.assertTrue(self.check_response(
            [b"RTSP/1.0 200", b" OK\r\nCSeq: 1\r\n\r\n"]))

    def test_closed_busy_and_malformed(self):
        for response in (b"", b"RTSP/1.0 453 Busy\r\nCSeq: 1\r\n\r\n",
                         b"HTTP/1.1 200 OK\r\nCSeq: 1\r\n\r\n",
                         b"RTSP/1.0 200 OK\r\nCSeq: 2\r\n\r\n",
                         b"RTSP/1.0 200 OK\r\nCSeq: 1\r\n"):
            with self.subTest(response=response):
                self.assertFalse(self.check_response([response]))

    def test_stalled_connection(self):
        self.assertFalse(self.check_response([], delay=0.2))

    def test_refused_connection(self):
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            self.assertFalse(healthcheck.probe(port=sock.getsockname()[1]))

    def test_transient_failure_does_not_restart(self):
        check = Mock(side_effect=[False, True])
        sleep = Mock()
        self.assertTrue(healthcheck.healthy(check, sleep, active=lambda: False))
        self.assertEqual(check.call_count, 2)
        sleep.assert_called_once_with(5)

    def test_three_failures_required(self):
        check = Mock(return_value=False)
        sleep = Mock()
        self.assertFalse(healthcheck.healthy(check, sleep, active=lambda: False))
        self.assertEqual(check.call_count, 3)
        self.assertEqual(sleep.call_count, 2)

    def test_active_sender_skips_probe(self):
        check = Mock()
        self.assertTrue(healthcheck.healthy(check, Mock(), active=lambda: True))
        check.assert_not_called()

    def test_sender_connecting_during_probe_prevents_restart(self):
        check = Mock(return_value=False)
        sleep = Mock()
        self.assertTrue(healthcheck.healthy(check, sleep, active=Mock(side_effect=[False, True])))
        sleep.assert_not_called()

    def test_kernel_socket_states_ipv4_and_ipv6(self):
        with tempfile.TemporaryDirectory() as tmp:
            table = Path(tmp) / "tcp"
            for address in ("0100007F", "00000000000000000000000001000000"):
                for port, state, expected in ((5000, "01", True), (5001, "01", False),
                                               (5000, "0A", False), (5000, "08", False)):
                    with self.subTest(address=address, port=port, state=state):
                        table.write_text(f"header\n0: {address}:{port:04X} {address}:ABCD {state} 0\n")
                        self.assertEqual(healthcheck.has_active_session(tables=[str(table)]), expected)
            table.write_text("header\nmalformed\n0: bad remote 01\n")
            self.assertFalse(healthcheck.has_active_session(tables=[str(table)]))
            self.assertFalse(healthcheck.has_active_session(tables=[str(table)+"missing"]))


if __name__ == "__main__":
    unittest.main()
