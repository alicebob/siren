.PHONY: build elm release

build:
	$(MAKE) -C siren

elm:
	$(MAKE) -C elm
	$(MAKE) -C siren static build

release:
	$(MAKE) -C elm
	$(MAKE) -C siren static
	go get -v github.com/goreleaser/goreleaser
	cd siren && goreleaser --rm-dist
