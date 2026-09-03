#!/bin/bash
set -e

mkdir -p /var/log/supervisor /run/sshd /run/dbus
# X/ICE rendezvous sockets. Normally a distro's systemd-tmpfiles creates these
# at boot; nothing here does, and both must be world-writable + sticky or the
# X server (and any ICE-managed client) silently fails to bind.
mkdir -p -m 1777 /tmp/.ICE-unix /tmp/.X11-unix

# XDG_RUNTIME_DIR — normally pam_systemd creates this at login; nothing here
# does, and /run/user itself isn't writable by `user`, so seed it as root.
mkdir -p -m 0700 "${XDG_RUNTIME_DIR}"
chown "${USER}:${USER}" "${XDG_RUNTIME_DIR}"

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
