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

type WSMsg interface {
	Type() string
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

		lock := sync.Mutex{}
		writeMsg := func(msg WSMsg) error {
			lock.Lock()
			defer lock.Unlock()
			w, err := conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return err
			}
			defer w.Close()
			return json.NewEncoder(w).Encode(struct {
				Type string `json:"type"`
				Msg  WSMsg  `json:"msg"`
			}{
				Type: msg.Type(),
				Msg:  msg,
			})
		}

		go func() {
		again:
			watch := c.Watch(r.Context())
			for msg := range watch {
				if err := writeMsg(msg); err != nil {
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
					cmd := struct {
						Cmd  string          `json:"cmd"`
						Args json.RawMessage `json:"args"`
					}{}
					if err := dec.Decode(&cmd); err != nil {
						if err != io.EOF {
							log.Printf("json err: %s", err)
						}
						break
					} else {
						if err := handle(c, writeMsg, cmd.Cmd, cmd.Args); err != nil {
							log.Printf("handle: %s", err)
						}
					}
				}
			default:
				log.Printf("got a %d. Ignored", t)
			}
		}
	}
}

type WSInodes struct {
	ID     string  `json:"id"`
	Inodes []Inode `json:"inodes"`
}

func (w WSInodes) Type() string { return "inodes" }

type WSList struct {
	ID   string    `json:"id"`
	List []DBEntry `json:"list"`
}

func (w WSList) Type() string { return "list" }

type WSTrack struct {
	ID    string `json:"id"`
	Track Track  `json:"track"`
}

func (w WSTrack) Type() string { return "track" }

var handlers = map[string]func(*MPD, json.RawMessage) (WSMsg, error){
	"loaddir": func(c *MPD, args json.RawMessage) (WSMsg, error) {
		var arg struct {
			ID   string `json:"id"`
			File string `json:"file"`
		}
		if err := json.Unmarshal(args, &arg); err != nil {
			return nil, err
		}
		ins, err := c.LSInfo(arg.File)
		if err != nil {
			return nil, err
		}
		return WSInodes{
			ID:     arg.ID,
			Inodes: ins,
		}, nil
	},
	"add": func(c *MPD, args json.RawMessage) (WSMsg, error) {
		var arg struct {
			ID string `json:"id"`
		}
		if err := json.Unmarshal(args, &arg); err != nil {
			return nil, err
		}
		return nil, c.PlaylistAdd(arg.ID)
	},
	"list": func(c *MPD, args json.RawMessage) (WSMsg, error) {
		var (
			arg struct {
				ID     string `json:"id"`
				What   string `json:"what"`
				Artist string `json:"artist"`
				Album  string `json:"album"`
			}
			ls  []DBEntry
			err error
		)
		if err := json.Unmarshal(args, &arg); err != nil {
			return nil, err
		}
		switch arg.What {
		case "artists":
			ls, err = c.Artists()
		case "artistalbums":
			ls, err = c.ArtistAlbums(arg.Artist)
		case "araltracks":
			ls, err = c.ArtistAlbumTracks(arg.Artist, arg.Album)
		default:
			err = fmt.Errorf("unknown what: %q", arg.What)
		}
		if err != nil {
			return nil, err
		}
		return WSList{
			ID:   arg.ID,
			List: ls,
		}, nil
	},
	"findadd": func(c *MPD, args json.RawMessage) (WSMsg, error) {
		var arg struct {
			Artist string `json:"artist"`
			Album  string `json:"album"`
			Track  string `json:"track"`
		}
		if err := json.Unmarshal(args, &arg); err != nil {
			return nil, err
		}
		p := "findadd"
		if a := arg.Artist; a != "" {
			p = fmt.Sprintf("%s artist %q", p, a)
		}
		if a := arg.Album; a != "" {
			p = fmt.Sprintf("%s album %q", p, a)
		}
		if t := arg.Track; t != "" {
			p = fmt.Sprintf("%s title %q", p, t)
		}
		return nil, c.Write(p)
	},
	"playid": func(c *MPD, args json.RawMessage) (WSMsg, error) {
		var arg struct {
			ID string `json:"id"`
		}
		if err := json.Unmarshal(args, &arg); err != nil {
			return nil, err
		}
		return nil, c.Write(fmt.Sprintf("playid %q", arg.ID))
	},
	"track": func(c *MPD, args json.RawMessage) (WSMsg, error) {
		var arg struct {
			ID   string `json:"id"`
			File string `json:"file"`
		}
		if err := json.Unmarshal(args, &arg); err != nil {
			return nil, err
		}
		ls, err := c.search(fmt.Sprintf("file %q", arg.File))
		if err != nil {
			return nil, err
		}

		if len(ls) == 0 {
			return nil, nil
		}
		return WSTrack{
			ID:    arg.ID,
			Track: ls[0],
		}, nil
	},
	"seek": func(c *MPD, args json.RawMessage) (WSMsg, error) {
		var arg struct {
			Song    string  `json:"song"`
			Seconds float64 `json:"seconds"`
		}
		if err := json.Unmarshal(args, &arg); err != nil {
			return nil, err
		}
		return nil, c.Write(fmt.Sprintf("seekid %s %d", arg.Song, int(arg.Seconds)))
	},
	"volume": func(c *MPD, args json.RawMessage) (WSMsg, error) {
		var arg struct {
			Volume float64 `json:"volume"`
		}
		if err := json.Unmarshal(args, &arg); err != nil {
			return nil, err
		}
		if v := arg.Volume; v >= 0 && v <= 100 {
			return nil, c.Write(fmt.Sprintf("setvol %d", int(v)))
		}
		return nil, nil
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
		handlers[m] = func(p string) func(*MPD, json.RawMessage) (WSMsg, error) {
			return func(c *MPD, _ json.RawMessage) (WSMsg, error) {
				return nil, c.Write(p)
			}
		}(p)
	}
}

func handle(c *MPD, writeMsg func(WSMsg) error, cmd string, args json.RawMessage) error {
	h, ok := handlers[cmd]
	if !ok {
		return fmt.Errorf("unknown command: %q", cmd)
	}
	log.Printf("handle %s", cmd)
	msg, err := h(c, args)
	if err != nil {
		return err
	}
	if msg != nil {
		return writeMsg(msg)
	}
	return nil
}
