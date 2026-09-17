#!/usr/bin/env bash
# configure.sh — generate ~/.config/.jira/.config.yml non-interactively.
#
# Reads values from flags or environment, so an agent can run it without a TTY.
# Idempotent: if a config already exists it is left untouched unless --force.
#
# Usage:
#   configure.sh --server URL --login EMAIL [--installation cloud|local]
#                [--auth-type basic|bearer|mtls] [--project KEY] [--board NAME]
#                [--force]
#
# Env equivalents: JIRA_SERVER JIRA_LOGIN JIRA_INSTALLATION JIRA_AUTH_TYPE
#                  JIRA_PROJECT JIRA_BOARD
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SELF_DIR/_lib.sh"

server="${JIRA_SERVER:-}"
login="${JIRA_LOGIN:-}"
installation="${JIRA_INSTALLATION:-cloud}"
auth_type="${JIRA_AUTH_TYPE:-basic}"
project="${JIRA_PROJECT:-}"
board="${JIRA_BOARD:-}"
force=0

while [ $# -gt 0 ]; do
  case "$1" in
    --server)       server="$2"; shift 2 ;;
    --login)        login="$2"; shift 2 ;;
    --installation) installation="$2"; shift 2 ;;
    --auth-type)    auth_type="$2"; shift 2 ;;
    --project)      project="$2"; shift 2 ;;
    --board)        board="$2"; shift 2 ;;
    --force)        force=1; shift ;;
    *)              die "Opción desconocida: $1" ;;
  esac
done

[ -n "$server" ] || die "Falta --server (URL base, sin path)."
[ -n "$login" ]  || die "Falta --login (email)."

case "$server" in
  */jira/*|*/projects/*|*/boards/*|*/browse/*)
    die "--server debe ser solo la URL base (https://acme.atlassian.net), sin path." ;;
esac

config="$JIRA_CONFIG_DIR/.config.yml"
if [ -f "$config" ] && [ "$force" != 1 ]; then
  ok "Config ya existe, no se toca: $config (usa --force para regenerar)"
  exit 0
fi

if ! has_secret; then
  die "No hay credencial. Define JIRA_API_TOKEN (recomendado) o crea ~/.netrc antes de continuar."
fi

mkdir -p "$JIRA_CONFIG_DIR"

args=(init --installation "$installation" --server "$server" --login "$login" --auth-type "$auth_type")
if [ -n "$project" ]; then args+=(--project "$project"); fi
if [ -n "$board" ]; then args+=(--board "$board"); fi
if [ "$force" = 1 ]; then args+=(--force); fi

info "Ejecutando: jira ${args[*]}"
jira_cmd "${args[@]}" >&2

if [ -f "$config" ]; then
  ok "Config generada: $config"
else
  die "No se generó $config. Revisa los mensajes anteriores."
fi
