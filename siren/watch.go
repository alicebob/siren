package main

import (
	"context"
	"fmt"
	"log"
	"path"
	"strconv"
	"strings"
)

type Msg interface {
	isMsg()
	Type() string
}

type Connection bool

func (Connection) isMsg()       {}
func (Connection) Type() string { return "connection" }

type Status struct {
	State    string `json:"state"`
	SongID   string `json:"songid"`
	Elapsed  string `json:"elapsed"`
	Duration string `json:"duration"`
	Volume   string `json:"volume"`
}

func (Status) isMsg()       {}
func (Status) Type() string { return "status" }

type PlaylistTrack struct {
	ID    string `json:"id"`
	Pos   int    `json:"pos"`
	Track Track  `json:"track"`
}

type Playlist []PlaylistTrack

func (Playlist) isMsg()       {}
func (Playlist) Type() string { return "playlist" }

type Database struct{}

func (Database) isMsg()       {}
func (Database) Type() string { return "database" }

type DBEntry struct {
	Type   string `json:"type"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
	ID     string `json:"id"`
	Title  string `json:"title"`
	Track  string `json:"track"`
}

type Watch chan Msg

func goWatch(ctx context.Context, url string) Watch {
	var w Watch = make(chan Msg)
	go w.run(ctx, url)
	return w
}

func (w Watch) run(ctx context.Context, url string) error {
	defer close(w)
	c, err := newConn(url)
	if err != nil {
		return err
	}
	defer c.Close()

	go func() {
		<-ctx.Done()
		c.Close()
	}()

	w <- Connection(true)
	defer func() {
		w <- Connection(false)
	}()
	// init
	w.playlist(c)
	w.status(c)

	for {
		if err := c.write("idle player playlist database mixer"); err != nil {
			return err
		}

		kv, err := c.readKVmap()
		if err != nil {
			return err
		}
		switch s := kv["changed"]; s {
		case "player", "mixer":
			if err := w.status(c); err != nil {
				log.Printf("player: %s", err)
			}
		case "playlist":
			if err := w.playlist(c); err != nil {
				log.Printf("playlist: %s", err)
			}
		case "database":
			w.database(c)
		default:
			log.Printf("unknown idle subsystem: %q", s)
		}
	}
}

func (w Watch) status(c *conn) error {
	if err := c.write("status"); err != nil {
		return err
	}
	kv, err := c.readKVmap()
	if err != nil {
		return err
	}
	if s, err := readStatus(kv); err != nil {
		return err
	} else {
		w <- s
	}
	return nil
}

func readStatus(kv map[string]string) (Status, error) {
	duration, ok := kv["duration"]
	if !ok {
		// 0.16 fallback
		if time, ok := kv["time"]; ok {
			parts := strings.Split(time, ":")
			if len(parts) != 2 {
				return Status{}, fmt.Errorf("invalid time field: %s", kv["time"])
			}
			duration = parts[1]
		}
	}
	return Status{
		State:    kv["state"],
		SongID:   kv["songid"],
		Elapsed:  kv["elapsed"],
		Duration: duration,
		Volume:   kv["volume"],
	}, nil
}

func (w Watch) playlist(c *conn) error {
	if err := c.write("playlistinfo"); err != nil {
		return err
	}
	kv, err := c.readKV()
	if err != nil {
		return err
	}
	w <- readPlaylist(kv)
	return nil
}

func readPlaylist(kv [][2]string) Playlist {
	var (
		ts = make(Playlist, 0)
		t  *PlaylistTrack
	)
	for _, v := range kv {
		if v[0] == "file" {
			if t != nil {
				ts = append(ts, *t)
			}
			t = &PlaylistTrack{}
		}
		if t == nil {
			continue
		}
		switch v[0] {
		case "file":
			t.Track.ID = v[1]
			t.Track.File = path.Base(v[1])
		case "Id":
			t.ID = v[1]
		case "Pos":
			t.Pos, _ = strconv.Atoi(v[1])
		case "Artist":
			t.Track.Artist = v[1]
		case "Title":
			t.Track.Title = v[1]
		case "Album":
			t.Track.Album = v[1]
		case "Track":
			t.Track.Track = v[1]
		case "duration":
			t.Track.Duration = v[1]
		}
	}
	if t != nil {
		ts = append(ts, *t)
	}
	return ts
}

func (w Watch) database(c *conn) error {
	w <- Database{}
	return nil
}
