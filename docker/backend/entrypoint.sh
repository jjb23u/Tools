#!/usr/bin/env bash
set -euo pipefail

: "${VNC_GEOMETRY:=1600x900}"
: "${VNC_PASSWORD:=changeme}"

mkdir -p "$HOME/.vnc"
echo "$VNC_PASSWORD" | vncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

vncserver -kill :1 >/dev/null 2>&1 || true
vncserver :1 -geometry "$VNC_GEOMETRY" -depth 24 -localhost no
exec tail -F "$HOME/.vnc/"*.log
