package main

import (
	"bufio"
	"errors"
	"io/ioutil"
	"log"
	"reflect"
	"strings"
	"testing"
)

func TestReadInodes(t *testing.T) {
	log.SetOutput(ioutil.Discard)
	type cas struct {
		payload string
		want    []Inode
		err     error
	}
	for n, c := range []cas{
		{
			payload: `file: 2.Foreword_2_Amanda_Palmer.flac
Last-Modified: 2018-01-10T12:39:15Z
Time: 798
duration: 797.794
Title: Foreword 2 Amanda Palmer
Artist: Amanda Palmer
AlbumArtist: Cory Doctorow
Album: Information Doesn't Want To Be Free
Genre: Audiobook
Composer: Cory Doctorow
Performer: Cory Doctorow
directory: Elliott Smith - Either-Or
Last-Modified: 2015-03-01T13:51:33Z
directory: Elliott Smith - Elliott Smith
Last-Modified: 2015-03-01T13:51:46Z
OK
`,
			want: []Inode{
				{
					File:   "2.Foreword_2_Amanda_Palmer.flac",
					Artist: "Amanda Palmer",
					Title:  "Foreword 2 Amanda Palmer",
					Album:  "Information Doesn't Want To Be Free",
				},
				{
					Dir: "Elliott Smith - Either-Or",
				},
				{
					Dir: "Elliott Smith - Elliott Smith",
				},
			},
		},
		{
			payload: "OK\n",
			want:    []Inode(nil),
		},
		{
			payload: "foo\n",
			err:     errors.New("unexpected line"),
		},
	} {
		kv, err := readKV(bufio.NewReader(strings.NewReader(c.payload)))
		if have, want := err, c.err; !reflect.DeepEqual(have, want) {
			t.Errorf("case %d: have %q, want %q", n, have, want)
			continue
		}
		if c.err != nil {
			continue
		}
		if have, want := readInodes(kv), c.want; !reflect.DeepEqual(have, want) {
			t.Errorf("case %d: have %#v, want %#v", n, have, want)
		}
	}
}
