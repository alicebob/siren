package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/julienschmidt/httprouter"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

// from use to the client
type WSMsg struct {
	Type string `json:"type"`
	Msg  Msg    `json:"msg"`
}

// from the client to us
type WSCmd struct {
	Cmd string `json:"cmd"`
	ID  string `json:"id"`
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

		msgs := make(chan Msg)

		go func() {
			defer cancel()
			for {
				t, m, err := conn.NextReader()
				if err != nil {
					conn.Close()
					break
				}
				if t == websocket.TextMessage {
					cmd := WSCmd{}
					if err := json.NewDecoder(m).Decode(&cmd); err != nil {
						log.Printf("json err: %s", err)
					} else {
						if err := handle(c, msgs, cmd); err != nil {
							log.Printf("handle: %s", err)
						}
					}
				}
			}
		}()

		go func() {
			for msg := range c.Watch(ctx) {
				msgs <- msg
			}
		}()

		for msg := range msgs {
			w, err := conn.NextWriter(websocket.TextMessage)
			if err != nil {
				log.Println(err)
				break
			}
			m := WSMsg{
				Type: msg.Type(),
				Msg:  msg,
			}
			if err := json.NewEncoder(w).Encode(m); err != nil {
				log.Println(err)
				break
			}
			w.Close()
		}
		// TODO: close msgs
	}
}

func handle(c *MPD, msgs chan Msg, cmd WSCmd) error {
	switch cmd.Cmd {
	case "loaddir":
		log.Println("handle loaddir")
		ins, err := c.LSInfo(cmd.ID)
		if err != nil {
			return err
		}
		msgs <- Inodes{
			ID:     cmd.ID,
			Inodes: ins,
		}
		return nil
	case "add":
		log.Println("handle add playlist")
		return c.PlaylistAdd(cmd.ID)
	default:
		return fmt.Errorf("unknown command: %q", cmd.Cmd)
	}
}
