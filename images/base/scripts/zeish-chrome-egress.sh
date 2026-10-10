#!/usr/bin/env bash

# Chrome ignores the conventional HTTP proxy environment. Both browser launchers
# use these flags so public requests traverse the machine's policy proxy.
zeish_chrome_egress_flags() {
  [ -n "${ZEISH_EGRESS_PROXY:-}" ] || return 0
  printf '%s\n' \
    "--proxy-server=${ZEISH_EGRESS_PROXY}" \
    '--proxy-bypass-list=localhost;127.0.0.1;[::1];*.internal' \
    '--disable-quic'
}
