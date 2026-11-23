#!/usr/bin/env bash
set -euo pipefail

: "${BACKEND_HOST:=backend}"
: "${BACKEND_PORT:=5901}"

websockify --web /usr/share/novnc 6080 "${BACKEND_HOST}:${BACKEND_PORT}" &
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
