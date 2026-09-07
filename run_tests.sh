#!/usr/bin/env bash
# Executa a suíte de testes headless. Uso: ./run_tests.sh [--quick] [--launches=N]
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
exec "$GODOT" --headless --path . res://tests/TestRunner.tscn -- "$@"
