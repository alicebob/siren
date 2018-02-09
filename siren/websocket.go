package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/robx/edn"
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
			return edn.NewEncoder(w).Encode(edn.Tag{
				Tagname: "siren/" + msg.Type(),
				Value:   msg,
			})
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
				dec := edn.NewDecoder(m)
				dec.UseTagMap(&cmdTagMap)
				for {
					var cmd interface{}
					if err := dec.Decode(&cmd); err != nil {
						if err != io.EOF {
							log.Printf("edn decode err: %s", err)
						}
						break
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

type WSInodes struct {
	ID     string  `edn:"id"`
	Inodes []Inode `edn:"inodes"`
}

func (w WSInodes) Type() string { return "inodes" }

type WSList struct {
	ID   string    `edn:"id"`
	List []DBEntry `edn:"list"`
}

func (w WSList) Type() string { return "list" }

type WSTrack struct {
	ID    string `edn:"id"`
	Track Track  `edn:"track"`
}

func (w WSTrack) Type() string { return "track" }

type CmdLoadDir struct {
	ID   string `edn:"id"`
	File string `edn:"file"`
}
type CmdAdd struct {
	ID string `edn:"id"`
}
type CmdList struct {
	ID     string `edn:"id"`
	What   string `edn:"what"`
	Artist string `edn:"artist"`
	Album  string `edn:"album"`
}
type CmdFindAdd struct {
	Artist string `edn:"artist"`
	Album  string `edn:"album"`
	Track  string `edn:"track"`
}
type CmdPlayID struct {
	ID string `edn:"id"`
}
type CmdTrack struct {
	ID   string `edn:"id"`
	File string `edn:"file"`
}
type CmdSeek struct {
	Song    string  `edn:"song"`
	Seconds float64 `edn:"seconds"`
}
type CmdVolume struct {
	Volume float64 `edn:"volume"`
}
type CmdPlay struct{}
type CmdStop struct{}
type CmdNext struct{}
type CmdPrevious struct{}
type CmdClear struct{}
type CmdPause struct{}
type CmdUnpause struct{}

var (
	commands = map[string]interface{}{
		"loaddir":  CmdLoadDir{},
		"add":      CmdAdd{},
		"list":     CmdList{},
		"findadd":  CmdFindAdd{},
		"playid":   CmdPlayID{},
		"track":    CmdTrack{},
		"seek":     CmdSeek{},
		"volume":   CmdVolume{},
		"play":     CmdPlay{},
		"stop":     CmdStop{},
		"next":     CmdNext{},
		"previous": CmdPrevious{},
		"clear":    CmdClear{},
		"pause":    CmdPause{},
		"unpause":  CmdUnpause{},
	}
	cmdTagMap edn.TagMap
)

func init() {
	for tag, proto := range commands {
		cmdTagMap.AddTagStruct(tag, proto)
	}
}

func handle(c *MPD, cmd interface{}) (WSMsg, error) {
	log.Printf("handle %T", cmd)
	switch args := cmd.(type) {
	case CmdLoadDir:
		ins, err := c.LSInfo(args.File)
		if err != nil {
			return nil, err
		}
		return WSInodes{
			ID:     args.ID,
			Inodes: ins,
		}, nil
	case CmdAdd:
		return nil, c.PlaylistAdd(args.ID)
	case CmdList:
		var (
			ls  []DBEntry
			err error
		)
		switch args.What {
		case "artists":
			ls, err = c.Artists()
		case "artistalbums":
			ls, err = c.ArtistAlbums(args.Artist)
		case "araltracks":
			ls, err = c.ArtistAlbumTracks(args.Artist, args.Album)
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
	case CmdFindAdd:
		p := "findadd"
		if a := args.Artist; a != "" {
			p = fmt.Sprintf("%s artist %q", p, a)
		}
		if a := args.Album; a != "" {
			p = fmt.Sprintf("%s album %q", p, a)
		}
		if t := args.Track; t != "" {
			p = fmt.Sprintf("%s title %q", p, t)
		}
		return nil, c.Write(p)
	case CmdPlayID:
		return nil, c.Write(fmt.Sprintf("playid %q", args.ID))
	case CmdTrack:
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
	case CmdSeek:
		return nil, c.Write(fmt.Sprintf("seekid %s %d", args.Song, int(args.Seconds)))
	case CmdVolume:
		if v := args.Volume; v >= 0 && v <= 100 {
			return nil, c.Write(fmt.Sprintf("setvol %d", int(v)))
		}
		return nil, nil
	case CmdPlay:
		return nil, c.Write("play")
	case CmdStop:
		return nil, c.Write("stop")
	case CmdNext:
		return nil, c.Write("next")
	case CmdPrevious:
		return nil, c.Write("previous")
	case CmdClear:
		return nil, c.Write("clear")
	case CmdPause:
		return nil, c.Write("pause 1")
	case CmdUnpause:
		return nil, c.Write("pause 0")
	case edn.Tag:
		return nil, fmt.Errorf("unknown command tag: %s", args.Tagname)
	default:
		return nil, fmt.Errorf("unknown command type: %T", cmd)
	}
}
