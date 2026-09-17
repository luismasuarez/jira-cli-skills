#!/usr/bin/env bash
# setup.sh — one-shot onboarding wizard for the jira-cli skill.
#
# Goal: a developer runs this once and ends up with a working `jira` command,
# a persisted config and reachable tasks. Values are resolved without nagging:
#
#   flags > env (JIRA_*) > defaults file > git user.email > interactive prompt
#
# The API token is NEVER handled by this script. It only checks whether a
# credential exists and, when missing, prints exactly what to do and waits.
#
# Usage: setup.sh [--guide] [--yes] [--force] [--no-alias]
#                 [--server URL] [--login EMAIL]
#                 [--installation cloud|local] [--auth-type basic|bearer|mtls]
#                 [--project KEY] [--board NAME] [--defaults FILE]
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$SELF_DIR/_lib.sh"

guide=0
yes=0
force=0
no_alias=0
server_flag=""
login_flag=""
installation_flag=""
auth_type_flag=""
project_flag=""
board_flag=""

usage() {
  cat <<'TXT'
setup.sh — configura JiraCLI de una sola pasada.

Uso:
  setup.sh [opciones]

Modos:
  (sin flags)   Interactivo si hay TTY; si no, modo agente (sin prompts).
  --guide       Solo imprime requisitos, links y comandos. No cambia nada.
  --yes, -y     Sin prompts (agente/CI). Si falta un dato, sale con código 2.

Datos (si no se pasan, se resuelven por env/defaults/git/prompt):
  --server URL        URL base, sin path. Ej: https://acme.atlassian.net
  --login EMAIL       Email de la cuenta Atlassian.
  --installation X    cloud | local            (default: cloud)
  --auth-type X       basic | bearer | mtls    (default: basic)
  --project KEY       Clave del proyecto por defecto.
  --board NAME        Nombre del board por defecto.

Opciones:
  --defaults FILE     Archivo de defaults (default: ~/.config/jira-cli-skills/defaults.env)
  --force             Regenera la config aunque ya exista.
  --no-alias          No crea el alias ~/.local/bin/jira-setup.
  -h, --help          Muestra esta ayuda.
TXT
}

while [ $# -gt 0 ]; do
  case "$1" in
    --guide)        guide=1; shift ;;
    --yes|-y)       yes=1; shift ;;
    --force)        force=1; shift ;;
    --no-alias)     no_alias=1; shift ;;
    --server)       server_flag="${2:-}"; shift 2 ;;
    --login)        login_flag="${2:-}"; shift 2 ;;
    --installation) installation_flag="${2:-}"; shift 2 ;;
    --auth-type)    auth_type_flag="${2:-}"; shift 2 ;;
    --project)      project_flag="${2:-}"; shift 2 ;;
    --board)        board_flag="${2:-}"; shift 2 ;;
    --defaults)     JIRA_DEFAULTS_FILE="${2:-}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "Opción desconocida: $1 (usa --help)" ;;
  esac
done
export JIRA_DEFAULTS_FILE
load_defaults

shell="$(detect_shell)"

print_token_help() {
  local link
  if [ "${installation:-cloud}" = "local" ]; then
    link="tu perfil de Jira (Profile -> Personal access tokens); si usas password, expórtalo igual"
  else
    link="https://id.atlassian.com/manage-profile/security/api-tokens"
  fi
  cat <<EOF >&2

  Falta la credencial. No me la pegues aquí; configúrala tú:

    1) Crea tu token:  $link
    2) Defínelo en tu shell:
         fish:  set -Ux JIRA_API_TOKEN "..."
         bash:  echo 'export JIRA_API_TOKEN="..."' >> ~/.bashrc && source ~/.bashrc
         zsh:   echo 'export JIRA_API_TOKEN="..."' >> ~/.zshrc && source ~/.zshrc
    3) Vuelve a ejecutar:  jira-setup

EOF
}

print_guide() {
  cat <<EOF
JiraCLI — guía rápida

Requisitos
  - Linux o macOS
  - Docker (recomendado) o curl (para el binario local)
  - Tu API token de Jira:
      Cloud:  https://id.atlassian.com/manage-profile/security/api-tokens
      Server: perfil de Jira -> Personal access tokens (JIRA_AUTH_TYPE=bearer)

Datos que usa el wizard (prioridad)
  flags > entorno (JIRA_*) > $JIRA_DEFAULTS_FILE > git user.email > pregunta

  Claves del archivo de defaults:
    JIRA_SERVER=https://acme.atlassian.net
    JIRA_LOGIN=tu@acme.com
    JIRA_INSTALLATION=cloud
    JIRA_AUTH_TYPE=basic
    JIRA_PROJECT=            # opcional
    JIRA_BOARD=              # opcional

Token (nunca se pide por chat)
    fish:  set -Ux JIRA_API_TOKEN "..."
    bash:  echo 'export JIRA_API_TOKEN="..."' >> ~/.bashrc && source ~/.bashrc
    zsh:   echo 'export JIRA_API_TOKEN="..."' >> ~/.zshrc && source ~/.zshrc

Qué hace el wizard
  1. Detecta entorno y qué falta
  2. Instala la imagen Docker pineada (o binario en ~/.local/bin)
  3. Instala la función jira, completions y la abreviatura jm
  4. Verifica el token (sin verlo)
  5. Resuelve URL/email/proyecto/board y los valida contra la API
  6. Genera ~/.config/.jira/.config.yml y verifica

Resultado
  jm                                     # tus tareas
  jira issue list -a\$(jira me)           # TUI interactiva
  jira sprint list --current -a\$(jira me)
  jira issue view PROJ-123
EOF
}

if [ "$guide" = 1 ]; then
  print_guide
  exit 0
fi

interactive=1
if [ "$yes" = 1 ] || [ ! -t 0 ] || [ ! -t 1 ]; then
  interactive=0
fi

ask() { # ask <prompt> [default]; echoes the answer
  local prompt="$1" def="${2:-}" ans=""
  if [ "$interactive" != 1 ]; then
    printf '%s' "$def"
    return 0
  fi
  if [ -n "$def" ]; then
    read -r -p "  $prompt [$def]: " ans || true
  else
    read -r -p "  $prompt: " ans || true
  fi
  [ -n "$ans" ] || ans="$def"
  printf '%s' "$ans"
}

need() { # need <message> -> agent-friendly failure
  echo >&2
  warn "$1"
  exit 2
}

# ---------------------------------------------------------------------------
# 1. Preflight
# ---------------------------------------------------------------------------
echo >&2
log "JiraCLI setup — $(detect_os)/$(detect_arch), shell: $shell"
log "-----------------------------------------------"

have_docker=0
if have docker; then have_docker=1; fi
config_file="$JIRA_CONFIG_DIR/.config.yml"
already_configured=0
if [ -f "$config_file" ]; then already_configured=1; fi

if [ "$have_docker" = 0 ] && [ ! -x "$JIRA_LOCAL_BIN" ]; then
  warn "No hay Docker; se usará el binario local (requiere curl)."
fi

token_ok=0
if has_secret; then token_ok=1; fi
info "Docker: $([ "$have_docker" = 1 ] && echo sí || echo no) · Config: $([ "$already_configured" = 1 ] && echo sí || echo no) · Token: $([ "$token_ok" = 1 ] && echo sí || echo no)"

# ---------------------------------------------------------------------------
# 2. Install executable
# ---------------------------------------------------------------------------
log "Instalando el ejecutable..."
bash "$SELF_DIR/install.sh" $([ "$have_docker" = 1 ] && echo --docker || echo --local)

# ---------------------------------------------------------------------------
# 3. Shell integration
# ---------------------------------------------------------------------------
log "Equipando el shell ($shell)..."
bash "$SELF_DIR/install_wrapper.sh" "$shell"
bash "$SELF_DIR/install_completions.sh" "$shell"

# ---------------------------------------------------------------------------
# 4. Token (instruct + wait, never handle the value)
# ---------------------------------------------------------------------------
if ! has_secret; then
  print_token_help
  if [ "$interactive" = 1 ]; then
    read -r -p "  Pulsa Enter cuando lo hayas definido en tu shell..." _ || true
  fi
  if ! has_secret; then
    echo >&2
    warn "Aún no veo JIRA_API_TOKEN en este entorno."
    info "Defínelo y ejecuta de nuevo 'jira-setup' para continuar el setup."
    exit 2
  fi
fi
ok "Credencial detectada (source: $(token_source))"

# ---------------------------------------------------------------------------
# 5. Config: skip when already present (idempotent)
# ---------------------------------------------------------------------------
if [ "$already_configured" = 1 ] && [ "$force" != 1 ]; then
  ok "Config ya presente, no se regenera: $config_file"
else
  # Resolve server / login / installation / auth_type
  server="$(resolve "$server_flag" JIRA_SERVER)"
  login="$(resolve "$login_flag" JIRA_LOGIN)"
  installation="$(resolve "$installation_flag" JIRA_INSTALLATION)"
  auth_type="$(resolve "$auth_type_flag" JIRA_AUTH_TYPE)"
  project="$(resolve "$project_flag" JIRA_PROJECT)"
  board="$(resolve "$board_flag" JIRA_BOARD)"
  [ -n "$installation" ] || installation="cloud"
  [ -n "$auth_type" ] || auth_type="basic"

  if [ -z "$login" ] && have git; then
    login="$(git config --global user.email 2>/dev/null || true)"
  fi

  if [ -z "$server" ]; then
    if [ "$interactive" = 1 ]; then
      server="$(ask "URL base de Jira (sin path, ej https://acme.atlassian.net)")"
    else
      need "Falta JIRA_SERVER. Pásalo con --server o en $JIRA_DEFAULTS_FILE."
    fi
  fi
  if [ -z "$login" ]; then
    if [ "$interactive" = 1 ]; then
      login="$(ask "Tu email de Atlassian")"
    else
      need "Falta JIRA_LOGIN. Pásalo con --login o en $JIRA_DEFAULTS_FILE."
    fi
  fi
  [ -n "$server" ] || need "Sin URL de Jira no puedo continuar."
  [ -n "$login" ] || need "Sin email de Atlassian no puedo continuar."

  case "$server" in
    http://*|https://*) : ;;
    *) need "URL inválida: '$server' (debe empezar por http:// o https://)" ;;
  esac
  case "$server" in
    */jira/*|*/projects/*|*/boards/*|*/browse/*)
      need "--server debe ser solo la URL base, sin path. Recibido: $server" ;;
  esac

  export JIRA_SERVER="$server" JIRA_LOGIN="$login" \
         JIRA_INSTALLATION="$installation" JIRA_AUTH_TYPE="$auth_type"

  # Discover projects when no project was provided
  if [ -z "$project" ]; then
    projects="$(bash "$SELF_DIR/discover.sh" projects 2>/dev/null || true)"
    [ -n "$projects" ] || need "No pude listar proyectos. Revisa URL, email y token."
    count="$(printf '%s\n' "$projects" | grep -c . || true)"
    if [ "$count" = 1 ]; then
      project="$(printf '%s\n' "$projects" | cut -f1 | head -1)"
      ok "Proyecto autodetectado: $project"
    elif [ "$interactive" = 1 ]; then
      echo >&2
      printf '%s\n' "$projects" | awk -F'\t' '{printf "    %2d) %s  %s\n", NR, $1, $2}' >&2
      read -r -p "  Elige proyecto [1]: " sel || true
      [ -n "$sel" ] || sel=1
      project="$(printf '%s\n' "$projects" | cut -f1 | sed -n "${sel}p")"
    else
      need "Modo no interactivo: pasa --project KEY (o JIRA_PROJECT)."
    fi
  fi
  [ -n "$project" ] || need "No pude determinar el proyecto."

  # Discover boards when no board was provided
  if [ -z "$board" ]; then
    boards="$(bash "$SELF_DIR/discover.sh" boards "$project" 2>/dev/null || true)"
    [ -n "$boards" ] || need "No pude listar boards para $project. Pasa --board NAME."
    bcount="$(printf '%s\n' "$boards" | grep -c . || true)"
    if [ "$bcount" = 1 ]; then
      board="$(printf '%s\n' "$boards" | cut -f2 | head -1)"
      ok "Board autodetectado: $board"
    elif [ "$interactive" = 1 ]; then
      echo >&2
      printf '%s\n' "$boards" | awk -F'\t' '{printf "    %2d) %s  %s\n", NR, $2, $1}' >&2
      read -r -p "  Elige board [1]: " bsel || true
      [ -n "$bsel" ] || bsel=1
      board="$(printf '%s\n' "$boards" | cut -f2 | sed -n "${bsel}p")"
    else
      need "Modo no interactivo: pasa --board NAME (o JIRA_BOARD)."
    fi
  fi
  [ -n "$board" ] || need "No pude determinar el board."

  # Configure
  log "Generando config..."
  conf_args=(--server "$server" --login "$login" --installation "$installation" --auth-type "$auth_type" --project "$project" --board "$board")
  if [ "$force" = 1 ]; then conf_args+=(--force); fi
  bash "$SELF_DIR/configure.sh" "${conf_args[@]}"
fi

# ---------------------------------------------------------------------------
# 6. Alias + verify
# ---------------------------------------------------------------------------
if [ "$no_alias" != 1 ]; then
  bin="$HOME/.local/bin"
  if mkdir -p "$bin" 2>/dev/null; then
    ln -sfn "$SELF_DIR/setup.sh" "$bin/jira-setup"
    ok "Alias disponible: $bin/jira-setup"
  fi
fi

log "Verificando..."
if ! bash "$SELF_DIR/verify.sh"; then
  die "La verificación falló. Revisa los mensajes y references/troubleshooting.md."
fi

cat >&2 <<'EOF'

  Listo. Abre una shell nueva (o recarga tu rc) y prueba:

    jm                                       # tus tareas
    jira issue list -a$(jira me)             # TUI interactiva
    jira sprint list --current -a$(jira me)  # sprint actual
    jira issue view PROJ-123                 # detalle

EOF
