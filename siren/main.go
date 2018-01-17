package main

import (
	"flag"
	"log"
	"net/http"
)

var (
	mpdURL = flag.String("mpd", "localhost:6600", "mpd URL")
	listen = flag.String("listen", ":6601", "http listen")
	static = flag.String("docroot", "", "use dir as docroot. Uses build-in files if empty")
)

func main() {
	flag.Parse()

	c, err := NewMPD(*mpdURL)
	if err != nil {
		log.Fatal(err)
	}

	var fs http.FileSystem
	if *static != "" {
		fs = http.Dir(*static)
	} else {
		fs = FS(false)
	}
	log.Printf("listening on %s...\n", *listen)
	log.Fatal(http.ListenAndServe(*listen, mux(c, fs)))
}

func mux(c *MPD, root http.FileSystem) *http.ServeMux {
	r := http.NewServeMux()
	r.HandleFunc("/mpd/ws", websocketHandler(c))
	r.Handle("/", http.FileServer(root))
	return r
}
