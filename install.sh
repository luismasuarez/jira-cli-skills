#!/usr/bin/env bash
# install.sh — help a developer register the jira-cli skill.
#
# By default it only prints what to do (safe, read-only). With --link it creates
# a symlink of skills/jira-cli inside the chosen agent's skills directory.
#
# Usage:
#   ./install.sh                 # print registration snippets
#   ./install.sh --link opencode # symlink into ~/.config/opencode/skills
#   ./install.sh --link claude   # symlink into ~/.claude/skills
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills_dir="$repo_root/skills"
skill="$skills_dir/jira-cli"

[ -f "$skill/SKILL.md" ] || { echo "No se encontró $skill/SKILL.md" >&2; exit 1; }

mode="print"
target="opencode"
while [ $# -gt 0 ]; do
  case "$1" in
    --link) mode="link"; shift; [ $# -gt 0 ] && target="$1" && shift || true ;;
    opencode|claude) target="$1"; mode="link"; shift ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
done

if [ "$mode" = "link" ]; then
  case "$target" in
    opencode) dest="$HOME/.config/opencode/skills" ;;
    claude)   dest="$HOME/.claude/skills" ;;
    *) echo "Destino inválido: $target (usa opencode o claude)" >&2; exit 1 ;;
  esac
  mkdir -p "$dest"
  ln -sfn "$skill" "$dest/jira-cli"
  echo "Enlazado: $dest/jira-cli -> $skill"
  echo "Reinicia el agente para que cargue la skill."
  exit 0
fi

cat <<EOF
Repo:        $repo_root
Skill:       $skill

Registra 'skills.paths' apuntando a la carpeta que contiene las skills:

opencode (~/.config/opencode/opencode.jsonc):
  {
    "skills": { "paths": ["$skills_dir"] }
  }

Claude Code:
  ln -s "$skill" ~/.claude/skills/jira-cli

Después, reinicia el agente. O ejecuta:
  $0 --link opencode
  $0 --link claude
EOF
