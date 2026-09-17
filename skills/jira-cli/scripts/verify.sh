#!/usr/bin/env bash
# verify.sh — assert that jira-cli is fully configured and tasks are reachable.
#
# Prints a PASS/FAIL line per check and exits non-zero if any check fails.
# Never prints the API token.
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SELF_DIR/_lib.sh"

fails=0
check() { # check <label> <command...>
  local label="$1"; shift
  if out="$("$@" 2>/dev/null)"; then
    if [ -n "$out" ]; then
      ok "$label"
    else
      warn "$label (sin resultados)"; fails=$((fails+1))
    fi
  else
    warn "$label (falló)"; fails=$((fails+1))
  fi
}

# 1. Executable reachable
check "jira version" jira_cmd version

# 2. Config on disk
config="$JIRA_CONFIG_DIR/.config.yml"
if [ -f "$config" ]; then
  ok "config presente: $config"
  if [ "$(stat -c '%u' "$config" 2>/dev/null || stat -f '%u' "$config")" = "$(id -u)" ]; then
    ok "config propiedad del usuario"
  else
    warn "config no es propiedad del usuario (¿root?)"; fails=$((fails+1))
  fi
else
  warn "config ausente: $config"; fails=$((fails+1))
fi

# 3. Credential present (boolean only)
if has_secret; then
  ok "credencial presente (source: $(token_source))"
else
  warn "sin credencial (define JIRA_API_TOKEN o ~/.netrc)"; fails=$((fails+1))
fi

# 4. Identity
me=""
if me="$(jira_cmd me 2>/dev/null)" && [ -n "$me" ]; then
  ok "jira me -> $me"
else
  warn "jira me no devolvió identidad"; fails=$((fails+1))
fi

# 5. Projects visible
check "jira project list" jira_cmd project list

# 6. Assigned tasks reachable
if [ -n "$me" ]; then
  count="$(jira_cmd issue list -a"$me" --plain --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  if [ -n "$count" ]; then
    ok "mis tareas accesibles ($count issues asignadas)"
  else
    warn "no se pudo listar tareas asignadas"; fails=$((fails+1))
  fi
fi

echo
if [ "$fails" = 0 ]; then
  ok "VERIFY: todo en orden"
  exit 0
fi
die "VERIFY: $fails comprobación(es) fallaron"
