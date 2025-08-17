#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  --precheck)
    for c in bash awk sed printf; do
      command -v "$c" >/dev/null || { echo "Missing $c"; exit 1; }
    done
    ;;
esac
