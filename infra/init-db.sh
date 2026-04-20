#!/usr/bin/env bash
# Executado automaticamente pelo Postgres na primeira inicializacao do container.
# Cria os usuarios e bancos de dados necessarios para cada projeto.
# Variaveis sao injetadas pelo docker-compose via environment.
set -euo pipefail

run_sql() {
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" "$@"
}

# ---------------------------------------------------------------------------
# Admin Portal
# ---------------------------------------------------------------------------
echo "[init-db] Criando usuario: $ADMIN_PORTAL_DB_USER"
run_sql --dbname postgres <<-SQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$ADMIN_PORTAL_DB_USER') THEN
      CREATE ROLE "$ADMIN_PORTAL_DB_USER" WITH LOGIN PASSWORD '$ADMIN_PORTAL_DB_PASSWORD';
    ELSE
      ALTER ROLE "$ADMIN_PORTAL_DB_USER" WITH PASSWORD '$ADMIN_PORTAL_DB_PASSWORD';
    END IF;
  END
  \$\$;
SQL

echo "[init-db] Criando banco: $ADMIN_PORTAL_DB_NAME"
run_sql --dbname postgres <<-SQL
  SELECT 'CREATE DATABASE "$ADMIN_PORTAL_DB_NAME" OWNER "$ADMIN_PORTAL_DB_USER"'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$ADMIN_PORTAL_DB_NAME')
  \gexec
SQL

run_sql --dbname "$ADMIN_PORTAL_DB_NAME" <<-SQL
  GRANT ALL PRIVILEGES ON DATABASE "$ADMIN_PORTAL_DB_NAME" TO "$ADMIN_PORTAL_DB_USER";
  GRANT ALL ON SCHEMA public TO "$ADMIN_PORTAL_DB_USER";
SQL

# ---------------------------------------------------------------------------
# Undead API
# ---------------------------------------------------------------------------
echo "[init-db] Criando usuario: $API_DB_USER"
run_sql --dbname postgres <<-SQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$API_DB_USER') THEN
      CREATE ROLE "$API_DB_USER" WITH LOGIN PASSWORD '$API_DB_PASSWORD';
    ELSE
      ALTER ROLE "$API_DB_USER" WITH PASSWORD '$API_DB_PASSWORD';
    END IF;
  END
  \$\$;
SQL

echo "[init-db] Criando banco: $API_DB_NAME"
run_sql --dbname postgres <<-SQL
  SELECT 'CREATE DATABASE "$API_DB_NAME" OWNER "$API_DB_USER"'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$API_DB_NAME')
  \gexec
SQL

run_sql --dbname "$API_DB_NAME" <<-SQL
  GRANT ALL PRIVILEGES ON DATABASE "$API_DB_NAME" TO "$API_DB_USER";
  GRANT ALL ON SCHEMA public TO "$API_DB_USER";
SQL

echo "[init-db] Bancos e usuarios criados com sucesso."
