#!/bin/bash
# Physical-interface network status for the cloned xhcoding.network panel.
#
# `omarchy-network-status` detects the active device with `ip route get 1.1.1.1`.
# A transparent-proxy TUN (a Clash-family proxy here, but also
# tailscale/wireguard/openvpn) installs policy-routing rules that send
# locally-generated traffic through the tunnel, so that lookup returns the
# tunnel interface instead of the real NIC. The panel then reports the
# tunnel's 198.18.0.0/30 address and link speed rather than the physical
# connection.
#
# Pinning the route lookup to the physical interface (`ip route get 1.1.1.1 oif
# eth0`) keeps the main routing table in play and makes `ip` report the
# interface's real `prefsrc`, so upstream keeps doing all the work and only the
# device lookup changes. Everything else the command prints -- address, prefix,
# gateway, rx/tx bytes, link speed/duplex, Wi-Fi details, ping samples -- is
# reused untouched.
#
# Override the interface with OMARCHY_NETWORK_IFACE; otherwise the physical NIC
# carrying the main table's default route is used.

set -u

# Virtual interfaces (tun/tap, bridges, veth, ...) have no device symlink.
is_physical() { [[ -e /sys/class/net/$1/device ]]; }

default_route=$(ip -j route show default table main 2>/dev/null)

iface=""
if [[ -n ${OMARCHY_NETWORK_IFACE:-} ]] && is_physical "$OMARCHY_NETWORK_IFACE"; then
  iface=$OMARCHY_NETWORK_IFACE
else
  while IFS= read -r dev; do
    if [[ -n $dev ]] && is_physical "$dev"; then
      iface=$dev
      break
    fi
  done < <(jq -r '[.[] | select((.dev // "") != "")] | sort_by(.metric // 0) | .[].dev' <<<"$default_route" 2>/dev/null)
fi

# No physical default route: defer to the stock command unchanged.
if [[ -z $iface ]]; then
  exec omarchy-network-status "$@"
fi

real_ip=$(command -v ip)
real_ping=$(command -v ping)
probe=${OMARCHY_NETWORK_PROBE:-8.8.8.8}
shim=$(mktemp -d)
trap 'rm -rf "$shim"' EXIT

cat >"$shim/ip" <<'SHIM'
#!/bin/bash
# Pin `route get` lookups to the physical interface so the proxy TUN's policy
# rules do not hijack interface detection. All other calls pass through.
args=()
pin=0
for arg in "$@"; do
  if ((pin)); then
    args+=("$arg" "oif" "$NET_STATUS_IFACE")
    pin=0
    continue
  fi
  args+=("$arg")
  [[ $arg == "get" ]] && pin=1
done
exec "$NET_STATUS_IP" "${args[@]}"
SHIM
chmod +x "$shim/ip"

# The stock command probes 1.1.1.1 for internet latency. Some networks (and the
# proxy TUN's policy routes) never answer that address, so the panel is stuck on
# "Timeout". Pin ICMP to the physical interface -- the same reasoning as the
# `ip` shim above -- and swap just the probe address for one that answers.
# Override the probe with OMARCHY_NETWORK_PROBE.
if [[ -n $real_ping ]]; then
  cat >"$shim/ping" <<'SHIM'
#!/bin/bash
args=()
for arg in "$@"; do
  [[ $arg == "1.1.1.1" ]] && arg=$NET_STATUS_PROBE
  args+=("$arg")
done
exec "$NET_STATUS_PING" -I "$NET_STATUS_IFACE" "${args[@]}"
SHIM
  chmod +x "$shim/ping"
fi

PATH="$shim:$PATH" NET_STATUS_IFACE="$iface" NET_STATUS_IP="$real_ip" NET_STATUS_PROBE="$probe" NET_STATUS_PING="$real_ping" exec omarchy-network-status "$@"
