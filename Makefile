SHELL := /usr/bin/env bash

ENV ?= dev

.PHONY: bootstrap deps generate-secrets services-up services-down sync envs

bootstrap: generate-secrets
	./scripts/bootstrap.sh --with-system-deps

deps:
	./scripts/install_system_deps.sh

generate-secrets:
	python3 scripts/generate_secrets.py --env $(ENV)

generate-secrets-force:
	python3 scripts/generate_secrets.py --env $(ENV) --force

services-up:
	./scripts/start_services.sh up $(ENV)

services-down:
	./scripts/start_services.sh down $(ENV)

sync:
	./scripts/bootstrap.sh --skip-system-deps --skip-services --only-clone

envs: generate-secrets
	./scripts/bootstrap.sh --skip-system-deps --skip-services --skip-clone
