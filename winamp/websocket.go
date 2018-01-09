package main

import (
	"context"
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

type WSMsg struct {
	Type string `json:"type"`
	Msg  Msg    `json:"msg"`
}

func websocketHandler(c *MPD) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
		ctx, cancel := context.WithCancel(r.Context())
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Println(err)
			return
		}
		defer conn.Close()

		log.Printf("new WS connection")
		defer log.Printf("end of WS connection")

		go func(c *websocket.Conn) {
			defer cancel()
			for {
				if _, _, err := c.NextReader(); err != nil {
					c.Close()
					break
				}
			}
		}(conn)

		for msg := range c.Watch(ctx) {
			w, err := conn.NextWriter(websocket.TextMessage)
			if err != nil {
				log.Println(err)
				break
			}
			if err := json.NewEncoder(w).Encode(WSMsg{
				Type: msg.Type(),
				Msg:  msg,
			}); err != nil {
				log.Println(err)
				break
			}
			w.Close()
		}
	}
}
