"""Browser egress arguments: public traffic is proxied, private traffic stays local."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "images/base/scripts/zeish-chrome-egress.sh"


class ChromeEgressTests(unittest.TestCase):
    def flags(self, proxy=None, no_proxy=None):
        env = os.environ.copy()
        env.pop("ZEISH_EGRESS_PROXY", None)
        env.pop("NO_PROXY", None)
        if proxy is not None:
            env["ZEISH_EGRESS_PROXY"] = proxy
        if no_proxy is not None:
            env["NO_PROXY"] = no_proxy
        return subprocess.check_output(
            ["bash", "-c", 'source "$1"; zeish_chrome_egress_flags', "bash", str(HELPER)],
            env=env,
            text=True,
        ).splitlines()

    def test_unmanaged_browser_does_not_acquire_a_proxy(self):
        self.assertEqual([], self.flags())
        self.assertEqual([], self.flags(""))

    def test_managed_proxy_keeps_ipv6_endpoint_in_one_argument(self):
        self.assertEqual(
            [
                "--proxy-server=http://[fdaa::1]:3128",
                "--proxy-bypass-list=localhost;127.0.0.1;[::1];*.internal",
                "--disable-quic",
            ],
            self.flags("http://[fdaa::1]:3128"),
        )

    def test_tenant_no_proxy_does_not_bypass_public_policy(self):
        self.assertEqual(
            self.flags("http://[fdaa::1]:3128"),
            self.flags("http://[fdaa::1]:3128", "*,blocked.example.com,10.0.0.0/8"),
        )

    def test_managed_launchers_fail_before_startup_without_helper(self):
        with tempfile.TemporaryDirectory() as tmp:
            absent_helper = str(Path(tmp) / "missing-helper.sh")
            for relative in (
                "images/base/scripts/zeish-chrome-cdp",
                "images/desktop-x11/scripts/zeish-chrome",
            ):
                with self.subTest(launcher=relative):
                    launcher = (ROOT / relative).read_text().replace(
                        "/usr/local/lib/zeish/chrome-egress.sh", absent_helper
                    )
                    env = os.environ.copy()
                    env["ZEISH_EGRESS_PROXY"] = "http://127.0.0.1:3128"
                    result = subprocess.run(
                        ["bash", "-c", launcher],
                        env=env,
                        capture_output=True,
                        text=True,
                        timeout=5,
                    )
                    self.assertEqual(1, result.returncode)
                    self.assertIn(absent_helper, result.stderr)

    def test_desktop_launcher_passes_policy_to_chrome(self):
        launcher = (ROOT / "images/desktop-x11/scripts/zeish-chrome").read_text()
        function = launcher.split("common_flags() {", 1)[1].split("\n# Bounded restart", 1)[0]
        result = subprocess.check_output(
            [
                "bash", "-c",
                'source "$1"; PROFILE_DIR=/tmp/profile; CDP_PORT=9223; '
                'ZEISH_EGRESS_PROXY=http://127.0.0.1:3128; common_flags() {'
                + function + '\ncommon_flags',
                "bash", str(HELPER),
            ],
            text=True,
        ).splitlines()
        self.assertIn("--remote-debugging-address=127.0.0.1", result)
        self.assertIn("--proxy-server=http://127.0.0.1:3128", result)
        self.assertIn("--proxy-bypass-list=localhost;127.0.0.1;[::1];*.internal", result)

    def test_headless_launcher_passes_policy_to_chrome(self):
        launcher = (ROOT / "images/base/scripts/zeish-chrome-cdp").read_text()
        function = launcher.split("watchdog() {", 1)[1].split("\nstart_bin() {", 1)[0]
        with tempfile.TemporaryDirectory() as tmp:
            capture = Path(tmp) / "args"
            subprocess.run(
                [
                    "bash", "-c",
                    'source "$1"; CAPTURE="$2"; LOG=/dev/null; MAX_RESTARTS=0; '
                    'LOCAL_PORT=9222; UD=/tmp/profile; '
                    'ZEISH_EGRESS_PROXY=http://127.0.0.1:3128; '
                    'sleep() { :; }; fake_chrome() { printf "%s\\n" "$@" > "$CAPTURE"; }; '
                    'watchdog() {' + function + '\nwatchdog fake_chrome',
                    "bash", str(HELPER), str(capture),
                ],
                check=True,
            )
            result = capture.read_text().splitlines()
        self.assertIn("--headless=new", result)
        self.assertIn("--remote-debugging-address=127.0.0.1", result)
        self.assertIn("--proxy-server=http://127.0.0.1:3128", result)
        self.assertIn("--proxy-bypass-list=localhost;127.0.0.1;[::1];*.internal", result)


if __name__ == "__main__":
    unittest.main()
