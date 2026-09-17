#!/usr/bin/env bash
# Shared helpers for the jira-cli skill scripts.
# Sourced by the other scripts; never executed directly.
#
# It never prints the API token. Scripts must treat JIRA_API_TOKEN as opaque:
# check for its presence, pass it through, but never echo it.

set -euo pipefail

JIRA_CLI_IMAGE_TAG="${JIRA_CLI_IMAGE_TAG:-v1.7.0}"
JIRA_CLI_IMAGE="${JIRA_CLI_IMAGE:-ghcr.io/ankitpokhrel/jira-cli:${JIRA_CLI_IMAGE_TAG}}"
JIRA_CONFIG_DIR="${JIRA_CONFIG_DIR:-$HOME/.config/.jira}"
JIRA_LOCAL_BIN="${JIRA_LOCAL_BIN:-$HOME/.local/bin/jira}"

# skill_root prints the skill folder (parent of this script's scripts/ dir).
skill_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "$(dirname "$here")"
}

log()  { printf '%s\n' "$*" >&2; }
info() { printf '  ..  %s\n' "$*" >&2; }
ok()   { printf '  ok  %s\n' "$*" >&2; }
warn() { printf '  !!  %s\n' "$*" >&2; }
die()  { printf '  xx  %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# has_secret returns 0 when a credential is available, without revealing it.
has_secret() {
  if [ -n "${JIRA_API_TOKEN:-}" ]; then return 0; fi
  if [ -f "$HOME/.netrc" ] && grep -qE '^[[:space:]]*machine[[:space:]]' "$HOME/.netrc" 2>/dev/null; then
    return 0
  fi
  return 1
}

token_source() {
  if [ -n "${JIRA_API_TOKEN:-}" ]; then
    printf 'env\n'
  elif [ -f "$HOME/.netrc" ] && grep -qE '^[[:space:]]*machine[[:space:]]' "$HOME/.netrc" 2>/dev/null; then
    printf 'netrc\n'
  else
    printf 'none\n'
  fi
}

# jira_cmd runs jira-cli non-interactively. It prefers the pinned Docker image
# (no host install needed) and falls back to a locally installed binary.
jira_cmd() {
  if have docker; then
    docker run --rm \
      --user "$(id -u):$(id -g)" \
      -e HOME=/home/jira \
      -e "JIRA_API_TOKEN=${JIRA_API_TOKEN:-}" \
      -v "$JIRA_CONFIG_DIR:/home/jira/.config/.jira" \
      --entrypoint jira "$JIRA_CLI_IMAGE" "$@"
  elif [ -x "$JIRA_LOCAL_BIN" ]; then
    "$JIRA_LOCAL_BIN" "$@"
  else
    die "Faltan Docker y el binario local ($JIRA_LOCAL_BIN). Ejecuta scripts/install.sh primero."
  fi
}

detect_os() {
  case "$(uname -s)" in
    Darwin) printf 'macos\n' ;;
    Linux)  printf 'linux\n' ;;
    *)      printf 'unknown\n' ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)   printf 'x86_64\n' ;;
    arm64|aarch64)  printf 'arm64\n' ;;
    *)              uname -m ;;
  esac
}

detect_shell() {
  local s=""
  if [ -n "${SHELL:-}" ]; then s="$(basename "$SHELL")"; fi
  case "$s" in
    fish|bash|zsh) printf '%s\n' "$s" ;;
    *) printf 'unknown\n' ;;
  esac
}

# replace_block rewrites the region between two marker lines inside a file,
# appending the block when the markers are not present. It is idempotent:
# the file is only replaced when its bytes actually change.
render_template() {
  local template="$1"
  sed "s|__JIRA_CLI_IMAGE__|$JIRA_CLI_IMAGE|g" "$template"
}

replace_block() {
  local file="$1" begin="$2" end="$3" block="$4"
  local out in_block=0 found=0 line
  out="$(mktemp "${TMPDIR:-/tmp}/jira-cli-block.XXXXXX")"
  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$line" = "$begin" ]; then
        printf '%s\n' "$block" >>"$out"
        in_block=1
        found=1
        continue
      fi
      if [ "$line" = "$end" ]; then
        in_block=0
        continue
      fi
      if [ "$in_block" = 0 ]; then
        printf '%s\n' "$line" >>"$out"
      fi
    done <"$file"
  fi
  if [ "$found" = 0 ]; then
    printf '\n%s\n' "$block" >>"$out"
  fi
  if [ -f "$file" ] && cmp -s "$out" "$file"; then
    rm -f "$out"
    return 1
  fi
  mv "$out" "$file"
  return 0
}
