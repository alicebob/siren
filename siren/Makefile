.PHONY: all test build build-pi run static

all: test build

test: static
	go test

build: static
	go build

build-pi: static
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=6 go build

run: build
	./siren -docroot ../docroot

static:
	go get github.com/mjibson/esc
	esc -o static.go -prefix=../docroot/ ../docroot/
