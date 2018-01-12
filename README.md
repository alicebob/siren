Browser based MPD client.

With Elm and `display:grid`.

== Build

Assuming there is an mpd running locally at :6600:

- Need a Go and Elm compiler.
- `(cd elm && make)`
- `cd siren && make run`
- go to http://localhost:6601/

== Devel

(Example playlist)[static/playlist.html] to change the playlist CSS. The
page is mostly identical to what Elm generates.

