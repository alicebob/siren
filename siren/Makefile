.PHONY: all test build build-pi run static

all: test build

test:
	go test

build:
	go build

build-pi:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=6 go build

run: build
	./siren -docroot ../docroot

static:
	esc -o static.go -prefix=../docroot/ ../docroot/
