SHELL := /usr/bin/env bash

ENV ?= dev

.PHONY: bootstrap deps generate-secrets services-up services-down sync envs

bootstrap: generate-secrets
	./scripts/bootstrap.sh --with-system-deps

init:
	./scripts/init-enviroment.sh  

