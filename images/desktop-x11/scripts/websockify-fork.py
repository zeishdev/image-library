#!/usr/bin/python3
"""Run websockify with fork-based workers.

NOT `/usr/bin/env python3`: the base image puts pyenv's python3 shim ahead of
/usr/bin on PATH, but python3-websockify is only installed into the system
interpreter's site-packages. Pin the shebang so this keeps working regardless
of PATH/pyenv state.

Ubuntu 26.04 ships Python 3.14, where multiprocessing defaults to forkserver
on POSIX. The distro websockify package expects fork-style socket inheritance;
with forkserver, accepted HTTP/WebSocket connections can hang while child
processes spin. Force fork before entering websockify's CLI.
"""

import multiprocessing as mp

from websockify import websocketproxy


def main() -> None:
    try:
        mp.set_start_method("fork")
    except RuntimeError:
        pass
    websocketproxy.websockify_init()


if __name__ == "__main__":
    main()
