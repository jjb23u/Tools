#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/jjb23u/CHANGE_ME.git"
PLAYBOOK="site.yml"

if ! command -v ansible-pull >/dev/null 2>&1; then
    sudo dnf install -y ansible git
fi

ansible-pull -U "$REPO_URL" -i "localhost," --limit localhost "$PLAYBOOK" "$@"
