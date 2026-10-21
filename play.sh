#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
godot --headless --path . --import >/dev/null 2>&1 || true  # registers new scripts and assets
exec godot --path . "$@"
