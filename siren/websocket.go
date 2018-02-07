package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

// from us to the client
type WSMsg struct {
	Type string      `json:"type"`
	ID   string      `json:"id,omitempty"` // in response to something
	Msg  interface{} `json:"msg"`
}

// from the client to us. Cmd is always filled.
type WSCmd struct {
	Cmd     string  `json:"cmd"`
	ID      string  `json:"id"` // will be used as WSMsg.ID
	What    string  `json:"what"`
	Artist  string  `json:"artist"`
	Album   string  `json:"album"`
	Track   string  `json:"track"`
	File    string  `json:"file"`
	Seconds float64 `json:"seconds"`
	Song    string  `json:"song"`
	Volume  float64 `json:"volume"`
}

func websocketHandler(c *MPD) func(http.ResponseWriter, *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Println(err)
			return
		}
		defer conn.Close()

		log.Printf("new WS connection")
		defer log.Printf("end of WS connection")

		msgs := make(chan WSMsg)

		go func() {
			defer close(msgs)
			for {
				t, m, err := conn.NextReader()
				if err != nil {
					log.Printf("conn err: %s", err)
					return
				}
				switch t {
				case websocket.TextMessage:
					dec := json.NewDecoder(m)
					for {
						cmd := WSCmd{}
						if err := dec.Decode(&cmd); err != nil {
							if err != io.EOF {
								log.Printf("json err: %s", err)
							}
							break
						} else {
							if err := handle(c, msgs, cmd); err != nil {
								log.Printf("handle: %s", err)
							}
						}
					}
				default:
					log.Printf("got a %d. Ignored", t)
				}
			}
		}()

		lock := sync.Mutex{}
		writeMsg := func(msg WSMsg) error {
			lock.Lock()
			defer lock.Unlock()
			w, err := conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return err
			}
			defer w.Close()
			return json.NewEncoder(w).Encode(msg)
		}

		go func() {
		again:
			watch := c.Watch(r.Context())
			for msg := range watch {
				if err := writeMsg(WSMsg{
					Type: msg.Type(),
					Msg:  msg,
				}); err != nil {
					log.Print(err)
					break
				}
			}
			select {
			case <-r.Context().Done():
				return
			default:
				log.Printf("lost connection to MPD")
				time.Sleep(5 * time.Second)
				goto again
			}
		}()

		for msg := range msgs {
			if err := writeMsg(msg); err != nil {
				log.Print(err)
				break
			}
		}
	}
}

var handlers = map[string]func(*MPD, chan WSMsg, WSCmd) error{
	"loaddir": func(c *MPD, msgs chan WSMsg, cmd WSCmd) error {
		ins, err := c.LSInfo(cmd.File)
		if err != nil {
			return err
		}
		msgs <- WSMsg{
			Type: "inodes",
			ID:   cmd.ID,
			Msg:  ins,
		}
		return nil
	},
	"add": func(c *MPD, _ chan WSMsg, cmd WSCmd) error {
		return c.PlaylistAdd(cmd.ID)
	},
	"list": func(c *MPD, msgs chan WSMsg, cmd WSCmd) error {
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
		msgs <- WSMsg{
			Type: "list",
			ID:   cmd.ID,
			Msg:  ls,
		}
		return nil
	},
	"findadd": func(c *MPD, _ chan WSMsg, cmd WSCmd) error {
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
	},
	"playid": func(c *MPD, _ chan WSMsg, cmd WSCmd) error {
		return c.Write(fmt.Sprintf("playid %q", cmd.ID))
	},
	"track": func(c *MPD, msgs chan WSMsg, cmd WSCmd) error {
		ls, err := c.search(fmt.Sprintf("file %q", cmd.File))
		if err != nil {
			return err
		}

		if len(ls) == 0 {
			return nil
		}
		msgs <- WSMsg{
			Type: "track",
			ID:   cmd.ID,
			Msg:  ls[0],
		}
		return nil
	},
	"seek": func(c *MPD, _ chan WSMsg, cmd WSCmd) error {
		return c.Write(fmt.Sprintf("seekid %s %d", cmd.Song, int(cmd.Seconds)))
	},
	"volume": func(c *MPD, _ chan WSMsg, cmd WSCmd) error {
		if v := cmd.Volume; v >= 0 && v <= 100 {
			return c.Write(fmt.Sprintf("setvol %d", int(v)))
		}
		return nil
	},
}

func init() {
	for m, p := range map[string]string{
		"play":     "play",
		"stop":     "stop",
		"next":     "next",
		"previous": "previous",
		"clear":    "clear",
		"pause":    "pause 1",
		"unpause":  "pause 0",
	} {
		handlers[m] = func(p string) func(*MPD, chan WSMsg, WSCmd) error {
			return func(c *MPD, _ chan WSMsg, _ WSCmd) error {
				return c.Write(p)
			}
		}(p)
	}
}

func handle(c *MPD, msgs chan WSMsg, cmd WSCmd) error {
	h, ok := handlers[cmd.Cmd]
	if !ok {
		return fmt.Errorf("unknown command: %q", cmd.Cmd)
	}
	log.Printf("handle %s", cmd.Cmd)
	return h(c, msgs, cmd)
}
