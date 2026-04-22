#!/usr/bin/env bash
set -euo pipefail

program_dir="$(cd "$(dirname "$0")" && pwd)"
exec "$program_dir/itchline.sh" "$@"
