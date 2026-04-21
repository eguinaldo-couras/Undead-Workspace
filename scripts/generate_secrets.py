#!/usr/bin/env python3
"""
Gerador central de secrets para o workspace Undead.

Gera:
  - Par de chaves RSA 2048-bit (JWT, formato PKCS8/PEM em uma linha)
  - Senhas seguras para cada banco de dados
  - Senha para Redis
  - Chave aleatoria de aplicacao (APP_SECRET_KEY)

Saidas:
  - config/secrets/.env.<ENVIRONMENT>   (arquivo central de referencia)
  - .env na raiz do Undead-Workspace

Uso:
  python3 scripts/generate_secrets.py [--env dev|test|staging] [--force] [--root .]
  python3 scripts/generate_secrets.py --only-central      # apenas gera o arquivo central
  python3 scripts/generate_secrets.py --only-distribute   # apenas regera o .env a partir do central
"""

from __future__ import annotations

import argparse
import os
import secrets
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Dependencia opcional: cryptography (necessaria apenas para geracao de RSA)
# ---------------------------------------------------------------------------
try:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    HAS_CRYPTOGRAPHY = True
except ImportError:
    HAS_CRYPTOGRAPHY = False


# ---------------------------------------------------------------------------
# Constantes fixas de cada projeto (nao aleatorizadas)
# ---------------------------------------------------------------------------

# Portas e hosts fixos (nao mudam por ambiente)
FIXED = {
    "POSTGRES_HOST": "127.0.0.1",
    "POSTGRES_PORT": "5432",
    "REDIS_HOST": "127.0.0.1",
    "REDIS_PORT": "6379",
    # Admin Portal API
    "ADMIN_PORTAL_APP_HOST": "127.0.0.1",
    "ADMIN_PORTAL_APP_PORT": "8001",
    # Undead API
    "API_APP_HOST": "127.0.0.1",
    "API_APP_PORT": "8000",
}

# Projetos com banco de dados proprio
DB_PROJECTS = {
    "Undead-Admin-Portal-API": {
        "user": "undead_admin",
        "db": "undead_admin_portal",
    },
    "Undead-API": {
        "user": "undead_api",
        "db": "undead_api",
    },
    "Undead-Migrations": {
        # Usa as mesmas credenciais do Admin Portal (schema compartilhado)
        "user": "undead_admin",
        "db": "undead_admin_portal",
        "shared_with": "Undead-Admin-Portal-API",
    },
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def rand_token(n: int = 64) -> str:
    """Gera um token URL-safe aleatorio com entropia equivalente a n bytes."""
    return secrets.token_urlsafe(n)


def generate_rsa_keypair() -> tuple[str, str]:
    """
    Gera um par RSA 2048-bit PKCS8 e retorna (private_pem_oneline, public_pem_oneline).
    As quebras de linha sao substituidas por \\n para uso em arquivos .env.
    """
    if not HAS_CRYPTOGRAPHY:
        print(
            "[ERRO] A biblioteca 'cryptography' nao esta instalada.\n"
            "       Execute: pip install cryptography",
            file=sys.stderr,
        )
        sys.exit(1)

    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=8096,
    )

    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")

    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode("utf-8")

    # Converte para formato de uma linha aceito pelo pydantic-settings
    private_oneline = private_pem.replace("\n", "\\n").strip("\\n")
    public_oneline = public_pem.replace("\n", "\\n").strip("\\n")

    return private_oneline, public_oneline


def write_env(path: Path, entries: dict[str, str], *, force: bool = False) -> None:
    """Escreve um arquivo .env. Nao sobrescreve por padrao."""
    if path.exists() and not force:
        print(f"  [ignorado] {path} ja existe  (use --force para regenerar)")
        return

    path.parent.mkdir(parents=True, exist_ok=True)

    lines = ["# Gerado automaticamente por generate_secrets.py — NAO versionar\n"]
    current_section = ""
    for key, value in entries.items():
        section = key.split("_")[0]
        if section != current_section:
            current_section = section
            lines.append("")
        # Chaves com espacos/caracteres especiais recebem aspas
        if any(c in str(value) for c in (' ', '"', "'", '\n', '\\n', '=')):
            lines.append(f'{key}="{value}"')
        else:
            lines.append(f"{key}={value}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(path, 0o600)
    print(f"  [ok] {path}")


# ---------------------------------------------------------------------------
# Geracao do arquivo central de secrets
# ---------------------------------------------------------------------------

def generate_central(env: str, root: Path, force: bool) -> dict[str, str]:
    """
    Gera o arquivo config/secrets/.env.<env> e retorna o dicionario de secrets.
    Se o arquivo ja existir e --force nao for passado, carrega os valores existentes.
    """
    central_path = root / "config" / "secrets" / f".env.{env}"

    if central_path.exists() and not force:
        print(f"  [carregando] secrets existentes de {central_path}")
        return _load_env_file(central_path)

    print(f"\n  Gerando par de chaves RSA...")
    jwt_private, jwt_public = generate_rsa_keypair()

    # Senhas por projeto de banco
    db_passwords: dict[str, str] = {}
    for project, meta in DB_PROJECTS.items():
        shared = meta.get("shared_with")
        if shared:
            db_passwords[project] = db_passwords[shared]
        else:
            db_passwords[project] = rand_token(24)

    redis_password = rand_token(24)
    app_secret = rand_token(48)

    admin_db = DB_PROJECTS["Undead-Admin-Portal-API"]
    api_db = DB_PROJECTS["Undead-API"]
    mig_db = DB_PROJECTS["Undead-Migrations"]

    pg_host = FIXED["POSTGRES_HOST"]
    pg_port = FIXED["POSTGRES_PORT"]

    central: dict[str, str] = {
        # Ambiente
        "APP_ENV": env,

        # JWT
        "JWT_ALGORITHM": "RS256",
        "JWT_KEY_ID": "v1",
        "JWT_PRIVATE_KEY": jwt_private,
        "JWT_PUBLIC_KEY": jwt_public,

        # App
        "APP_SECRET_KEY": app_secret,

        # Redis
        "REDIS_HOST": FIXED["REDIS_HOST"],
        "REDIS_PORT": FIXED["REDIS_PORT"],
        "REDIS_PASSWORD": redis_password,
        "REDIS_URL": f"redis://:{redis_password}@{FIXED['REDIS_HOST']}:{FIXED['REDIS_PORT']}/0",

        # Postgres - Admin Portal
        "ADMIN_PORTAL_DB_HOST": pg_host,
        "ADMIN_PORTAL_DB_PORT": pg_port,
        "ADMIN_PORTAL_DB_NAME": admin_db["db"],
        "ADMIN_PORTAL_DB_USER": admin_db["user"],
        "ADMIN_PORTAL_DB_PASSWORD": db_passwords["Undead-Admin-Portal-API"],
        "ADMIN_PORTAL_DATABASE_URL": (
            f"postgresql+psycopg2://{admin_db['user']}:{db_passwords['Undead-Admin-Portal-API']}"
            f"@{pg_host}:{pg_port}/{admin_db['db']}"
        ),

        # Postgres - API
        "API_DB_HOST": pg_host,
        "API_DB_PORT": pg_port,
        "API_DB_NAME": api_db["db"],
        "API_DB_USER": api_db["user"],
        "API_DB_PASSWORD": db_passwords["Undead-API"],
        "API_DATABASE_URL": (
            f"postgresql+psycopg2://{api_db['user']}:{db_passwords['Undead-API']}"
            f"@{pg_host}:{pg_port}/{api_db['db']}"
        ),

        # Migrations (compartilha com Admin Portal)
        "MIGRATIONS_DATABASE_URL": (
            f"postgresql+psycopg2://{mig_db['user']}:{db_passwords['Undead-Migrations']}"
            f"@{pg_host}:{pg_port}/{mig_db['db']}"
        ),

        # Docker Compose (variaveis lidas diretamente pelo compose)
        "POSTGRES_USER": "postgres",
        "POSTGRES_PASSWORD": rand_token(24),
        "POSTGRES_PORT": pg_port,
    }

    print(f"\n  Escrevendo arquivo central...")
    write_env(central_path, central, force=force)
    return central


def _load_env_file(path: Path) -> dict[str, str]:
    """Carrega um arquivo .env em um dicionario, ignorando comentarios e linhas vazias."""
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, raw_value = line.partition("=")
        value = raw_value.strip().strip('"').strip("'")
        result[key.strip()] = value
    return result


# ---------------------------------------------------------------------------
# Builder do .env do workspace
# ---------------------------------------------------------------------------

def build_api_env(s: dict[str, str]) -> dict[str, str]:
    api_port = FIXED["API_APP_PORT"]
    api_admin_portal_port = FIXED["ADMIN_PORTAL_APP_PORT"]
    return {
        "APP_ENV": s["APP_ENV"],
        "DEBUG": "false",
        "ADMIN_PORTAL_BASE_URL": f"http://127.0.0.1:{api_admin_portal_port}",
        "RAG_API_BASE_URL": f"http://127.0.0.1:{api_port}",
        "ADMIN_PORTAL_HOST": FIXED["ADMIN_PORTAL_APP_HOST"],
        "ADMIN_PORTAL_PORT": FIXED["ADMIN_PORTAL_APP_PORT"],
        "RAG_API_HOST": FIXED["API_APP_HOST"],
        "RAG_API_PORT": FIXED["API_APP_PORT"],
        "DB_HOST": s["ADMIN_PORTAL_DB_HOST"],
        "DB_PORT": s["ADMIN_PORTAL_DB_PORT"],
        "DB_NAME": s["ADMIN_PORTAL_DB_NAME"],
        "DB_USER": s["ADMIN_PORTAL_DB_USER"],
        "DB_PASSWORD": s["ADMIN_PORTAL_DB_PASSWORD"],
        "DB_SUPERUSER": "postgres",
        "DATABASE_URL": s["ADMIN_PORTAL_DATABASE_URL"],
        "REDIS_URL": s["REDIS_URL"],
        "JWT_ACCESS_TOKEN_EXPIRE_MINUTES": "30",
        "JWT_ALGORITHM": s["JWT_ALGORITHM"],
        "JWT_KEY_ID": s["JWT_KEY_ID"],
        "JWT_PRIVATE_KEY": s["JWT_PRIVATE_KEY"],
        "JWT_PUBLIC_KEY": s["JWT_PUBLIC_KEY"],
        "JWT_ISSUER": "undead-admin-portal",
        "JWT_AUDIENCE": "undead-admin-portal",
        "CORS_ORIGINS": "http://localhost:5173",
    }


def write_workspace_env(secrets_map: dict[str, str], workspace_root: Path, force: bool) -> None:
    """Gera um unico .env em config/secrets/ usando build_api_env."""
    print("\n--- Gerando .env em config/secrets/ ---")
    env_path = workspace_root / "config" / "secrets" / ".env"
    entries = build_api_env(secrets_map)
    write_env(env_path, entries, force=force)


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera secrets centralizados e distribui .env por projeto."
    )
    parser.add_argument(
        "--env",
        default="dev",
        choices=["dev", "test", "staging"],
        help="Ambiente alvo (default: dev)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Sobrescreve arquivos .env existentes",
    )
    parser.add_argument(
        "--root",
        default=None,
        help="Caminho para a raiz do Undead-Workspace (detectado automaticamente se omitido)",
    )
    parser.add_argument(
        "--only-central",
        action="store_true",
        help="Apenas gera o arquivo central, sem distribuir para os projetos",
    )
    parser.add_argument(
        "--only-distribute",
        action="store_true",
        help="Apenas distribui um arquivo central ja existente (nao gera novos secrets)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    script_dir = Path(__file__).resolve().parent
    workspace_root_default = script_dir.parent          # Undead-Workspace/

    root: Path = Path(args.root).resolve() if args.root else workspace_root_default

    print(f"=== Undead Secrets Generator ===")
    print(f"  Ambiente  : {args.env}")
    print(f"  Workspace : {root}")

    if args.only_distribute and args.only_central:
        print("[ERRO] --only-central e --only-distribute sao mutualmente exclusivos", file=sys.stderr)
        sys.exit(1)

    if args.only_distribute:
        central_path = root / "config" / "secrets" / f".env.{args.env}"
        if not central_path.exists():
            print(
                f"[ERRO] Arquivo central nao encontrado: {central_path}\n"
                "       Execute sem --only-distribute para gerá-lo primeiro.",
                file=sys.stderr,
            )
            sys.exit(1)
        print(f"\n--- Carregando secrets de {central_path} ---")
        secrets_map = _load_env_file(central_path)
    else:
        print("\n--- Gerando arquivo central de secrets ---")
        secrets_map = generate_central(args.env, root, force=args.force)

    if not args.only_central:
        write_workspace_env(secrets_map, root, force=args.force)

    print("\n[concluido] .env gerado com sucesso.")
    print("  IMPORTANTE: nunca versione config/secrets/.env.* nem o .env da raiz")


if __name__ == "__main__":
    main()
