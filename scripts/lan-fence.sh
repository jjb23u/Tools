#!/usr/bin/env bash
set -euo pipefail

# Blocks the toolkit's egress network from reaching your local LAN while
# leaving its internet access intact. Run on the Docker host with root.
# Re-run after a Docker daemon restart (the DOCKER-USER chain is flushed then).

: "${EGRESS_SUBNET:=172.31.66.0/24}"
: "${LAN_SUBNET:?set LAN_SUBNET, e.g. LAN_SUBNET=192.168.1.0/24}"

iptables -C DOCKER-USER -s "$EGRESS_SUBNET" -d "$LAN_SUBNET" -j DROP 2>/dev/null \
  || iptables -I DOCKER-USER -s "$EGRESS_SUBNET" -d "$LAN_SUBNET" -j DROP

echo "Fenced $EGRESS_SUBNET from $LAN_SUBNET"
