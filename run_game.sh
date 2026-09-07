#!/usr/bin/env bash
# Abre o jogo. Uso: ./run_game.sh
cd "$(dirname "$0")"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
exec "$GODOT" --path . "$@"
