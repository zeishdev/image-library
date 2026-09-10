#!/bin/bash
set -e

# initd (PID 1 in the microVM) starts this workload with a bare environment —
# only its own allowlist (DISPLAY, XDG_RUNTIME_DIR, XAUTHORITY, SANDBOXD_*),
# HOME=/ — unlike `docker run`, which inherits the image's full ENV. Without
# help the two paths diverge: under Docker the desktop sees the image's
# HOME=/home/user, under initd it sees HOME=/, so GTK/Chrome/xfwm4 state lands
# somewhere different and a `docker run` smoke test stops being evidence about
# the microVM.
#
# /etc/zeish/desktop.env is the single source of truth for those values. Each
# Dockerfile writes it with the same values it bakes into ENV, using `:=` so a
# genuine runtime override (DISPLAY=:2, a bigger VNC_RESOLUTION, ...) still
# wins. Sourcing it makes both start paths identical by construction rather
# than by two lists someone has to remember to keep in sync.
if [ -r /etc/zeish/desktop.env ]; then
	# shellcheck source=/dev/null
	. /etc/zeish/desktop.env
fi

# Last-ditch fallbacks if the env file is somehow missing.
: "${USER:=root}"
: "${HOME:=/root}"
: "${DISPLAY:=:1}"
: "${VNC_PORT:=5900}"
: "${PROXY_PORT:=6080}"
: "${VNC_RESOLUTION:=1280x800}"
: "${VNC_DEPTH:=24}"
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
: "${XAUTHORITY:=/run/zeish/Xauthority}"
export USER HOME DISPLAY VNC_PORT PROXY_PORT VNC_RESOLUTION VNC_DEPTH \
	XDG_RUNTIME_DIR XAUTHORITY

mkdir -p /var/log/supervisor /run/sshd /run/dbus /run/user
# X/ICE rendezvous sockets. Normally a distro's systemd-tmpfiles creates these
# at boot; nothing here does, and both must be world-writable + sticky or the
# X server (and any ICE-managed client) silently fails to bind.
mkdir -p -m 1777 /tmp/.ICE-unix /tmp/.X11-unix

# XDG_RUNTIME_DIR — normally pam_systemd creates this at login; nothing here
# does, and /run/user itself isn't writable by `user`, so seed it as root.
mkdir -p -m 0700 "${XDG_RUNTIME_DIR}"
chown "${USER}:${USER}" "${XDG_RUNTIME_DIR}" 2>/dev/null || true

# ── X access control ────────────────────────────────────────────────────────
# Xvfb runs WITHOUT `-ac`. `-ac` disables access control entirely, which lets
# any process in the guest — including whatever the tenant runs in /workspace —
# screenshot the agent's browser session and inject synthetic input into it,
# and lets one fork display drive another. Instead every X client authenticates
# with an MIT-MAGIC-COOKIE from a root-owned 0600 Xauthority file. sandboxd
# reads it through the XAUTHORITY initd forwards; the supervised units get it
# from their `environment=` lines; the fork broker adds its own per-display
# cookie to the same file before starting a fork's Xvfb.
mkdir -p -m 0700 "$(dirname "${XAUTHORITY}")"
if ! command -v xauth >/dev/null 2>&1; then
	echo "entrypoint: xauth is required for X access control but is not installed" >&2
	exit 1
fi
touch "${XAUTHORITY}"
chmod 0600 "${XAUTHORITY}"
# Re-seed on every boot: a cookie persisted from a previous boot into a
# snapshot would be a shared secret across every sandbox restored from it.
xauth -f "${XAUTHORITY}" remove "${DISPLAY}" 2>/dev/null || true
xauth -f "${XAUTHORITY}" add "${DISPLAY}" MIT-MAGIC-COOKIE-1 \
	"$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
