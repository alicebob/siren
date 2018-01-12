Browser based MPD client.

With Elm and `display:grid`.

## Build

Assuming there is an mpd running locally at :6600:

- Need a Go and Elm compiler.
- `(cd elm && make)`
- `cd siren && make run`
- go to http://localhost:6601/

## Devel

There is a static example playlist in /static/playlist.html to easily work on the playlist CSS. The
page is mostly identical to what Elm generates.

## Links

- [Music Player Daemon](https://www.musicpd.org)
- [Elm](https://elm-lang.org)
