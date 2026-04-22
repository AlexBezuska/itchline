#!/usr/bin/env bash
set -euo pipefail

program_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$program_dir/.." && pwd)"

config_file=""
check_only=false

resolve_path() {
  local candidate="$1"
  local base_dir="$2"

  if [[ "$candidate" = /* ]]; then
    printf '%s\n' "$candidate"
    return
  fi

  if [[ -n "$base_dir" ]]; then
    printf '%s/%s\n' "$base_dir" "$candidate"
    return
  fi

  printf '%s/%s\n' "$PWD" "$candidate"
}

find_default_config() {
  local candidates=(
    "$PWD/itchline.config.env"
    "$PWD/itchline.config.local.env"
    "$repo_root/itchline.config.env"
    "$repo_root/itchline.config.local.env"
    "$program_dir/itchline.config.local.env"
    "$program_dir/itchline.config.env"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  printf '%s\n' "$repo_root/itchline.config.env"
}

find_butler_bin() {
  if [[ -n "${BUTLER_BIN:-}" ]]; then
    if [[ -x "$BUTLER_BIN" ]]; then
      printf '%s\n' "$BUTLER_BIN"
      return
    fi
    echo "Configured BUTLER_BIN is not executable: $BUTLER_BIN" >&2
    exit 1
  fi

  if command -v butler >/dev/null 2>&1; then
    command -v butler
    return
  fi

  local itch_dir="$HOME/Library/Application Support/itch/broth/butler/versions"
  if [[ -d "$itch_dir" ]]; then
    # Pick the highest semantic-like version folder if present.
    local candidate
    candidate="$(find "$itch_dir" -mindepth 2 -maxdepth 2 -type f -name butler | sort -V | tail -n 1)"
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  fi

  echo "Could not find butler. Install itch app/butler or set BUTLER_BIN in config." >&2
  exit 1
}

pre_scan_args() {
  local index=1
  while [[ $index -le $# ]]; do
    local arg="${!index}"
    case "$arg" in
      --config|--env-file)
        local next=$((index + 1))
        config_file="${!next}"
        index=$((index + 2))
        ;;
      *)
        index=$((index + 1))
        ;;
    esac
  done
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --config FILE           Path to itch config file (default: itchline.config.env)
  --butler-bin PATH       Path to butler executable
  --target USER/GAME      itch target slug (example: fufroom/fashion-fupa)
  --linux-path DIR        Linux build folder
  --windows-path DIR      Windows build folder
  --mac-path DIR          macOS build folder or .app
  --channel-linux NAME    Linux channel (default: linux)
  --channel-windows NAME  Windows channel (default: windows)
  --channel-mac NAME      macOS channel (default: macos)
  --userversion VERSION   Version label for this push
  --check                 Validate config/files without uploading
  -h, --help              Show this help

Config variables (in itchline.config.env):
  BUTLER_BIN
  ITCH_TARGET
  ITCH_BUILD_PATH_LINUX
  ITCH_BUILD_PATH_WINDOWS
  ITCH_BUILD_PATH_MAC
  ITCH_CHANNEL_LINUX
  ITCH_CHANNEL_WINDOWS
  ITCH_CHANNEL_MAC
  ITCH_USER_VERSION
  BUTLER_API_KEY

If BUTLER_API_KEY is unset, butler will use your existing local auth/session.
EOF
}

pre_scan_args "$@"

if [[ -z "$config_file" ]]; then
  config_file="$(find_default_config)"
elif [[ "$config_file" != /* ]]; then
  config_file="$(resolve_path "$config_file" "$PWD")"
fi

if [[ ! -f "$config_file" ]]; then
  echo "Config file not found: $config_file" >&2
  echo "Create one at itchline.config.env." >&2
  echo "A starter template is in itchline/examples/itchline.config.env.example." >&2
  exit 1
fi

config_dir="$(cd "$(dirname "$config_file")" && pwd)"

set -a
# shellcheck disable=SC1090
source "$config_file"
set +a

itch_target="${ITCH_TARGET:-}"
build_path_linux="${ITCH_BUILD_PATH_LINUX:-./build/Linux}"
build_path_windows="${ITCH_BUILD_PATH_WINDOWS:-./build/Windows}"
build_path_mac="${ITCH_BUILD_PATH_MAC:-./build/Mac/Fashion FUPA.app}"
channel_linux="${ITCH_CHANNEL_LINUX:-linux}"
channel_windows="${ITCH_CHANNEL_WINDOWS:-windows}"
channel_mac="${ITCH_CHANNEL_MAC:-macos}"
user_version="${ITCH_USER_VERSION:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config|--env-file)
      shift 2
      ;;
    --butler-bin)
      BUTLER_BIN="$2"
      shift 2
      ;;
    --target)
      itch_target="$2"
      shift 2
      ;;
    --linux-path)
      build_path_linux="$2"
      shift 2
      ;;
    --windows-path)
      build_path_windows="$2"
      shift 2
      ;;
    --mac-path)
      build_path_mac="$2"
      shift 2
      ;;
    --channel-linux)
      channel_linux="$2"
      shift 2
      ;;
    --channel-windows)
      channel_windows="$2"
      shift 2
      ;;
    --channel-mac)
      channel_mac="$2"
      shift 2
      ;;
    --userversion)
      user_version="$2"
      shift 2
      ;;
    --check)
      check_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$itch_target" ]]; then
  echo "ITCH_TARGET is required (example: fufroom/fashion-fupa)." >&2
  exit 1
fi

if [[ ! "$itch_target" =~ ^[^/]+/[^/]+$ ]]; then
  echo "ITCH_TARGET must be in USER/GAME format. Got: $itch_target" >&2
  exit 1
fi

linux_abs="$(resolve_path "$build_path_linux" "$config_dir")"
windows_abs="$(resolve_path "$build_path_windows" "$config_dir")"
mac_abs="$(resolve_path "$build_path_mac" "$config_dir")"

[[ -d "$linux_abs" ]] || { echo "Linux build path not found: $linux_abs" >&2; exit 1; }
[[ -d "$windows_abs" ]] || { echo "Windows build path not found: $windows_abs" >&2; exit 1; }
[[ -d "$mac_abs" ]] || { echo "macOS build path not found: $mac_abs" >&2; exit 1; }

if [[ -z "$user_version" ]]; then
  project_file="$repo_root/godot-project/project.godot"
  if [[ -f "$project_file" ]]; then
    project_version="$(awk -F'"' '/^config\/version="/ {print $2; exit}' "$project_file")"
  else
    project_version=""
  fi

  if [[ -z "$project_version" ]]; then
    project_version="dev"
  fi

  user_version="$project_version-$(date +%Y%m%d-%H%M%S)"
fi

butler_bin="$(find_butler_bin)"

echo "Itchline preflight checks passed."
echo "- Config: $config_file"
echo "- Butler: $butler_bin"
echo "- Target: $itch_target"
echo "- Linux path: $linux_abs"
echo "- Windows path: $windows_abs"
echo "- Mac path: $mac_abs"
echo "- Channels: $channel_linux, $channel_windows, $channel_mac"
echo "- User version: $user_version"

if [[ "$check_only" == true ]]; then
  echo "Check complete (--check): no uploads performed."
  exit 0
fi

if [[ -n "${BUTLER_API_KEY:-}" ]]; then
  export BUTLER_API_KEY
fi

echo "Uploading Linux build..."
"$butler_bin" push "$linux_abs" "$itch_target:$channel_linux" --userversion "$user_version"

echo "Uploading Windows build..."
"$butler_bin" push "$windows_abs" "$itch_target:$channel_windows" --userversion "$user_version"

echo "Uploading macOS build..."
"$butler_bin" push "$mac_abs" "$itch_target:$channel_mac" --userversion "$user_version"

echo "Itch upload complete."
