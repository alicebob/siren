package main

import (
	"path"
)

type Track struct {
	ID       string  `edn:"id"`
	File     string  `edn:"file"`
	Artist   string  `edn:"artist"`
	Title    string  `edn:"title"`
	Album    string  `edn:"album"`
	Track    string  `edn:"track"`
	Duration float64 `edn:"duration"`
}

type IEntry struct {
	ID    string `edn:"id"`
	Title string `edn:"title"`
}
type Inode struct {
	Dir  *IEntry `edn:"dir"`
	File *IEntry `edn:"file"`
}

func readInodes(kv [][2]string) []Inode {
	var (
		ts     []Inode
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
