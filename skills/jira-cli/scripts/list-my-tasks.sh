#!/usr/bin/env bash
# list-my-tasks.sh — convenience wrapper: list issues assigned to the current user.
#
# Any extra arguments are forwarded to `jira issue list` (e.g. --csv, -s"En curso").
# Defaults to the plain table so the output is pipe-friendly.
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SELF_DIR/_lib.sh"

me="$(jira_cmd me 2>/dev/null || true)"
if [ -z "$me" ]; then die "No se pudo determinar tu usuario (jira me). ¿Config y token listos?"; fi

jira_cmd issue list -a"$me" --plain "$@"
