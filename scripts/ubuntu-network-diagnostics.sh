#!/usr/bin/env bash
#
# Ubuntu VPS network diagnostics (read-only)
# Collects interface, route, resolver and service status.
# It does not change network configuration or contact external hosts.
#
# Usage:
#   bash ubuntu-network-diagnostics.sh
#
# Review and redact IP addresses, hostnames and other sensitive details
# before sharing the output publicly.

set -u

section() {
  printf '\n\n===== %s =====\n' "$1"
}

run() {
  printf '\n$'
  printf ' %q' "$@"
  printf '\n'
  "$@" 2>&1 || true
}

section "Timestamp and system"
date -Is 2>&1 || true
hostnamectl --static 2>&1 || hostname 2>&1 || true
uname -a 2>&1 || true
if [[ -r /etc/os-release ]]; then
  sed -n '1,8p' /etc/os-release
fi

section "Network interfaces"
run ip -br link
run ip -br address
run ip -s link

section "Routing"
run ip route
run ip -6 route
run ip rule

section "DNS resolver"
if command -v resolvectl >/dev/null 2>&1; then
  run resolvectl status
elif [[ -r /etc/resolv.conf ]]; then
  printf '\n$ cat /etc/resolv.conf\n'
  cat /etc/resolv.conf
else
  echo "No resolvectl command or readable /etc/resolv.conf found."
fi

section "Network service status"
run systemctl is-active systemd-networkd
run systemctl is-active NetworkManager
run systemctl is-active networking
run networkctl list

if command -v nmcli >/dev/null 2>&1; then
  run nmcli device status
fi

section "Netplan inventory"
if [[ -d /etc/netplan ]]; then
  find /etc/netplan -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true
  if command -v netplan >/dev/null 2>&1; then
    run netplan get
  fi
else
  echo "/etc/netplan does not exist."
fi

section "Recent network-related kernel messages"
if command -v journalctl >/dev/null 2>&1; then
  journalctl -k -b --no-pager 2>/dev/null \
    | grep -Ei 'virtio|network|link is|rename|driver|firmware' \
    | tail -n 100 || true
fi

section "Firewall status (read-only)"
if command -v nft >/dev/null 2>&1; then
  run nft list ruleset
fi
if command -v ufw >/dev/null 2>&1; then
  run ufw status verbose
fi

section "Completion"
echo "Diagnostics completed. No network settings were changed."
echo "Redact sensitive addresses, hostnames and customer data before sharing."
