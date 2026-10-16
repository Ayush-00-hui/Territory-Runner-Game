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

clean:
	rm -rf bin/

