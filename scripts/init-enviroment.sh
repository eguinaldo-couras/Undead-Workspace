#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
REPS_DIR="$WORKSPACE_DIR/reps"
LOG_FILE="$WORKSPACE_DIR/logs/bootstrap.log"

mkdir -p "$WORKSPACE_DIR/logs"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "  [OK]  $*"; }
skip() { log " [SKIP] $*"; }
err()  { log " [ERR]  $*" >&2; }

# ---------------------------------------------------------------------------
# Lista de repositorios (SSH)
# Formato: "nome_da_pasta|git@github.com:org/repo.git"
# ---------------------------------------------------------------------------
REPOS=(
  "Undead-Admin-Portal-API|git@github.com:eguinaldo-couras/Undead-Admin-API.git"
  "Undead-Admin-UI|git@github.com:eguinaldo-couras/Undead-Admin-UI.git"
  "Undead-AI|git@github.com:eguinaldo-couras/Undead-AI.git"
  "Undead-API|git@github.com:eguinaldo-couras/Undead-API.git"
  "Undead-Migrations|git@github.com:eguinaldo-couras/Undead-Migrations.git"
)

# ---------------------------------------------------------------------------
# Dependencias de sistema (apt)
# ---------------------------------------------------------------------------
APT_PACKAGES=(
  # --- ferramentas gerais ---
  git
  curl
  wget
  file
  build-essential
  # --- Python ---
  python3
  python3-pip
  python3-venv
  # --- Docker ---
  docker.io
  docker-compose
  # --- Banco / cache ---
  postgresql-client
  redis-tools
  # --- Tauri (v2) ---
  libwebkit2gtk-4.1-dev
  libssl-dev
  libxdo-dev
  libayatana-appindicator3-dev
  librsvg2-dev
)

install_system_deps() {
  log "==============================="
  log " Instalando dependencias de sistema (apt)"
  log "==============================="

  if ! command -v apt-get &>/dev/null; then
    skip "apt-get nao encontrado — ignorando instalacao de sistema"
    return 0
  fi

  log "Atualizando lista de pacotes ..."
  sudo apt-get update -y >> "$LOG_FILE" 2>&1

  local failed=0
  for pkg in "${APT_PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
      skip "$pkg — ja instalado"
    else
      log "Instalando $pkg ..."
      if sudo apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
        ok "$pkg instalado"
      else
        err "$pkg falhou ao instalar"
        failed=$(( failed + 1 ))
      fi
    fi
  done

  if (( failed > 0 )); then
    err "$failed pacote(s) falharam. Verifique $LOG_FILE"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Rust (via rustup)
# ---------------------------------------------------------------------------
install_rust() {
  log "==============================="
  log " Instalando Rust (rustup)"
  log "==============================="

  if command -v rustc &>/dev/null; then
    skip "Rust ja instalado: $(rustc --version)"
    return 0
  fi

  log "Baixando e executando rustup-init ..."
  if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path >> "$LOG_FILE" 2>&1; then
    # Disponibiliza cargo/rustc na sessao atual
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
    ok "Rust instalado: $(rustc --version)"
  else
    err "Falha ao instalar Rust via rustup"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Gerar secrets (.env)
# ---------------------------------------------------------------------------
generate_secrets() {
  log "==============================="
  log " Gerando secrets (.env)"
  log "==============================="

  local script="$SCRIPT_DIR/generate_secrets.py"

  if [[ ! -f "$script" ]]; then
    err "generate_secrets.py nao encontrado em $script"
    return 1
  fi

  if ! command -v python3 &>/dev/null; then
    err "python3 nao encontrado — instale as dependencias de sistema primeiro"
    return 1
  fi

  local env_file="$WORKSPACE_DIR/config/secrets/.env"
  if [[ -f "$env_file" ]]; then
    skip ".env ja existe em $env_file (use --force para regenerar)"
    return 0
  fi

  log "Executando generate_secrets.py ..."
  if python3 "$script" >> "$LOG_FILE" 2>&1; then
    ok ".env gerado em $env_file"
  else
    err "Falha ao gerar secrets. Verifique $LOG_FILE"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Clone repositories
# ---------------------------------------------------------------------------
clone_repos() {
  log "==============================="
  log " Cloning repositories -> $REPS_DIR"
  log "==============================="

  mkdir -p "$REPS_DIR"

  local failed=0

  for entry in "${REPOS[@]}"; do
    local folder="${entry%%|*}"
    local url="${entry##*|}"
    local dest="$REPS_DIR/$folder"

    if [[ -z "$url" ]]; then
      skip "$folder — URL nao configurada, ignorando"
      continue
    fi

    if [[ -d "$dest/.git" ]]; then
      skip "$folder — ja clonado em $dest"
      continue
    fi

    log "Clonando $folder ..."
    if git clone "$url" "$dest" >> "$LOG_FILE" 2>&1; then
      ok "$folder clonado com sucesso"
    else
      err "$folder falhou ao clonar"
      failed=$(( failed + 1 ))
    fi
  done

  if (( failed > 0 )); then
    err "$failed repositorio(s) falharam. Verifique $LOG_FILE"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  log "Iniciando setup do ambiente — $(date)"
  generate_secrets
  install_system_deps
  install_rust
  clone_repos
  log "Concluido."
}

main "$@"
