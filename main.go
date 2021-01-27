package main

import (
	"embed"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
)

var (
	version        = "master"
	mpdURL         = flag.String("mpd", "", "MPD address. order of options: this flag, MPD_HOST:MPD_PORT, localhost:6600. port is optional")
	listen         = flag.String("listen", ":6601", "http listen address")
	static         = flag.String("docroot", "", "for development: use directory as docroot, not the built-in files")
	useAlbumartist = flag.Bool("albumartist", true, "use albumartist, not artist")
	showVersion    = flag.Bool("version", false, "show version and exit")
)

//go:embed docroot/*
var docroot embed.FS

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

	var root fs.FS
	if *static != "" {
		root = os.DirFS(*static)
	} else {
		root, _ = fs.Sub(docroot, "docroot")
	}
	log.Printf("MPD used: %s\n", u)
	log.Printf("listening on: %s\n", *listen)
	log.Fatal(http.ListenAndServe(*listen, mux(c, root)))
}

func mux(c *MPD, root fs.FS) *http.ServeMux {
	r := http.NewServeMux()
	r.HandleFunc("/mpd/ws", websocketHandler(c))
	r.Handle("/", http.FileServer(http.FS(root)))
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
