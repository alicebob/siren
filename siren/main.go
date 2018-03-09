package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
)

var (
	version        = "master"
	mpdURL         = flag.String("mpd", "", "MPD address. order of options: this flag, MPD_HOST:MPD_PORT, localhost:6600. port is optional")
	listen         = flag.String("listen", ":6601", "http listen address")
	static         = flag.String("docroot", "", "for development: use directory as docroot, not the build-in files")
	useAlbumartist = flag.Bool("albumartist", true, "use albumartist, not artist")
	showVersion    = flag.Bool("version", false, "show version and exit")
)

func main() {
	flag.Parse()

	if *showVersion {
		fmt.Printf("siren %s\n", version)
		os.Exit(0)
	}

	u := url(*mpdURL)
	mode := ModeArtist
	if *useAlbumartist {
		mode = ModeAlbumartist
	}
	c, err := NewMPD(u, mode)
	if err != nil {
		log.Fatal(err)
	}

	var fs http.FileSystem
	if *static != "" {
		fs = http.Dir(*static)
	} else {
		fs = FS(false)
	}
	log.Printf("MPD used: %s\n", u)
	log.Printf("listening on: %s\n", *listen)
	log.Fatal(http.ListenAndServe(*listen, mux(c, fs)))
}

func mux(c *MPD, root http.FileSystem) *http.ServeMux {
	r := http.NewServeMux()
	r.HandleFunc("/mpd/ws", websocketHandler(c))
	r.Handle("/", http.FileServer(root))
	return r
}

func url(u string) string {
	host, port := "localhost", "6600"

	if h, _ := os.LookupEnv("MPD_HOST"); h != "" {
		host = h
		if p, _ := os.LookupEnv("MPD_PORT"); p != "" {
			port = p
		}
	}

	if u != "" {
		if h, p, err := net.SplitHostPort(u); err != nil {
			host = u
			port = "6600"
		} else {
			host = h
			port = p
		}
	}

	return net.JoinHostPort(host, port)
}
