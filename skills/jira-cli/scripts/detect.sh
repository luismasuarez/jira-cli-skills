#!/usr/bin/env bash
# detect.sh — report environment and current jira-cli setup state as JSON.
# Secrets are never printed; only a boolean "token_present" and its source.
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SELF_DIR/_lib.sh"

os="$(detect_os)"
arch="$(detect_arch)"
shell_name="$(detect_shell)"

docker_present=false
docker_version=""
if have docker; then
  docker_present=true
  docker_version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || true)"
fi

python_present=false
if have python3; then python_present=true; fi

config_path="$JIRA_CONFIG_DIR/.config.yml"
config_exists=false
if [ -f "$config_path" ]; then config_exists=true; fi

image_present=false
if [ "$docker_present" = true ]; then
  if docker image inspect "$JIRA_CLI_IMAGE" >/dev/null 2>&1; then image_present=true; fi
fi

local_bin_present=false
if [ -x "$JIRA_LOCAL_BIN" ]; then local_bin_present=true; fi

# shim_present: the executable Docker shim installed at $JIRA_LOCAL_BIN.
shim_present=false
if [ -f "$JIRA_LOCAL_BIN" ] && grep -qF 'jira-cli skill' "$JIRA_LOCAL_BIN" 2>/dev/null; then
  shim_present=true
fi

# jira_on_path: `jira` is reachable without sourcing any rc file (this is what
# an agent's non-interactive shell sees).
jira_on_path=false
if command -v jira >/dev/null 2>&1; then jira_on_path=true; fi

wrapper_present=false
case "$shell_name" in
  fish)
    if [ -f "$HOME/.config/fish/functions/jira.fish" ]; then wrapper_present=true; fi
    ;;
  bash)
    if grep -qF 'jira-cli skill' "$HOME/.bashrc" 2>/dev/null; then wrapper_present=true; fi
    ;;
  zsh)
    if grep -qF 'jira-cli skill' "$HOME/.zshrc" 2>/dev/null; then wrapper_present=true; fi
    ;;
esac

token_present=false
if has_secret; then token_present=true; fi

cat <<JSON
{
  "os": "$os",
  "arch": "$arch",
  "shell": "$shell_name",
  "shell_path": "${SHELL:-}",
  "docker": $docker_present,
  "docker_version": "$docker_version",
  "python3": $python_present,
  "image": "$JIRA_CLI_IMAGE",
  "image_present": $image_present,
  "local_binary_present": $local_bin_present,
  "config_dir": "$JIRA_CONFIG_DIR",
  "config_path": "$config_path",
  "config_exists": $config_exists,
  "token_present": $token_present,
  "token_source": "$(token_source)",
  "wrapper_present": $wrapper_present,
  "shim_present": $shim_present,
  "jira_on_path": $jira_on_path
}
JSON
