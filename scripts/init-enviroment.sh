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
# Instalar dependencias dos repositorios
# ---------------------------------------------------------------------------
install_repo_deps() {
  log "==============================="
  log " Instalando dependencias dos repositorios"
  log "==============================="

  local failed=0

  for entry in "${REPOS[@]}"; do
    local folder="${entry%%|*}"
    local dest="$REPS_DIR/$folder"

    if [[ ! -d "$dest/.git" ]]; then
      skip "$folder — repositorio nao encontrado, ignorando"
      continue
    fi

    # Node.js — package.json presente
    if [[ -f "$dest/package.json" ]]; then
      log "$folder — executando npm install ..."
      if (cd "$dest" && npm install >> "$LOG_FILE" 2>&1); then
        ok "$folder — npm install concluido"
      else
        err "$folder — npm install falhou"
        failed=$(( failed + 1 ))
      fi
    fi

    # Python — requirements.txt ou pyproject.toml presente
    if [[ -f "$dest/requirements.txt" || -f "$dest/pyproject.toml" ]]; then
      log "$folder — criando/atualizando .venv ..."
      if python3 -m venv "$dest/.venv" >> "$LOG_FILE" 2>&1; then
        ok "$folder — .venv criado"
      else
        err "$folder — falha ao criar .venv"
        failed=$(( failed + 1 ))
        continue
      fi

      if [[ -f "$dest/requirements.txt" ]]; then
        log "$folder — instalando requirements.txt ..."
        if "$dest/.venv/bin/pip" install -r "$dest/requirements.txt" >> "$LOG_FILE" 2>&1; then
          ok "$folder — requirements.txt instalado"
        else
          err "$folder — falha ao instalar requirements.txt"
          failed=$(( failed + 1 ))
        fi
      elif [[ -f "$dest/pyproject.toml" ]]; then
        log "$folder — instalando pyproject.toml (pip install -e) ..."
        if "$dest/.venv/bin/pip" install -e "$dest" >> "$LOG_FILE" 2>&1; then
          ok "$folder — pyproject.toml instalado"
        else
          err "$folder — falha ao instalar pyproject.toml"
          failed=$(( failed + 1 ))
        fi
      fi
    fi

    if [[ ! -f "$dest/package.json" && ! -f "$dest/requirements.txt" && ! -f "$dest/pyproject.toml" ]]; then
      skip "$folder — nenhum manifesto de dependencias encontrado"
    fi
  done

  if (( failed > 0 )); then
    err "$failed repositorio(s) com falha. Verifique $LOG_FILE"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Sincronizar senha do Postgres com o .env
# ---------------------------------------------------------------------------
sync_pg_password() {
  log "==============================="
  log " Sincronizando senha do Postgres"
  log "==============================="

  local env_file="$WORKSPACE_DIR/config/secrets/.env"

  if [[ ! -f "$env_file" ]]; then
    err "Arquivo .env nao encontrado: $env_file"
    return 1
  fi

  local db_user db_password
  db_user=$(grep "^DB_USER=" "$env_file" | cut -d= -f2)
  db_password=$(grep "^DB_PASSWORD=" "$env_file" | cut -d= -f2)

  if [[ -z "$db_user" || -z "$db_password" ]]; then
    err "DB_USER ou DB_PASSWORD nao encontrados em $env_file"
    return 1
  fi

  if ! command -v psql &>/dev/null; then
    err "psql nao encontrado — instale postgresql-client"
    return 1
  fi

  log "Atualizando senha do usuario '$db_user' no Postgres ..."
  if sudo -u postgres psql -c "ALTER USER $db_user WITH PASSWORD '$db_password';" >> "$LOG_FILE" 2>&1; then
    ok "Senha de '$db_user' sincronizada com o .env"
  else
    err "Falha ao atualizar senha do '$db_user'. Verifique $LOG_FILE"
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
  install_repo_deps
  sync_pg_password
  log "Concluido."
}

main "$@"
