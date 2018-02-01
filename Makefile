.PHONY: build build-pi preparerelease release fakerelease

build:
	$(MAKE) -C elm
	$(MAKE) -C siren

build-pi:
	$(MAKE) -C elm
	$(MAKE) -C siren build-pi

preparerelease:
	$(MAKE) -C elm
	$(MAKE) -C siren static
	go get -v github.com/goreleaser/goreleaser

release: preparerelease
	cd siren && goreleaser --rm-dist

fakerelease: preparerelease
	cd siren && goreleaser --rm-dist --snapshot
