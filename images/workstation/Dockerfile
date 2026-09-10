FROM ghcr.io/zeishdev/base:latest

ARG DEBIAN_FRONTEND=noninteractive

# No `USER` directive: base already never sets one, and everything below runs
# as the implicit-root default (sshd needs root to bind :22 and manage host
# keys anyway). See base/Dockerfile for why an explicit baked Config.User
# (even non-root) breaks depot's initd workload exec.

# ── SSH access (headless workstation only) ────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd \
    && sed -i 's/^AcceptEnv LANG LC_\*$/#AcceptEnv LANG LC_*/' /etc/ssh/sshd_config

EXPOSE 22
WORKDIR /workspace
