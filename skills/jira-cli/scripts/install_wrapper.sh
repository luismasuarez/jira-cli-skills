#!/usr/bin/env bash
# install_wrapper.sh — install the interactive `jira` shell function.
#
# The function lets `jira ...` behave like a native command: it runs the pinned
# Docker image (or the local binary as fallback), persists config on the host,
# forwards the API token from the environment, and only allocates a TTY when
# one is actually attached (so `jira ... --plain | grep` works in pipelines).
#
# Usage: install_wrapper.sh [fish|bash|zsh]   (defaults to $SHELL)
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SELF_DIR/_lib.sh"

shell="${1:-$(detect_shell)}"
assets="$(skill_root)/assets"
begin='# >>> jira-cli skill >>>'
end='# <<< jira-cli skill <<<'

case "$shell" in
  fish)
    src="$assets/jira.fish"
    dest="$HOME/.config/fish/functions/jira.fish"
    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ] && ! grep -qF 'jira-cli skill' "$dest"; then
      cp "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
      warn "jira.fish existente respaldado antes de sobrescribir"
    fi
    tmp="$(mktemp "${TMPDIR:-/tmp}/jira-wrapper.XXXXXX")"
    render_template "$src" >"$tmp"
    if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
      rm -f "$tmp"
      ok "Wrapper fish sin cambios: $dest"
    else
      mv "$tmp" "$dest"
      ok "Wrapper fish instalado: $dest"
    fi

    # conf.d is auto-sourced by fish at startup, so the abbreviation is ready
    # before the first `jira` call (a function file is only autoloaded on use).
    conf="$HOME/.config/fish/conf.d/jira-cli.fish"
    mkdir -p "$(dirname "$conf")"
    ctmp="$(mktemp "${TMPDIR:-/tmp}/jira-conf.XXXXXX")"
    cat >"$ctmp" <<'CONF'
# >>> jira-cli skill >>>
abbr --add jm 'jira issue list -a(jira me)'
# <<< jira-cli skill <<<
CONF
    if [ -f "$conf" ] && cmp -s "$ctmp" "$conf"; then
      rm -f "$ctmp"
      ok "abreviatura jm sin cambios: $conf"
    else
      mv "$ctmp" "$conf"
      ok "abreviatura jm instalada: $conf"
    fi
    ;;
  bash)
    dest="$HOME/.bashrc"
    block="$(render_template "$assets/jira.bash")"
    if replace_block "$dest" "$begin" "$end" "$block"; then
      ok "Wrapper bash actualizado en $dest"
    else
      ok "Wrapper bash sin cambios en $dest"
    fi
    ;;
  zsh)
    dest="$HOME/.zshrc"
    block="$(render_template "$assets/jira.zsh")"
    if replace_block "$dest" "$begin" "$end" "$block"; then
      ok "Wrapper zsh actualizado en $dest"
    else
      ok "Wrapper zsh sin cambios en $dest"
    fi
    ;;
  *)
    die "Shell no soportado: '$shell'. Usa fish, bash o zsh."
    ;;
esac
