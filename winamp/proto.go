package main

import (
	"path"
)

type Track struct {
	ID     string `json:"id"`
	File   string `json:"file"`
	Artist string `json:"artist"`
	Title  string `json:"title"`
	Album  string `json:"album"`
}

type Inode struct {
	ID     string `json:"id"`
	File   string `json:"file,omitempty"`
	Artist string `json:"artist"`
	Title  string `json:"title"`
	Album  string `json:"album"`
	Dir    string `json:"dir,omitempty"`
}

func readInodes(kv [][2]string) []Inode {
	var (
		ts     []Inode
		in     *Inode
		finish = func() {
			if in != nil {
				ts = append(ts, *in)
			}
			in = &Inode{}
		}
	)
	for _, v := range kv {
		switch v[0] {
		case "file":
			finish()
			in.ID = v[1]
			in.File = path.Base(v[1])
		case "directory":
			finish()
			in.ID = v[1]
			in.Dir = path.Base(v[1])
		case "Artist":
			in.Artist = v[1]
		case "Title":
			in.Title = v[1]
		case "Album":
			in.Album = v[1]
		}
	}
	finish()
	return ts
}
