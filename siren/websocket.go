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

// from us to the client
type WSMsg struct {
	Type string `json:"type"`
	Msg  Msg    `json:"msg"`
}

// from the client to us. Cmd is always filled.
type WSCmd struct {
	Cmd    string `json:"cmd"`
	ID     string `json:"id"`
	What   string `json:"what"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
	Track  string `json:"track"`
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
	case "list":
		log.Println("handle list")
		var (
			ls  []DBEntry
			err error
		)
		switch cmd.What {
		case "artists":
			ls, err = c.Artists()
		case "artistalbums":
			ls, err = c.ArtistAlbums(cmd.Artist)
		case "araltracks":
			ls, err = c.ArtistAlbumTracks(cmd.Artist, cmd.Album)
		default:
			err = fmt.Errorf("unknown what: %q", cmd.What)
		}
		if err != nil {
			return err
		}
		msgs <- DBList{
			ID:   cmd.ID,
			List: ls,
		}
		return nil
	case "findadd":
		log.Println("handle findadd")
		p := "findadd"
		if a := cmd.Artist; a != "" {
			p = fmt.Sprintf("%s artist %q", p, a)
		}
		if a := cmd.Album; a != "" {
			p = fmt.Sprintf("%s album %q", p, a)
		}
		if t := cmd.Track; t != "" {
			p = fmt.Sprintf("%s title %q", p, t)
		}
		return c.Write(p)
	default:
		return fmt.Errorf("unknown command: %q", cmd.Cmd)
	}
}
