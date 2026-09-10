# desktop-x11

`zeish-agent-desktop-x11` — the X11 replacement for the Wayland [`desktop`](../desktop)
image. Built `FROM ghcr.io/zeishdev/base:latest`.

## What it is

A headless X11 desktop for agent (`computer_use`) automation:

| Component | Role |
|-----------|------|
| `Xvfb :1` | headless X server (`+extension XTEST` **required**; `-auth $XAUTHORITY`, **not** `-ac`) |
| `xfwm4`   | stand-alone window manager (no panel, no session) |
| `picom`   | compositor, `--backend xrender` (no GLX/DRI in a container) |
| `x11vnc`  | RFB capture of `:1`, bound to `127.0.0.1` only |
| `websockify` + noVNC | the single external face, on `:6080` |
| `sandboxd` | the one guest agent — drives `:1` in-process over XTEST + core `GetImage`. **Started by initd, not supervisord** (see below). |

## How it differs from `desktop`

| | `desktop` | `desktop-x11` |
|--|--|--|
| Display server | Wayland (labwc, headless `WLR_BACKENDS`) | X11 (`Xvfb :1`) |
| Capture | `wayvnc` over `wlr-screencopy` | `x11vnc` over RFB |
| Session | full Budgie desktop | bare `xfwm4` + `picom` |
| Input/screenshot | out-of-process `desktop-agentd` over a Wayland socket + UDS | **in-process** in `sandboxd` (no separate daemon, no UDS hop) |
| Keyboard | shells out to `wtype` | XTEST directly (`x11rb`, pure Rust) |
| Clipboard | n/a | `xclip` (sandboxd shells out) |

`desktop-agentd` does not exist here. There is no Wayland, `labwc`, `wayvnc`, or
`wtype` in this image.

## Ports

| Port | Bind | What |
|------|------|------|
| `6080` | `0.0.0.0` (EXPOSEd) | unauthenticated noVNC / websockify — reachable only through proxyd's authenticated DesktopSession route; guest networking must not expose this port directly |
| `5900` | `127.0.0.1` | raw VNC (x11vnc), loopback only |
| `9222 + <display-number>` | `127.0.0.1` | Chrome DevTools Protocol. `DISPLAY=:1` → **9223**. Never bound to a routable address. |

## `sandboxd` is injected and initd-managed, not baked

The `sandboxd` binary is **not** part of this image and **not** a supervisord
unit. `machined` injects the host's current build into
`/usr/local/sbin/sandboxd` at guest boot, and initd (PID 1) owns its
lifecycle on every image — it sidecar-starts sandboxd with `RestartSandboxd`
hot-update support and forwards `DISPLAY` / `XAUTHORITY` / `XDG_RUNTIME_DIR` /
`SANDBOXD_*` from this image's ENV into it. That is why `DISPLAY=:1` and
`XDG_RUNTIME_DIR` are set in the image ENV: initd's allowlist forwards them so
sandboxd attaches to the Xvfb display this image brings up. A supervisord copy
would be a second instance colliding on `:8899` / `:8900` / `:22`.

In a plain `docker run` (no initd, no injection) sandboxd simply is not
present; the X11 desktop and `zeish-chrome` still come up.

## `zeish-chrome`

`/usr/local/bin/zeish-chrome` — agent Chrome launcher (parity with the
reference `box-chrome`):

- `zeish-chrome --sand-prepare` — background Chrome, CDP reachable, no window.
- `zeish-chrome --new-window [url]` — ensure Chrome is up, open a visible window on `$DISPLAY`.
- `zeish-chrome <url>` — visible window navigated to `<url>`.
- `zeish-chrome --close` — stop this display's Chrome for good (what sandboxd's
  `CloseBrowser` calls).

CDP is bound `127.0.0.1:$((9222 + <display-number>))`; persistent per-display
profile at `/var/lib/zeish/agent-data/chrome-profile-<display-number>`; stale
`Singleton*` locks cleared on start. `zeish-chrome-policy` re-asserts the baked
enterprise policy.

Two pidfiles per display, because they are two different processes:

| file | pid |
|---|---|
| `/tmp/zeish-chrome-<cdp>.pid` | the **browser** — what `--close` signals |
| `/tmp/zeish-chrome-<cdp>.watchdog.pid` | the supervising shell |
| `/tmp/zeish-chrome-<cdp>.stop` | stop flag; its presence tells the watchdog not to restart |

The watchdog restarts Chrome only on a **crash** (non-zero exit, no stop
requested), bounded at 5. A clean exit or a `--close` ends it — otherwise
`CloseBrowser` could never actually close anything.

## X access control

Xvfb runs **without `-ac`**. Every X client authenticates with an
MIT-MAGIC-COOKIE from `$XAUTHORITY` (`/run/zeish/Xauthority`, root-owned 0600),
re-seeded on every boot by `entrypoint.sh` so a cookie can't be inherited
through a snapshot. `-ac` would let anything in the guest — the tenant's own
code in `/workspace` included — screenshot the agent's browser session, inject
input, and drive other fork displays. sandboxd gets the path through the
`XAUTHORITY` initd forwards; the fork broker adds its own per-display cookie to
the same file before starting a fork's Xvfb.

## Environment

| Variable | Default | Description |
|----------|---------|-------------|
| `DISPLAY` | `:1` | X display (also drives the CDP port) |
| `VNC_RESOLUTION` | `1280x800` | Xvfb screen geometry |
| `VNC_DEPTH` | `24` | Xvfb colour depth |
| `VNC_PORT` | `5900` | loopback x11vnc port |
| `PROXY_PORT` | `6080` | noVNC / websockify port |

Port 6080 intentionally has no second websockify password or token. The
security boundary is proxyd's authenticated DesktopSession route plus the
microVM network isolation. Deployments must not publish the guest address or
port 6080 to a tenant or shared node network.

## Build / run

```sh
make -C images/base build          # base first
make -C images/desktop-x11 build
make -C images/desktop-x11 run     # noVNC on http://localhost:6080
# or: cd images/desktop-x11 && docker compose up
```
