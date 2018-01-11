package main

import (
	"context"
	"fmt"
	"log"
	"strings"
)

type Msg interface {
	isMsg()
	Type() string
}

type Status struct {
	State    string `json:"state"`
	SongID   string `json:"songid"`
	Elapsed  string `json:"elapsed"`
	Duration string `json:"duration"`
}

func (Status) isMsg()       {}
func (Status) Type() string { return "status" }

type Playlist []Track

func (Playlist) isMsg()       {}
func (Playlist) Type() string { return "playlist" }

type Inodes struct {
	ID     string  `json:"id"`
	Inodes []Inode `json:"inodes"`
}

func (Inodes) isMsg()       {}
func (Inodes) Type() string { return "inodes" }

type DBEntry struct {
	Type   string `json:"type"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
	Title  string `json:"title"`
}
type DBList struct {
	ID   string    `json:"id"`
	List []DBEntry `json:"list"`
}

func (DBList) isMsg()       {}
func (DBList) Type() string { return "list" }

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

	// init
	w.playlist(c)
	w.status(c)

	for {
		if err := c.write("idle player playlist"); err != nil {
			return err
		}

		kv, err := c.readKVmap()
		if err != nil {
			return err
		}
		switch s := kv["changed"]; s {
		case "player":
			if err := w.status(c); err != nil {
				log.Printf("player: %s", err)
			}
		case "playlist":
			if err := w.playlist(c); err != nil {
				log.Printf("playlist: %s", err)
			}
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
		t  *Track
	)
	for _, v := range kv {
		if v[0] == "file" {
			if t != nil {
				ts = append(ts, *t)
			}
			t = &Track{}
		}
		if t == nil {
			continue
		}
		switch v[0] {
		case "file":
			t.File = v[1]
		case "Id":
			t.ID = v[1]
		case "Artist":
			t.Artist = v[1]
		case "Title":
			t.Title = v[1]
		case "Album":
			t.Album = v[1]
		}
	}
	if t != nil {
		ts = append(ts, *t)
	}
	return ts
}
