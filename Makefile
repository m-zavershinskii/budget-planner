.PHONY: help db-up db-down db-reset migrate-build migrate-up migrate-down migrate-status migrate-version migrate-create sqlc run build

GOOSE_VERSION ?= v3.28.0
MIGRATE = GOOSE_VERSION=$(GOOSE_VERSION) docker compose run --rm migrate
SQLC ?= $(shell command -v sqlc 2>/dev/null || printf '%s/bin/sqlc' "$$(go env GOPATH)")

help:
	@printf '%s\n' \
		'make db-up                         Start PostgreSQL' \
		'make db-down                       Stop local containers' \
		'make db-reset                      Recreate PostgreSQL and apply all migrations' \
		'make migrate-build                 Build the Goose migration container' \
		'make migrate-up                    Apply all pending migrations' \
		'make migrate-down                  Roll back one migration' \
		'make migrate-status                Show migration status' \
		'make migrate-version               Show current DB migration version' \
		'make migrate-create name=<name>    Create a timestamped SQL migration' \
		'make sqlc                          Generate typed database code' \
		'make run                           Run the Go server locally' \
		'make build                         Build the application binary'

db-up:
	docker compose up -d postgres

db-down:
	docker compose down

db-reset:
	docker compose down -v
	docker compose up -d postgres
	$(MIGRATE) up

migrate-build:
	GOOSE_VERSION=$(GOOSE_VERSION) docker compose build migrate

migrate-up:
	$(MIGRATE) up

migrate-down:
	$(MIGRATE) down

migrate-status:
	$(MIGRATE) status

migrate-version:
	$(MIGRATE) version

migrate-create:
	@test -n "$(name)" || (echo "usage: make migrate-create name=add_accounts" >&2; exit 1)
	$(MIGRATE) create "$(name)" sql

sqlc:
	$(SQLC) generate

run:
	go run ./cmd/server

build:
	mkdir -p bin
	go build -o bin/budget-planner ./cmd/server
