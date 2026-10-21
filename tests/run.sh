#!/usr/bin/env bash
# Import (registers class_name scripts), then run the headless test suite.
set -uo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")/.."
godot --headless --path . --import >/dev/null 2>&1
exec godot --headless --path . -s tests/run_tests.gd -- "$@"
