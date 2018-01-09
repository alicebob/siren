package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/julienschmidt/httprouter"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

func websocketHandler(c *MPD) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
		// TODO: context to close the ping reader and the watcher
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Println(err)
			return
		}
		defer conn.Close()

		log.Printf("new WS connection")
		defer log.Printf("end of WS connection")

		go func(c *websocket.Conn) {
			for {
				if _, _, err := c.NextReader(); err != nil {
					c.Close()
					break
				}
			}
		}(conn)

		for msg := range c.Watch().C() {
			w, err := conn.NextWriter(websocket.TextMessage)
			if err != nil {
				log.Println(err)
				return
			}
			if err := json.NewEncoder(w).Encode(msg); err != nil {
				log.Println(err)
				return

			}
			w.Close()
		}
	}
}
