.PHONY: build elm preparerelease release fakerelease

build:
	$(MAKE) -C siren

elm:
	$(MAKE) -C elm
	$(MAKE) -C siren static build

preparerelease:
	$(MAKE) -C elm
	$(MAKE) -C siren static
	go get -v github.com/goreleaser/goreleaser

release: preparerelease
	cd siren && goreleaser --rm-dist

fakerelease: preparerelease
	cd siren && goreleaser --rm-dist --snapshot
