#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./tor_socks_pool.sh -l US,DE,JP -p 1010,1011,1012 -i 10
#
#   -l  Comma-separated list of ISO country codes for exit nodes (e.g. US,DE,JP)
#   -p  Comma-separated list of local SOCKS5 ports (must match number of locations)
#   -i  Interval in minutes to rotate IPs via NEWNYM (1-60 minutes)

print_usage() {
  echo "Usage: $0 -l LOC1,LOC2,.. -p PORT1,PORT2,.. -i INTERVAL_MINUTES"
  echo
  echo "Example:"
  echo "  $0 -l US,DE,JP -p 1010,1020,1030 -i 5"
  echo "    -> Three Tor instances on ports 1010,1020,1030 with exit nodes in"
  echo "       US, DE, JP, each rotating IP every 5 minutes."
  exit 1
}

check_dependencies() {
  for cmd in tor nc ss; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: $cmd is not installed. Please install it and try again."
      exit 1
    fi
  done
}

check_port() {
  local port=$1
  if ss -tuln | grep -q ":$port "; then
    echo "Error: Port $port is already in use."
    return 1
  fi
  return 0
}

control_port() {
  echo $(( 9051 + $1 ))
}

cleanup() {
  echo "Stopping all Tor instances and cleaning up..."
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  rm -rf /tmp/tor_instance_* 2>/dev/null || true
  echo "Cleanup completed."
  exit 0
}

LOCS=""
PORTS=""
INTERVAL=0
while getopts "l:p:i:" opt; do
  case "$opt" in
    l) LOCS="$OPTARG" ;;
    p) PORTS="$OPTARG" ;;
    i) INTERVAL="$OPTARG" ;;
    *) print_usage ;;
  esac
done
[[ -z "$LOCS" || -z "$PORTS" || "$INTERVAL" -le 0 ]] && print_usage

if [[ "$INTERVAL" -lt 1 || "$INTERVAL" -gt 60 ]]; then
  echo "Error: INTERVAL must be between 1 and 60 minutes."
  exit 1
fi

IFS=',' read -r -a LOC_ARRAY <<< "$LOCS"
IFS=',' read -r -a PORT_ARRAY <<< "$PORTS"

if [[ ${#LOC_ARRAY[@]} -ne ${#PORT_ARRAY[@]} ]]; then
  echo "Error: Number of locations must match number of ports."
  exit 1
fi

check_dependencies

for port in "${PORT_ARRAY[@]}"; do
  if ! check_port "$port"; then
    exit 1
  fi
done

declare -a PIDS

echo "Starting ${#LOC_ARRAY[@]} Tor SOCKS5 instances..."

for idx in "${!LOC_ARRAY[@]}"; do
  LOC="${LOC_ARRAY[$idx]}"
  SOCKSPORT="${PORT_ARRAY[$idx]}"
  CP=$(control_port $idx)
  DATADIR="/tmp/tor_instance_$idx"

  mkdir -p "$DATADIR"

  cat > "$DATADIR/torrc" <<EOF
SocksPort $SOCKSPORT
ControlPort $CP
DataDirectory $DATADIR
ExitNodes {$LOC}
StrictNodes 1
Log notice file $DATADIR/tor.log
EOF

  echo "  - Instance #$idx: ExitNodes={$LOC}, SocksPort=$SOCKSPORT, ControlPort=$CP"
  tor -f "$DATADIR/torrc" &>/dev/null &
  PIDS[$idx]=$!
  if ! kill -0 "${PIDS[$idx]}" 2>/dev/null; then
    echo "  [error] Failed to start Tor instance on port $SOCKSPORT"
    cleanup
  fi
done

echo
echo "All Tor instances launched."
echo "Summary of SOCKS5 tunnels:"
for idx in "${!LOC_ARRAY[@]}"; do
  echo "  • localhost:${PORT_ARRAY[$idx]} → ExitNode=${LOC_ARRAY[$idx]} (ControlPort=$(control_port $idx))"
done
echo
echo "IP rotation interval: every $INTERVAL minutes."
echo

trap cleanup SIGINT SIGTERM

while true; do
  sleep "$(( INTERVAL * 60 ))"
  echo "Rotating IPs for all Tor instances..."
  for idx in "${!LOC_ARRAY[@]}"; do
    CP=$(control_port $idx)
    SOCKSPORT="${PORT_ARRAY[$idx]}"
    if ! kill -0 "${PIDS[$idx]}" 2>/dev/null; then
      echo "  [error] Tor instance on port $SOCKSPORT is not running"
      continue
    fi
    if printf 'AUTHENTICATE ""\nSIGNAL NEWNYM\nQUIT\n' | nc localhost "$CP"; then
      echo "  [ok] Rotated instance on port $SOCKSPORT"
    else
      echo "  [error] Failed to rotate instance on port $SOCKSPORT"
    fi
  done
done
