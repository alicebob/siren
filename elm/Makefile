.PHONY: build format libs

build:
	elm-make Main.elm --output=../docroot/s/main.js

format:
	elm-format --yes .

libs:
	elm-package install
