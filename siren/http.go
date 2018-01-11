package main

import (
	"log"
	"net/http"

	"github.com/julienschmidt/httprouter"
)

func genHandler(c *MPD, cmd string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
		if err := c.Write(cmd); err != nil {
			log.Printf("%q: %s", cmd, err)
			w.WriteHeader(502)
			return
		}
		w.WriteHeader(200)
	}
}

func trackHandler(c *MPD, cmd string) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
		id := p.ByName("id")
		if err := c.Write(cmd + " " + id); err != nil {
			log.Printf("%q: %s", cmd, err)
			w.WriteHeader(502)
			return
		}
		w.WriteHeader(200)
	}
}
