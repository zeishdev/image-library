FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=en_US.UTF-8 \
    TERM=xterm-256color \
    HOME=/home/user \
    USER=user \
    NVM_DIR=/home/user/.nvm \
    PYENV_ROOT=/home/user/.pyenv \
    GOROOT=/home/user/.go \
    GOPATH=/home/user/go \
    PATH="/home/user/.pyenv/bin:/home/user/.pyenv/shims:/home/user/.go/bin:/home/user/go/bin:/home/user/.local/bin:${PATH}"

# ── Base system + dev utilities ──────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg \
        apt-transport-https software-properties-common lsb-release \
        # shell & terminal
        bash bash-completion zsh tmux \
        # editors
        vim neovim nano \
        # vcs
        git git-lfs \
        # build
        build-essential make cmake pkg-config \
        # system python
        python3 python3-pip python3-venv python3-dev xz-utils \
        # search & navigation
        ripgrep fd-find fzf tree \
        # data & network
        jq netcat-openbsd dnsutils net-tools iputils-ping \
        # system
        sudo locales tzdata procps htop lsof \
        openssh-client \
        # file utilities
        unzip zip tar gzip rsync file less man-db \
        # misc
        acl iproute2 kmod udev dbus \
        util-linux rng-tools \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── GitHub CLI ────────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Docker CE ─────────────────────────────────────────────────────────────────
# Use the convenience script — handles ubuntu 26.04 without a published repo entry
RUN curl -fsSL https://get.docker.com | sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── yq ────────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH} \
        -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# ── filebrowser (web file manager, opt-in per variant) ────────────────────────
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# ── Chrome ─────────────────────────────────────────────────────────────────
# Google only publishes Chrome for linux/amd64 — there is no arm64 build, and
# Ubuntu's `chromium-browser` package is a snap-transitional stub that can't
# actually run inside a container (no snapd). So: real Google Chrome Stable
# on amd64; on arm64, fall back to Playwright's prebuilt Chromium (installed
# later, once nvm/node exist) and symlink it to the same `google-chrome` name
# so callers don't need to branch on architecture.
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then \
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/google-chrome.gpg \
        && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
            > /etc/apt/sources.list.d/google-chrome.list \
        && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
        && apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

# ── Python tooling (system-wide) ─────────────────────────────────────────────
RUN pip3 install --no-cache-dir --break-system-packages uv pipx

# ── User setup ────────────────────────────────────────────────────────────────
RUN echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections \
    && echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections \
    && userdel -r ubuntu 2>/dev/null || true \
    && useradd -u 1000 -m -s /bin/bash -G sudo,docker,users user \
    && echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd \
    && chmod 440 /etc/sudoers.d/nopasswd \
    && echo "root:root" | chpasswd \
    # A machine-id must be a real 32-hex-char ID, not empty — an empty file
    # is invalid, not "auto-generate on boot" (that requires a dbus init
    # script we don't run). An empty file makes dbus-daemon refuse to start
    # a session bus at all, silently breaking anything that depends on one
    # (dconf, GTK app state, etc). All containers from this image share the
    # same baked ID, which is fine here — uniqueness matters for real hosts
    # tracking hardware, not ephemeral sandbox containers.
    && python3 -c "import uuid; print(uuid.uuid4().hex)" | tee /etc/machine-id \
    && mkdir -p /var/lib/dbus \
    && cp /etc/machine-id /var/lib/dbus/machine-id

# ── User-owned toolchain installs ──────────────────────────────────────────────
# Deliberately no `USER user` directive anywhere in this image: a container's
# final baked Config.User (from the last USER instruction in the whole FROM
# chain) changes how depot's initd execs the workload — an explicit user
# (even "root") makes it go through a full /etc/passwd lookup + explicit
# setuid/setgid/setgroups credential path, instead of just inheriting initd's
# own already-root identity. That extra path is where sandboxes built on top
# of this image failed to boot in production. `su -p user -c '...'` gets the
# same per-step non-root ownership (files under /home/user end up uid 1000)
# without ever touching the image's baked Config.User — every RUN here still
# executes as the implicit-root default, exactly like a plain ubuntu image.

# ── Node.js via nvm (version-switchable) ──────────────────────────────────────
RUN su -p user -c '\
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install --lts \
    && nvm alias default "lts/*" \
    '

# ── Chrome, arm64 fallback: Playwright's prebuilt Chromium ────────────────────
# `--with-deps` needs root for the system libs it installs; user has
# passwordless sudo (configured above), which playwright's installer uses.
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" != "amd64" ]; then \
        su -p user -c '\
            . "$NVM_DIR/nvm.sh" \
            && npx --yes playwright install --with-deps chromium \
            && CHROME_BIN=$(find "$HOME/.cache/ms-playwright" -type f \( -name chrome -o -name chromium \) 2>/dev/null | head -1) \
            && sudo ln -sf "$CHROME_BIN" /usr/local/bin/google-chrome-stable \
            && sudo ln -sf /usr/local/bin/google-chrome-stable /usr/local/bin/google-chrome \
            '; \
    fi

# ── Agent CDP helper (Arin / Playwright connectOverCDP) ───────────────────────
# Shared by desktop + workstation (both FROM base). Starts Chrome with
# --remote-debugging-port; see scripts/zeish-chrome-cdp.
COPY scripts/zeish-chrome-cdp /usr/local/bin/zeish-chrome-cdp
RUN chmod +x /usr/local/bin/zeish-chrome-cdp

# ── Python via pyenv (version-switchable, alongside system python3) ──────────
# The -dev headers below are only needed to compile CPython; installing and
# purging them within this single RUN keeps them out of the image entirely
# (a separate later `apt purge` would only mark them deleted, not shrink the
# layer they were installed in).
RUN apt-get update && apt-get install -y --no-install-recommends \
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
        libncurses-dev libffi-dev liblzma-dev tk-dev \
    && su -p user -c '\
        export PATH="$PYENV_ROOT/bin:$PATH" \
        && curl https://pyenv.run | bash \
        && eval "$(pyenv init -)" \
        && pyenv install 3.12.7 \
        && pyenv global 3.12.7 \
        ' \
    && apt-get purge -y --auto-remove \
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
        libncurses-dev libffi-dev liblzma-dev tk-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Go via g (version-switchable) ─────────────────────────────────────────────
# GOROOT=$HOME/.go, GOPATH=$HOME/go (g's defaults) — both already on PATH.
# SHELL must be set: g's installer picks a dotfile to configure based on it,
# and Docker's /bin/sh -c leaves it unset ("no shell has been selected").
# The installer itself downloads and activates the latest stable Go release —
# no separate `g install` needed.
RUN su -p user -c '\
    export SHELL=/bin/bash \
    && curl -fsSL https://github.com/stefanmaric/g/releases/latest/download/install | sh -s -- -y \
    '

# ── AI agent CLIs (need nvm's node on PATH) ───────────────────────────────────
RUN su -p user -c '\
    . "$NVM_DIR/nvm.sh" && npm install -g \
        @anthropic-ai/claude-code \
        @openai/codex \
        @google/gemini-cli \
    && npm cache clean --force \
    '

# ── Grok Build (xAI's official coding agent CLI) ──────────────────────────────
RUN su -p user -c 'curl -fsSL https://x.ai/cli/install.sh | bash || true'

# ── Shell profile: make nvm/pyenv/g available in every login & exec shell ────
# No `chown -R /home/user` here: everything under it was already installed as
# `user` above (via su -p), so it's correctly owned. A blanket recursive chown
# on a multi-GB tree forces overlay2 to copy-up every file into a new layer
# for a no-op ownership change — roughly doubling the image size for nothing.
COPY profile.d/depot-toolchain.sh /etc/profile.d/depot-toolchain.sh
COPY profile.d/prompt.sh /etc/profile.d/prompt.sh
RUN chmod 644 /etc/profile.d/depot-toolchain.sh /etc/profile.d/prompt.sh \
    && mkdir -p /workspace && chown user:user /workspace \
    # profile.d only runs for login shells; desktop terminal tabs and plain
    # `docker exec` shells are typically non-login, so also source it from
    # bash.bashrc. But Ubuntu's per-user ~/.bashrc (root's, and the copy
    # useradd already made at /home/user/.bashrc from /etc/skel) sets PS1
    # itself and is sourced AFTER bash.bashrc for non-login shells — so it
    # silently wins unless we also append there, last, so it overrides them
    # instead of the other way around. /etc/hostname is a static fallback
    # for non-bash contexts.
    && SOURCE_LINE='\n[ -f /etc/profile.d/prompt.sh ] && . /etc/profile.d/prompt.sh\n' \
    && printf "$SOURCE_LINE" >> /etc/bash.bashrc \
    && printf "$SOURCE_LINE" >> /etc/skel/.bashrc \
    && printf "$SOURCE_LINE" >> /root/.bashrc \
    && printf "$SOURCE_LINE" >> /home/user/.bashrc \
    && chown user:user /home/user/.bashrc \
    && echo "zeish" > /etc/hostname \
    # Cosmetic only — NAME/ID/VERSION_ID stay untouched since apt, the
    # Mozilla repo pin, and other tooling key off them for compatibility.
    && sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Zeish Desktop"/' /etc/os-release

WORKDIR /workspace
