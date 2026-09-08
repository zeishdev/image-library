#!/bin/bash
set -e

# initd (PID 1 in the microVM) starts this workload with a bare environment —
# only its own allowlist (DISPLAY, XDG_RUNTIME_DIR, XAUTHORITY, SANDBOXD_*),
# HOME=/ — unlike `docker run`, which inherits the image's full ENV. Re-assert
# every var supervisord.conf reads as %(ENV_*)s: a missing one makes
# supervisord's config interpolation fail and it spins without ever starting
# the desktop. Defaults match the image ENV; keep them in sync.
: "${USER:=root}"
: "${HOME:=/root}"
: "${DISPLAY:=:1}"
: "${VNC_PORT:=5900}"
: "${PROXY_PORT:=6080}"
: "${VNC_RESOLUTION:=1280x800}"
: "${VNC_DEPTH:=24}"
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export USER HOME DISPLAY VNC_PORT PROXY_PORT VNC_RESOLUTION VNC_DEPTH XDG_RUNTIME_DIR

mkdir -p /var/log/supervisor /run/sshd /run/dbus /run/user
# X/ICE rendezvous sockets. Normally a distro's systemd-tmpfiles creates these
# at boot; nothing here does, and both must be world-writable + sticky or the
# X server (and any ICE-managed client) silently fails to bind.
mkdir -p -m 1777 /tmp/.ICE-unix /tmp/.X11-unix

# XDG_RUNTIME_DIR — normally pam_systemd creates this at login; nothing here
# does, and /run/user itself isn't writable by `user`, so seed it as root.
mkdir -p -m 0700 "${XDG_RUNTIME_DIR}"
chown "${USER}:${USER}" "${XDG_RUNTIME_DIR}" 2>/dev/null || true

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
