.PHONY: all test build build-pi run preparerelease release fakerelease

all: test build

test:
	go test

build:
	go build

build-pi: static
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=6 go build

run: build
	./siren -docroot ./docroot

preparerelease: test build
	go get -v github.com/goreleaser/goreleaser

release: preparerelease
	goreleaser --rm-dist

fakerelease: preparerelease
	goreleaser --rm-dist --snapshot
