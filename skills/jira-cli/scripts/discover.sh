#!/usr/bin/env bash
# discover.sh — query Jira for identity, projects and boards.
#
# Requires: JIRA_SERVER (base URL, no path) and JIRA_LOGIN (email).
# Credential: JIRA_API_TOKEN (basic by default; bearer when JIRA_AUTH_TYPE=bearer)
# or an entry in ~/.netrc. The token is never printed.
#
# Usage:
#   discover.sh myself
#   discover.sh projects
#   discover.sh boards [PROJECT_KEY]
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SELF_DIR/_lib.sh"

: "${JIRA_SERVER:?Falta JIRA_SERVER (p.ej. https://acme.atlassian.net)}"
: "${JIRA_LOGIN:?Falta JIRA_LOGIN (tu email de Atlassian)}"

case "$JIRA_SERVER" in
  */jira/*|*/projects/*|*/boards/*|*/browse/*)
    die "JIRA_SERVER debe ser solo la URL base (https://acme.atlassian.net), sin path. Recibido: $JIRA_SERVER" ;;
esac

CURL_AUTH=()
if [ -n "${JIRA_API_TOKEN:-}" ]; then
  if [ "${JIRA_AUTH_TYPE:-basic}" = "bearer" ]; then
    CURL_AUTH=(-H "Authorization: Bearer ${JIRA_API_TOKEN}")
  else
    CURL_AUTH=(-u "${JIRA_LOGIN}:${JIRA_API_TOKEN}")
  fi
elif [ -f "$HOME/.netrc" ]; then
  CURL_AUTH=(--netrc)
else
  die "No hay credencial: define JIRA_API_TOKEN o crea ~/.netrc."
fi

api() { # api <path> -> body; non-zero on HTTP != 200
  local path="$1" url tmp code
  url="${JIRA_SERVER%/}${path}"
  tmp="$(mktemp "${TMPDIR:-/tmp}/jira-api.XXXXXX")"
  code="$(curl -sS -o "$tmp" -w '%{http_code}' "${CURL_AUTH[@]}" "$url" || true)"
  if [ "$code" != "200" ]; then
    warn "HTTP $code en $url"
    rm -f "$tmp"
    return 1
  fi
  cat "$tmp"
  rm -f "$tmp"
}

api_try() { # try several paths, first success wins
  local p out
  for p in "$@"; do
    if out="$(api "$p")"; then printf '%s' "$out"; return 0; fi
  done
  return 1
}

parse() { # parse <python-expression>  (reads JSON from stdin)
  if have python3; then
    python3 -c "$1"
  else
    die "python3 es necesario para interpretar las respuestas. Instálalo o revisa el JSON manualmente."
  fi
}

cmd="${1:-myself}"
case "$cmd" in
  myself)
    body="$(api_try /rest/api/3/myself /rest/api/2/myself)"
    printf '%s' "$body" | parse 'import sys,json; d=json.load(sys.stdin); print(d.get("displayName","?"), "<"+d.get("emailAddress", d.get("name","?"))+">")'
    ;;
  projects)
    body="$(api_try "/rest/api/3/project/search?maxResults=100" /rest/api/2/project)"
    printf '%s' "$body" | parse '
import sys,json
d=json.load(sys.stdin)
vals=d.get("values", d) if isinstance(d,dict) else d
for p in vals: print(p.get("key","?"), "\t", p.get("name","?"))
'
    ;;
  boards)
    project="${2:-}"
    qs="maxResults=50"
    if [ -n "$project" ]; then qs="$qs&projectKeyOrId=$project"; fi
    body="$(api "/rest/agile/1.0/board?$qs")"
    printf '%s' "$body" | parse '
import sys,json
d=json.load(sys.stdin)
for b in d.get("values",[]):
    loc=b.get("location",{}) or {}
    print(b.get("id","?"), "\t", b.get("name","?"), "\t", b.get("type","?"), "\t", loc.get("projectKey",""))
'
    ;;
  *)
    die "Subcomando desconocido: $cmd (usa myself|projects|boards)"
    ;;
esac
