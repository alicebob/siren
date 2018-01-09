package main

import (
	"bufio"
	"io/ioutil"
	"log"
	"reflect"
	"strings"
	"testing"
)

func TestReadTracklist(t *testing.T) {
	log.SetOutput(ioutil.Discard)
	type cas struct {
		payload string
		want    Playlist
		err     error
	}
	for n, c := range []cas{
		{
			payload: `file: Elliott Smith - Either-Or/11 - 2-45 am.mp3
Last-Modified: 2015-03-01T13:51:22Z
Artist: Elliott Smith
AlbumArtist: Elliott Smith
Title: 2:45 am
Album: Either/Or
Track: 11
Date: 1997
Genre: (81)
Time: 199
duration: 198.896
Pos: 0
Id: 79
file: Elliott Smith - Either-Or/12 - Say Yes.mp3
Last-Modified: 2015-03-01T13:51:30Z
Artist: Elliott Smith
AlbumArtist: Elliott Smith
Title: Say Yes
Album: Either/Or
Track: 12
Date: 1997
Genre: (81)
Time: 138
duration: 138.187
Pos: 1
Id: 80
OK
`,
			want: Playlist{
				{
					ID:     "79",
					File:   "Elliott Smith - Either-Or/11 - 2-45 am.mp3",
					Artist: "Elliott Smith",
					Title:  "2:45 am",
					Album:  "Either/Or",
				},
				{
					ID:     "80",
					File:   "Elliott Smith - Either-Or/12 - Say Yes.mp3",
					Artist: "Elliott Smith",
					Title:  "Say Yes",
					Album:  "Either/Or",
				},
			},
		},
		{
			payload: "OK\n",
			want:    Playlist(nil),
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
		if have, want := readPlaylist(kv), c.want; !reflect.DeepEqual(have, want) {
			t.Errorf("case %d: have %#v, want %#v", n, have, want)
		}
	}
}
