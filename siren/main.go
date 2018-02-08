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
	version     = "master"
	mpdURL      = flag.String("mpd", "localhost:6600", "MPD address. Uses MPD_HOST by default, port optional")
	listen      = flag.String("listen", ":6601", "http listen address")
	static      = flag.String("docroot", "", "for development: use directory as docroot, not the build-in files")
	showVersion = flag.Bool("version", false, "show version and exit")
)

func main() {
	flag.Parse()

	if *showVersion {
		fmt.Printf("siren %s\n", version)
		os.Exit(0)
	}

	u := url(*mpdURL)
	c, err := NewMPD(u)
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
	if h, _ := os.LookupEnv("MPD_HOST"); h != "" {
		u = h
	}
	if _, _, err := net.SplitHostPort(u); err != nil {
		u = u + ":6600"
	}
	return u
}
