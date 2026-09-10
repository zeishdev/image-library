FROM ghcr.io/zeishdev/base:latest

ARG DEBIAN_FRONTEND=noninteractive

# DISPLAY/VNC_* are read by the supervisord units and by `zeish-chrome`
# (CDP port = 9222 + <display-number>, so :1 -> 9223). VNC_PORT is loopback
# only; PROXY_PORT (noVNC/websockify) is the single external face.
ENV DISPLAY=:1 \
    VNC_PORT=5900 \
    PROXY_PORT=6080 \
    VNC_RESOLUTION=1280x800 \
    VNC_DEPTH=24 \
    XDG_RUNTIME_DIR=/run/user/1000

# No `USER` directive: base already never sets one, and everything below runs
# as the implicit-root default. See base/Dockerfile for why an explicit baked
# Config.User (even "root") breaks the initd workload exec path.

# ── X11 desktop stack ────────────────────────────────────────────────────────
# Xvfb is the headless X server; xfwm4 is a minimal stand-alone window manager
# (no panel/session — this is an agent-driven surface, not a human login); picom
# gives real compositing over the xrender backend (no GLX/DRI in a headless
# container); x11vnc captures :1 over RFB and feeds the same websockify/noVNC
# path the retired desktop image used, so proxyd auth stays untouched.
#
#   x11-utils      → xdpyinfo, the "is :1 up yet?" probe every unit waits on
#   x11-xserver-utils → xset/xrdb/xsetroot
#   xclip          → sandboxd's clipboard get/set shells out to this
#   xkb-data       → keymap tables XTEST keycode translation needs
#   dbus-x11       → dbus-launch + a session bus for GTK app state
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb \
        xfwm4 \
        xfce4-terminal \
        thunar \
        picom \
        x11vnc \
        python3-websockify \
        x11-xserver-utils \
        x11-utils \
        xauth \
        xclip \
        xkb-data \
        dbus \
        dbus-x11 \
        fonts-liberation \
        fonts-dejavu-core \
        fonts-noto \
        fonts-noto-color-emoji \
        supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── noVNC (spinupdev fork, zeish-desktop branch: stripped UI, auto-connect) ──
# Pinned to a commit, not the branch tip: GH Actions' layer cache (type=gha)
# keys on this instruction's literal text, so `--branch zeish-desktop` alone
# would keep serving a stale clone from cache forever after the fork moves —
# bump this SHA whenever zeish-desktop gets new commits that need to ship.
# Kept byte-for-byte identical to images/desktop so the viewer is the same.
RUN git clone https://github.com/spinupdev/noVNC.git /opt/novnc && \
    git -C /opt/novnc checkout 5280513 && \
    ln -sf /opt/novnc/vnc.html /opt/novnc/index.html

# ── VS Code (Microsoft's official build, not VSCodium) ───────────────────────
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor > /usr/share/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list \
    && apt-get update && apt-get install -y --no-install-recommends code \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Claude Code + Codex CLIs (official native builds, no Node.js needed) ─────
# Neither Anthropic nor OpenAI ships an official Linux desktop app for these
# (both are Mac/Windows-only) — CLIs only, installed system-wide under
# /usr/local/bin rather than the installer's default ~/.local/bin so every
# shell/user picks them up without PATH changes.
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL https://claude.ai/install.sh | bash \
    && mv /home/user/.local/bin/claude /usr/local/bin/claude \
    && CODEX_ARCH=$([ "$ARCH" = "arm64" ] && echo aarch64 || echo x86_64) \
    && CODEX_VERSION=$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"rust-v([^"]+)".*/\1/') \
    && curl -fsSL "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${CODEX_ARCH}-unknown-linux-musl.tar.gz" \
        | tar -xz -C /tmp \
    && mv /tmp/codex-${CODEX_ARCH}-unknown-linux-musl /usr/local/bin/codex \
    && chmod +x /usr/local/bin/codex

# ── Default browser (arch-dependent — see base/Dockerfile's Chrome comment:
# amd64 gets real Google Chrome; arm64's "chrome" is Playwright's automation
# Chromium). Chrome itself comes from `base`; do NOT reinstall it here. ───────
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then \
        update-alternatives --set x-www-browser /usr/bin/google-chrome-stable 2>/dev/null || true; \
    fi

# ── Chrome enterprise policy (skip first-run metrics/sign-in/default-browser
# nags). The baked file is authoritative; `zeish-chrome-policy` can re-assert
# it from the copy kept under /usr/local/share for parity with box-chrome. ───
RUN mkdir -p /etc/opt/chrome/policies/managed /usr/local/share/zeish/chrome-policies
COPY config/chrome-policies/managed.json /etc/opt/chrome/policies/managed/managed.json
COPY config/chrome-policies/managed.json /usr/local/share/zeish/chrome-policies/managed.json

# ── Configs and scripts ──────────────────────────────────────────────────────
COPY config/supervisord.conf /etc/supervisor/supervisord.conf
COPY run.json /etc/run.json
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/websockify-fork.py /usr/local/bin/websockify-fork
COPY scripts/zeish-chrome /usr/local/bin/zeish-chrome
COPY scripts/zeish-chrome-policy /usr/local/bin/zeish-chrome-policy
RUN chmod +x /entrypoint.sh /usr/local/bin/websockify-fork \
        /usr/local/bin/zeish-chrome /usr/local/bin/zeish-chrome-policy

# Canonical runtime paths. /workspace already exists from base; agent-data is
# the volume-backed agent root (window registry, Chrome profile, jobs). Owned
# by the desktop user so an unprivileged session and the root sandboxd both
# write it.
RUN mkdir -p /var/log/supervisor /workspace /var/lib/zeish/agent-data \
    && chown -R ${USER}:${USER} /workspace /var/lib/zeish/agent-data

EXPOSE ${PROXY_PORT}

# Image-owned liveness: the X server must answer AND every supervised unit
# (dbus/xvfb/xfwm4/picom/x11vnc/websockify) must be RUNNING — a bare
# `test -S /run/supervisor.sock` reported "healthy" even when x11vnc or
# websockify had crash-looped into FATAL and the noVNC desktop was dead.
# sandboxd is injected and supervised by initd, so its liveness is reported
# by the guest supervisor rather than here.
HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=3 \
    CMD xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 || exit 1; \
        s=$(supervisorctl -c /etc/supervisor/supervisord.conf status 2>/dev/null); \
        echo "$s" | grep -q RUNNING || exit 1; \
        echo "$s" | grep -qE 'BACKOFF|FATAL|EXITED|STOPPED|UNKNOWN' && exit 1; \
        exit 0

# Docker Desktop: entrypoint.sh directly.
# microVM: initd (PID 1) reads /etc/run.json → /entrypoint.sh.
ENTRYPOINT ["/entrypoint.sh"]
