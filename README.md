# xhcoding.network

Fork of the first-party [`omarchy.network`](https://github.com/omacom/omarchy)
bar widget (MIT licensed). Adds a wrapper (`network-status.sh`) that pins
interface detection to the physical NIC, so a transparent-proxy TUN
(Clash-family proxy, tailscale, wireguard, openvpn) with policy-routing rules
no longer hides the real connection.

## How it works

- `Panel.qml` — the Wi-Fi/network panel (upstream, lightly annotated).
- `Model.js` — parsing and formatting helpers (upstream).
- `network-status.sh` — runs the stock `omarchy-network-status` with `ip` and
  `ping` shims that pin the route lookup and ICMP to the physical interface
  carrying the default route. Override with `OMARCHY_NETWORK_IFACE`
  (interface) and `OMARCHY_NETWORK_PROBE` (probe address, default `8.8.8.8`).

## Install

```bash
omarchy plugin add https://github.com/xhcoding/xhcoding.network
```

## License

MIT. Forked from [omacom/omarchy](https://github.com/omacom/omarchy)
(MIT licensed) — see [LICENSE](LICENSE).
