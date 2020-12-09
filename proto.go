package main

import (
	"path"
)

type Track struct {
	ID          string  `json:"id"`
	File        string  `json:"file"`
	Artist      string  `json:"artist"`
	AlbumArtist string  `json:"albumartist"`
	Title       string  `json:"title"`
	Album       string  `json:"album"`
	Track       string  `json:"track"`
	Duration    float64 `json:"duration"`
}

type IEntry struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}
type Inode struct {
	Dir  *IEntry `json:"dir"`
	File *IEntry `json:"file"`
}

func readInodes(kv [][2]string) []Inode {
	var (
		ts     = []Inode{}
		file   *IEntry
		dir    *IEntry
		finish = func() {
			if file != nil {
				ts = append(ts, Inode{File: file})
				file = nil
			}
			if dir != nil {
				ts = append(ts, Inode{Dir: dir})
				dir = nil
			}
		}
	)
	for _, v := range kv {
		switch v[0] {
		case "file":
			finish()
			file = &IEntry{
				ID:    v[1],
				Title: path.Base(v[1]),
			}
		case "directory":
			finish()
			dir = &IEntry{
				ID:    v[1],
				Title: path.Base(v[1]),
			}
		default:
			// ignoring all fields
		}
	}
	finish()
	return ts
}
