#!/bin/bash
# Docker entrypoint:
# 1. Populate UI cache from pre-built /ui-dist if available (so the "dev" binary
#    serves the full React SPA without a runtime download).
# 2. On first run (no config.yaml yet), initialise skillshare with --no-skill so
#    the container doesn't ship the built-in skillshare skill by default.
if [ -d /ui-dist ] && [ -n "$HOME" ]; then
  ver="${SKILLSHARE_VERSION:-dev}"
  cache_dir="$HOME/.cache/skillshare/ui/$ver"
  if [ ! -f "$cache_dir/index.html" ]; then
    mkdir -p "$cache_dir"
    cp -r /ui-dist/* "$cache_dir/"
  fi
fi

if [ -n "$HOME" ] && [ ! -f "$HOME/.config/skillshare/config.yaml" ]; then
  echo "First run: initialising skillshare config (--no-skill)..."
  skillshare init -g --no-copy --no-git --no-skill 2>/dev/null || true
fi

exec "$@"
