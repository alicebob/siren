package main

import (
	"context"
	"encoding/json"
	"errors"
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

type Tag struct {
	Name  string          `json:"name"`
	Value json.RawMessage `json:"value"`
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

			value, err := json.Marshal(msg)
			if err != nil {
				return err
			}
			return json.NewEncoder(w).Encode(Tag{
				Name:  "siren/" + msg.Type(),
				Value: value,
			})
		}

		// init client state
		config := WSConfig{
			ArtistMode: c.artistMode,
			MpdHost:    c.url,
		}
		if err := writeMsg(config); err != nil {
			log.Printf("writeMsg: %s", err)
			return
		}

		go func(ctx context.Context, conn *websocket.Conn) {
			tick := time.NewTicker(55 * time.Second)
			defer tick.Stop()
			for {
				select {
				case <-tick.C:
					if err := conn.WriteControl(
						websocket.PingMessage,
						nil,
						time.Now().Add(5*time.Second),
					); err != nil {
						return
					}
				case <-ctx.Done():
					return
				}
			}
		}(r.Context(), conn)

		go func() {
			for {
				func() {
					ctx, cancel := context.WithCancel(r.Context())
					defer cancel()
					w := c.Watch(ctx)
					for msg := range w {
						if err := writeMsg(msg); err != nil {
							log.Printf("writeMsg: %s", err)
							go func() {
								for range w {
								}
							}()
							return
						}
					}
				}()
				select {
				case <-r.Context().Done():
					return
				default:
					log.Printf("lost connection to MPD")
					time.Sleep(5 * time.Second)
				}
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
					var tag Tag
					if err := dec.Decode(&tag); err != nil {
						if err != io.EOF {
							log.Printf("decode err: %s", err)
						}
						break
					}
					cmd, err := parseCmd(tag)
					if err != nil {
						log.Printf("parseCmd: %s", err)
						continue
					}

					msg, err := handle(c, cmd)
					if err != nil {
						log.Printf("handle: %s", err)
						continue
					}
					if msg == nil {
						continue
					}
					if err := writeMsg(msg); err != nil {
						log.Printf("write response: %s", err)
					}
				}
			default:
				log.Printf("got a %d. Ignored", t)
			}
		}
	}
}

type WSConfig struct {
	ArtistMode ArtistMode `json:"artistmode"`
	MpdHost    string     `json:"mpdhost"`
}

func (w WSConfig) Type() string { return "config" }

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

type CmdLoadDir struct {
	ID   string `json:"id"`
	File string `json:"file"`
}
type CmdAdd struct {
	ID string `json:"id"`
}
type CmdList struct {
	ID     string `json:"id"`
	What   string `json:"what"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
}
type CmdFindAdd struct {
	Artist string `json:"artist"`
	Album  string `json:"album"`
	Track  string `json:"track"`
}
type CmdPlayID struct {
	ID string `json:"id"`
}
type CmdTrack struct {
	ID   string `json:"id"`
	File string `json:"file"`
}
type CmdSeek struct {
	Song    string  `json:"song"`
	Seconds float64 `json:"seconds"`
}
type CmdVolume struct {
	Volume float64 `json:"volume"`
}
type CmdPlay struct{}
type CmdStop struct{}
type CmdNext struct{}
type CmdPrevious struct{}
type CmdClear struct{}
type CmdPause struct{}
type CmdUnpause struct{}

func parseCmd(t Tag) (interface{}, error) {
	switch t.Name {
	case "loaddir":
		var c CmdLoadDir
		return &c, json.Unmarshal(t.Value, &c)
	case "add":
		var c CmdAdd
		return &c, json.Unmarshal(t.Value, &c)
	case "playid":
		var c CmdPlayID
		return &c, json.Unmarshal(t.Value, &c)
	case "track":
		var c CmdTrack
		return &c, json.Unmarshal(t.Value, &c)
	case "seek":
		var c CmdSeek
		return &c, json.Unmarshal(t.Value, &c)
	case "volume":
		var c CmdVolume
		return &c, json.Unmarshal(t.Value, &c)
	case "list":
		var c CmdList
		return &c, json.Unmarshal(t.Value, &c)
	case "findadd":
		var c CmdFindAdd
		return &c, json.Unmarshal(t.Value, &c)
	case "play":
		var c CmdPlay
		return &c, json.Unmarshal(t.Value, &c)
	case "stop":
		var c CmdStop
		return &c, json.Unmarshal(t.Value, &c)
	case "next":
		var c CmdNext
		return &c, json.Unmarshal(t.Value, &c)
	case "previous":
		var c CmdPrevious
		return &c, json.Unmarshal(t.Value, &c)
	case "clear":
		var c CmdClear
		return &c, json.Unmarshal(t.Value, &c)
	case "pause":
		var c CmdPause
		return &c, json.Unmarshal(t.Value, &c)
	case "unpause":
		var c CmdUnpause
		return &c, json.Unmarshal(t.Value, &c)
	default:
		return nil, errors.New("unknown tag")
	}
}

func handle(c *MPD, cmd interface{}) (WSMsg, error) {
	// log.Printf("handle %#v", cmd)

	switch args := cmd.(type) {
	case *CmdLoadDir:
		ins, err := c.LSInfo(args.File)
		if err != nil {
			return nil, err
		}
		return WSInodes{
			ID:     args.ID,
			Inodes: ins,
		}, nil
	case *CmdAdd:
		return nil, c.PlaylistAdd(args.ID)
	case *CmdList:
		var (
			ls  []DBEntry
			err error
		)
		switch args.What {
		case "artists":
			ls, err = c.Artists(c.artistMode)
		case "artistalbums":
			ls, err = c.ArtistAlbums(c.artistMode, args.Artist)
		case "araltracks":
			ls, err = c.ArtistAlbumTracks(c.artistMode, args.Artist, args.Album)
		default:
			err = fmt.Errorf("unknown what: %q", args.What)
		}
		if err != nil {
			return nil, err
		}
		return WSList{
			ID:   args.ID,
			List: ls,
		}, nil
	case *CmdFindAdd:
		p := "findadd"
		if a := args.Artist; a != "" {
			cmd := "artist"
			if c.artistMode == ModeAlbumartist {
				cmd = "albumartist"
			}
			if a := args.Artist; a != "" {
				p = fmt.Sprintf("%s %s %q", p, cmd, a)
			}
		}
		if a := args.Album; a != "" {
			p = fmt.Sprintf("%s album %q", p, a)
		}
		if t := args.Track; t != "" {
			p = fmt.Sprintf("%s title %q", p, t)
		}
		return nil, c.Write(p)
	case *CmdPlayID:
		return nil, c.Write(fmt.Sprintf("playid %q", args.ID))
	case *CmdTrack:
		ls, err := c.search(fmt.Sprintf("file %q", args.File))
		if err != nil {
			return nil, err
		}

		if len(ls) == 0 {
			return nil, nil
		}
		return WSTrack{
			ID:    args.ID,
			Track: ls[0],
		}, nil
	case *CmdSeek:
		return nil, c.Write(fmt.Sprintf("seekid %s %d", args.Song, int(args.Seconds)))
	case *CmdVolume:
		if v := args.Volume; v >= 0 && v <= 100 {
			return nil, c.Write(fmt.Sprintf("setvol %d", int(v)))
		}
		return nil, nil
	case *CmdPlay:
		return nil, c.Write("play")
	case *CmdStop:
		return nil, c.Write("stop")
	case *CmdNext:
		return nil, c.Write("next")
	case *CmdPrevious:
		return nil, c.Write("previous")
	case *CmdClear:
		// won't be a playlist update event when it's still playing (MPD
		// 0.20.14)
		if err := c.Write("stop"); err != nil {
			return nil, err
		}
		return nil, c.Write("clear")
	case *CmdPause:
		return nil, c.Write("pause 1")
	case *CmdUnpause:
		return nil, c.Write("pause 0")
	default:
		return nil, fmt.Errorf("unknown command type: %T", cmd)
	}
}
