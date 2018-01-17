.PHONY: build elm

build:
	$(MAKE) -C siren

elm:
	$(MAKE) -C elm
	$(MAKE) -C siren static build
