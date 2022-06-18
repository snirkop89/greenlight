SHELL ?= /bin/bash

# include variables from the .envrc file
include .envrc

# =========================================================== #
# HELPERS
# =========================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@echo -n 'Are you sure? [y/N]' && read ans && [ $${ans:-N} = y ]

# =========================================================== #
# Development
# =========================================================== #

## run/api: run the cmd/api application
.PHONY: run/api
run/api:
	go run ./cmd/api/ -db-dsn=${GREENLIGHT_DB_DSN}


## db/psql: connect to the database using psql
.PHONY: db/psql
db/psql:
	psql ${GREENLIGHT_DB_DSN}

## db/migrations/new name=$1: create a new database migration
.PHONY: db/migrations/new
db/migrations/new:
	@echo 'Creating migration files for ${name}'
	migrate create -seq -ext=.sql -dir=./migrations ${name}

## db/migrations/up: apply all up database migrations
.PHONY: db/migrations/up
db/migrations/up: confirm
	@echo 'Running up migrations'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} up

# =========================================================== #
# QUALITY CONTORL
# =========================================================== #

## audit: tidy dependencies and format, vet and test all code
.PHONY: audit
audit: vendor
	@echo 'Formatting code...'
	go fmt ./cmd/... ./internal/...
	@echo 'Vetting code...'
	go vet ./cmd/... ./internal/...
	staticcheck ./cmd/... ./internal/...
	@echo 'Running tests...'
	go test -race -vet=off ./cmd/... ./internal/...

## vendor: tidy and vendor dependencies
.PHONE: vendor
vendor:
	@echo 'Tidying and verifying module dependencies...'
	go mod tidy -e
	go mod verify
	@echo 'Vendoring dependencies...'
	go mod vendor -e

# =========================================================== #
# BUILD
# =========================================================== #

## build/api: build the cmd/api application
.PHONY: build/api
build/api:
	@echo 'Building cmd/api...'
	go build -ldflags='-s' -o=./bin/api ./cmd/api
	GOOS=linux GOARCH=amd64 go build -ldflags='-s' -o=./bin/linux_amd64/api ./cmd/api

# =========================================================== #
# PRODUCTION
# =========================================================== #

## production/connect: connect to the production server
.PHONY: production/connect
production/connect:
	ssh greenlight@${PRODUCTION_HOST_IP}

## production/deploy/api: deploy the api to production
.PHONY: production/deploy/api
production/deploy/api:
	rsync -P ./bin/linux_amd64/api greenlight@${PRODUCTION_HOST_IP}:~
	rsync -rP --delete ./migrations greenlight@${PRODUCTION_HOST_IP}:~
	rsync -P ./remote/production/api.service greenlight@${PRODUCTION_HOST_IP}:~
	rsync -P ./remote/production/Caddyfile greenlight@${PRODUCTION_HOST_IP}:~
	ssh -t greenlight@${PRODUCTION_HOST_IP} '\
		migrate -path ~/migrations -database $$GREENLIGHT_DB_DSN up \
		&& sudo mv ~/api.service /etc/systemd/system/ \
		&& sudo systemctl enable api \
		&& sudo systemctl restart api \
		&& sudo mv ~/Caddyfile /etc/caddy/ \
		&& sudo systemctl reload caddy \
	'