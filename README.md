# Undead Workspace

Orquestrador de ambiente para desenvolvimento e testes dos repositorios Undead.

## Objetivo

Esta pasta centraliza o setup local de forma organizada:

1. Sobe dependencias de infraestrutura (PostgreSQL e Redis via Docker Compose).
2. Clona os repositorios configurados (quando ainda nao existem localmente).
3. Cria ambientes Python (.venv) nos projetos Python.
4. Instala dependencias (pip e npm).
5. Gera arquivos .env para configuracao inicial dos projetos.

## Estrutura

- `config/`: lista de repositorios e classificacao por tipo de projeto.
- `scripts/`: scripts de automacao reutilizaveis.
- `docker-compose.yml`: servicos de infraestrutura para desenvolvimento/testes.
- `Makefile`: comandos de alto nivel.

## Pre-requisitos

- Linux com `bash`
- `git`
- `python3` e `python3-venv`
- `node` e `npm`
- `docker` e `docker compose`

Opcional: o script pode tentar instalar dependencias de sistema em distribuicoes suportadas (`apt`, `dnf`, `pacman`).

## Uso rapido

1. Ajuste as URLs dos repositorios em `config/projects.conf`.
2. Execute:

```bash
make bootstrap
```

Ou diretamente:

```bash
./scripts/bootstrap.sh --with-system-deps
```

## Comandos

- `make bootstrap`: setup completo.
- `make deps`: instala dependencias de sistema (quando possivel).
- `make services-up`: sobe banco/redis.
- `make services-down`: derruba banco/redis.
- `make sync`: clona/atualiza repositorios.
- `make envs`: cria `.venv` e `.env`.

## Observacoes

- Se um repositorio ja existir localmente, o clone e ignorado.
- A instalacao de dependencias Python considera `requirements-dev.txt` e `requirements.txt`.
- A instalacao de dependencias Node acontece quando existe `package.json`.
- O setup grava logs em `logs/bootstrap.log`.
