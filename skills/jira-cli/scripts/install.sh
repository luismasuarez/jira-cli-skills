#!/usr/bin/env bash
# install.sh — make the jira-cli executable available, idempotently.
#
# Preferred: the pinned Docker image (pin in _lib.sh). Fallback: a release
# binary in ~/.local/bin. Re-running is safe and cheap.
#
# Usage: install.sh [--docker|--local]
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SELF_DIR/_lib.sh"

mode="auto"
case "${1:-}" in
  --docker) mode="docker" ;;
  --local)  mode="local" ;;
  "")       mode="auto" ;;
  *)        die "Opción desconocida: $1 (usa --docker o --local)" ;;
esac

if [ "$mode" = "auto" ]; then
  if have docker; then mode="docker"; else mode="local"; fi
fi

if [ "$mode" = "docker" ]; then
  if ! have docker; then die "Docker no está instalado. Usa --local o instala Docker."; fi
  if docker image inspect "$JIRA_CLI_IMAGE" >/dev/null 2>&1; then
    ok "Imagen ya presente: $JIRA_CLI_IMAGE"
  else
    info "Descargando $JIRA_CLI_IMAGE ..."
    docker pull "$JIRA_CLI_IMAGE" >&2
    ok "Imagen descargada: $JIRA_CLI_IMAGE"
  fi
  exit 0
fi

# ---- Local binary fallback -------------------------------------------------
os="$(detect_os)"
arch="$(detect_arch)"
if [ "$os" = "unknown" ] || [ "$arch" = "unknown" ]; then
  die "Plataforma no soportada: os=$os arch=$arch"
fi

case "$os" in
  linux) os_label="linux" ;;
  macos) os_label="macOS" ;;
esac

ver="${JIRA_CLI_IMAGE_TAG#v}"
asset="jira_${ver}_${os_label}_${arch}.tar.gz"
base="https://github.com/ankitpokhrel/jira-cli/releases/download/${JIRA_CLI_IMAGE_TAG}"

if [ -x "$JIRA_LOCAL_BIN" ]; then
  current="$("$JIRA_LOCAL_BIN" version 2>/dev/null || true)"
  if printf '%s' "$current" | grep -q "Version=\"${JIRA_CLI_IMAGE_TAG}\""; then
    ok "Binario local ya presente y en ${JIRA_CLI_IMAGE_TAG}: $JIRA_LOCAL_BIN"
    exit 0
  fi
fi

if ! have curl; then die "curl es necesario para descargar el binario."; fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/jira-cli.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

info "Descargando $asset ..."
curl -fsSL "$base/$asset" -o "$tmp/$asset"

if curl -fsSL "$base/checksums.txt" -o "$tmp/checksums.txt" 2>/dev/null; then
  expected="$(grep -E "[[:space:]]${asset}$" "$tmp/checksums.txt" | awk '{print $1}' | head -1)"
  if [ -n "$expected" ]; then
    if have sha256sum; then actual="$(sha256sum "$tmp/$asset" | awk '{print $1}')"
    elif have shasum; then actual="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"
    else actual=""; fi
    if [ -n "$actual" ] && [ "$actual" != "$expected" ]; then
      die "Checksum inválido para $asset (esperado $expected, obtenido $actual)."
    fi
    ok "Checksum verificado"
  else
    warn "No se encontró $asset en checksums.txt; se omite la verificación"
  fi
else
  warn "No se pudo descargar checksums.txt; se omite la verificación"
fi

tar -xzf "$tmp/$asset" -C "$tmp"
bin="$(find "$tmp" -type f -name jira -perm -u+x | head -1)"
if [ -z "$bin" ]; then bin="$(find "$tmp" -type f -name jira | head -1)"; fi
if [ -z "$bin" ]; then die "No se encontró el binario jira dentro de $asset."; fi

mkdir -p "$(dirname "$JIRA_LOCAL_BIN")"
install -m 0755 "$bin" "$JIRA_LOCAL_BIN" 2>/dev/null || { cp "$bin" "$JIRA_LOCAL_BIN"; chmod 0755 "$JIRA_LOCAL_BIN"; }
ok "Instalado: $JIRA_LOCAL_BIN"
"$JIRA_LOCAL_BIN" version >&2 || true
