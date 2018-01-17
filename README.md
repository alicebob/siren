Browser based MPD client.

With Elm and `display:grid`.

## Easy build

- You need a Go compiler
- `make`

The binary will be `siren/siren`. It has all resources bundled in the
executable. The default port is http://localhost:6601 .


## CSS dev build

If you want to change the CSS, but don't need changes in Elm:

- `cd siren && make run`
- go to http://localhost:6601/

This will uses the files from `./docroot/`. You can change the files in there
and reload your browser


## Elm + CSS dev build

Compiled .elm files are included in the ./docroot/ directory, so you don't need
an Elm compiler unless you make changes to the Elm code:

- You need a Go and Elm compiler.
- `(cd elm && make)`
- `cd siren && make run`
- go to http://localhost:6601/

`make run` serves the files from disk, so you can recompile the elm code and
reload the browser while changing elm/css.


## Links

- [Music Player Daemon](https://www.musicpd.org)
- [Elm](https://elm-lang.org)
