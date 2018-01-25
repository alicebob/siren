Browser based MPD client.

Make with Elm and `display:grid`.

<img src="./img_playlist.png" width="400" /><img src="./img_files.png" width="400" />


## Build

### Vanilla build

- you need a Go compiler
- run `make`

The binary will be `siren/siren`. It has all resources bundled in the
executable, so you can copy it to other machines.

By default it binds to [*:6601](http://localhost:6601) , and it searches for MPD on localhost. See `./siren --help` to change settings.

### Raspberry Pi build

Thanks to Go's cross-platform support you can build Siren on your laptop, and copy the executable to your Rasberry Pi.

- you need a Go compiler on your laptop
- `(cd build && make build-pi)`
- copy `siren/siren` to your Raspberry Pi
- open http://your_raspberry:6601/

Done, no other files needed.


## Development

Usually the CSS and compiled Elm files are embedded in the executable, but you
can use the filesystem while developing:

- you need a Go and an Elm compiler
- `(cd siren && make run)`
- `cd elm && make`
- open http://localhost:6601/


## Links

- [Music Player Daemon](https://www.musicpd.org)
- [Elm](https://elm-lang.org)
