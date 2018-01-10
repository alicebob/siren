package main

import (
	"flag"
	"log"
	"net/http"

	"github.com/julienschmidt/httprouter"
)

var (
	mpdURL = flag.String("mpd", "localhost:6600", "mpd URL")
	listen = flag.String("listen", ":6601", "http listen")
	static = flag.String("static", "../static/", "points to static/")
)

func main() {
	flag.Parse()

	c, err := NewMPD(*mpdURL)
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("listening on %s...\n", *listen)
	log.Fatal(http.ListenAndServe(*listen, mux(c, *static)))
}

func mux(c *MPD, static string) *httprouter.Router {
	r := httprouter.New()
	if static != "" {
		r.GET("/", func(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
			http.ServeFile(w, r, static+"index.html")
		})
		r.ServeFiles("/s/*filepath", http.Dir(static))
	}
	r.GET("/mpd/play", genHandler(c, "play"))
	r.GET("/mpd/stop", genHandler(c, "stop"))
	r.GET("/mpd/next", genHandler(c, "next"))
	r.GET("/mpd/previous", genHandler(c, "previous"))
	r.GET("/mpd/pause", genHandler(c, "pause 1"))
	r.GET("/mpd/unpause", genHandler(c, "pause 0"))
	r.GET("/mpd/track/:id/play", trackHandler(c, "playid"))
	r.GET("/mpd/ws", websocketHandler(c))
	return r
}