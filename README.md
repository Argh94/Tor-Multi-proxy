# Tor Multi-Proxy

A robust and flexible Bash script for creating and managing a pool of Tor-based SOCKS5 proxies with country-specific exit nodes and automatic IP rotation.

---

## Features

- **Multiple Tor Instances**: Launch several Tor SOCKS5 proxies, each on a unique local port, with country-specific exit nodes.
- **Automatic IP Rotation**: Periodically rotate exit IPs using Tor's `NEWNYM` signal (1–60 min intervals).
- **Port Validation**: Checks if specified ports are free before launching instances.
- **Process Monitoring**: Tracks Tor instance PIDs to ensure they're running before IP rotation.
- **Graceful Cleanup**: Cleans up temp directories and stops Tor processes on script termination (e.g., Ctrl+C).
- **Dependency Validation**: Ensures `tor`, `nc`, `ss` are installed before execution.
- **Configurable Intervals**: Restricts rotation intervals to 1–60 minutes.
- **Detailed Logging**: Tor logs stored at `/tmp/tor_instance_<idx>/tor.log`.
- **User-Friendly Output**: Summarizes launched proxies and their configs.

---

## Purpose

Launch multiple Tor SOCKS5 proxies, each bound to a specified port and configured for a specific country exit node (e.g., US, DE, JP). Supports automatic IP rotation, ideal for privacy, web scraping, V2Ray/Xray, or any anonymized traffic routing scenario.

**Workflow Example:**

`User Application (e.g., V2Ray) → Xray Core → Tor SOCKS5 Proxies (US, DE, JP) → Internet`

---

## Prerequisites

- **tor**: Tor daemon (v0.4.x recommended)
- **netcat (nc)**: For sending control signals (e.g., netcat-openbsd or netcat-traditional)
- **iproute2 (ss)**: For port checking
- **bash**: v4.0 or higher
- **tmux** (optional): For persistent sessions

---

## Installation on Debian/Ubuntu

```bash
sudo apt-get update
sudo apt-get install tor netcat-openbsd iproute2 tmux
```

### Clone the Repository

```bash
git clone https://github.com/Argh94/tor-multi-proxy.git
cd tor-multi-proxy
```

### Make the Script Executable

```bash
chmod +x tor-multi-proxy.sh
```

---

## Usage

```bash
./tor-multi-proxy.sh -l LOC1,LOC2,... -p PORT1,PORT2,... -i INTERVAL_MINUTES
```

- `-l`: Comma-separated ISO country codes for exit nodes (e.g., US,DE,JP)
- `-p`: Comma-separated local SOCKS5 ports (must match countries count)
- `-i`: IP rotation interval (1–60 min)

### Example

Launch three proxies for US, Germany, Japan on ports 1010, 1020, 1030, rotating IPs every 5 minutes:

```bash
./tor-multi-proxy.sh -l US,DE,JP -p 1010,1020,1030 -i 5
```

---

## Running in a Persistent Session

Use tmux to keep proxies running after closing terminal:

```bash
tmux new -s tor-proxy "./tor-multi-proxy.sh -l US,DE,JP -p 1010,1020,1030 -i 5"
```

- Detach: `Ctrl+B D`
- Reattach: `tmux attach -t tor-proxy`

Or use `screen` or run as a background process.

---

## Configuration in V2Ray/Xray

Configure outbounds in V2Ray/Xray to use the SOCKS5 proxies.

**Example for V2Ray:**

```json
{
  "outbounds": [
    {
      "protocol": "socks",
      "settings": {
        "servers": [
          { "address": "127.0.0.1", "port": 1010 },
          { "address": "127.0.0.1", "port": 1020 },
          { "address": "127.0.0.1", "port": 1030 }
        ]
      }
    }
  ]
}
```

This routes traffic through the Tor proxies on ports 1010 (US), 1020 (DE), and 1030 (JP).

---

## Verifying Exit IPs

Check the current exit IP for a specific proxy:

```bash
curl --socks5-hostname localhost:1010 https://api.ipify.org
```

---

## Troubleshooting

- **Port Conflicts**: If a port is in use, the script exits with error. Check with `ss -tuln`.
- **Tor Failures**: If a Tor instance fails, check `/tmp/tor_instance_<idx>/tor.log`.
- **Missing Dependencies**: Ensure `tor`, `nc`, and `ss` are installed.
- **IP Rotation Issues**: If rotation fails, verify Tor is running (`ps aux | grep tor`) and control port connectivity.

---

## Security Considerations

- **Control Port Authentication**: By default, no password (`AUTHENTICATE ""`). For production, enable password in `torrc`.
- **Resource Usage**: Multiple instances consume more CPU/memory.
- **Temporary Files**: Data stored in `/tmp/tor_instance_<idx>`, cleaned up on exit. Ensure `/tmp` has space.

---

## Future Improvements (TODO)

- Support for IPv6 exit nodes
- systemd service for auto startup/management
- ISO country code validation
- Log rotation for Tor logs
- Custom data directories (not only `/tmp`)

---

## Contributing

Contributions welcome! Open an issue or PR on GitHub. For major changes, discuss first to align with project goals.

---

## License

MIT License. See [LICENSE](LICENSE).

---

## Acknowledgments

Inspired by the Tor Project and the open-source community. Thanks to contributors and users for feedback and support.
