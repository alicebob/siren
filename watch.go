package main

import (
	"context"
	"fmt"
	"log"
	"path"
	"strconv"
	"strings"
)

type Connection bool

func (Connection) Type() string { return "connection" }

type Status struct {
	State    string  `json:"state"`
	SongID   string  `json:"songid"`
	Elapsed  float64 `json:"elapsed"`
	Duration float64 `json:"duration"`
	Volume   float64 `json:"volume"`
}

func (Status) Type() string { return "status" }

type PlaylistTrack struct {
	ID    string `json:"id"`
	Pos   int    `json:"pos"`
	Track Track  `json:"track"`
}

type Playlist []PlaylistTrack

func (Playlist) Type() string { return "playlist" }

type Database struct{}

func (Database) Type() string { return "database" }

type DBEntry struct {
	Type   string `json:"type"`
	Artist string `json:"artist,omitempty"`
	Album  string `json:"album,omitempty"`
	Track  *Track `json:"track,omitempty"`
}

/*
type DBArtist struct {
	Artist string `json:"artist"`
}

type DBAlbum struct {
	Artist string `json:"artist"`
	Album  string `json:"album"`
}

func (e DBEntry) MarshalJSON() ([]byte, error) {
	var payload interface{}
	switch e.Type {
	case "artist":
		payload = DBArtist{
			Artist: e.Artist,
		}
	case "album":
		payload = DBAlbum{
			Artist: e.Artist,
			Album:  e.Album,
		}
	case "track":
		payload = e.Track
	default:
		return nil, fmt.Errorf("unknown entry type: %s", e.Type)
	}

	value, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	return json.Marshal(Tag{
		Name:  "siren/entry." + e.Type,
		Value: value,
	})
}
*/

type Watch chan WSMsg

func goWatch(ctx context.Context, url string) Watch {
	var w Watch = make(chan WSMsg)
	go func() {
		if err := w.run(ctx, url); err != nil {
			log.Printf("watch: %s", err)
		}
	}()
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
	if err := w.playlist(c); err != nil {
		return fmt.Errorf("playlist: %s", err)
	}
	if err := w.status(c); err != nil {
		return fmt.Errorf("player: %s", err)
	}

	for {
		if err := c.write("idle player playlist update database mixer"); err != nil {
			return err
		}

		kv, err := c.readKVmap()
		if err != nil {
			return err
		}
		switch s := kv["changed"]; s {
		case "player", "mixer":
			if err := w.status(c); err != nil {
				return fmt.Errorf("player: %s", err)
			}
		case "playlist":
			if err := w.playlist(c); err != nil {
				return fmt.Errorf("playlist: %s", err)
			}
		case "database", "update":
			if err := w.database(c); err != nil {
				return fmt.Errorf("database: %s", err)
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
		// MPD 0.16 fallback
		if time, ok := kv["time"]; ok {
			parts := strings.Split(time, ":")
			if len(parts) != 2 {
				return Status{}, fmt.Errorf("invalid time field: %s", kv["time"])
			}
			duration = parts[1]
		}
	}
	toFloat := func(s string) float64 {
		f, _ := strconv.ParseFloat(s, 64)
		return f
	}
	return Status{
		State:    kv["state"],
		SongID:   kv["songid"],
		Elapsed:  toFloat(kv["elapsed"]),
		Duration: toFloat(duration),
		Volume:   toFloat(kv["volume"]),
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
		case "AlbumArtist":
			t.Track.AlbumArtist = v[1]
		case "Title":
			t.Track.Title = v[1]
		case "Album":
			t.Track.Album = v[1]
		case "Track":
			t.Track.Track = v[1]
		case "duration":
			t.Track.Duration, _ = strconv.ParseFloat(v[1], 64)
		case "Time":
			// legacy, newer mpds have the `duration` field
			if t.Track.Duration == 0.0 {
				t.Track.Duration, _ = strconv.ParseFloat(v[1], 64)
			}
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
