.PHONY: all build run test docker-up docker-down clean

all: test build

build:
	go build -o bin/server ./cmd/server

run:
	go run ./cmd/server

test:
	go test -v -race ./...

test-integration:
	go test -v -count=1 -tags=integration ./internal/store/...

docker-up:
	docker compose up -d

docker-down:
	docker compose down

healthcheck:
	go run ./cmd/server healthcheck

smoke-test:
	powershell -ExecutionPolicy Bypass -File ../scripts/smoke_test.ps1 -BaseUrl http://localhost:8080

clean:
	rm -rf bin/


