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
					ID:  "79",
					Pos: 0,
					Track: Track{
						ID:       "Elliott Smith - Either-Or/11 - 2-45 am.mp3",
						File:     "11 - 2-45 am.mp3",
						Artist:   "Elliott Smith",
						Title:    "2:45 am",
						Album:    "Either/Or",
						Track:    "11",
						Duration: 198.896,
					},
				},
				{
					ID:  "80",
					Pos: 1,
					Track: Track{
						ID:       "Elliott Smith - Either-Or/12 - Say Yes.mp3",
						File:     "12 - Say Yes.mp3",
						Artist:   "Elliott Smith",
						Title:    "Say Yes",
						Album:    "Either/Or",
						Track:    "12",
						Duration: 138.187,
					},
				},
			},
		},
		{
			payload: "OK\n",
			want:    Playlist{},
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

func TestStatus(t *testing.T) {
	log.SetOutput(ioutil.Discard)
	type cas struct {
		payload string
		want    Status
	}
	for n, c := range []cas{
		// 0.16
		{
			payload: `volume: 61
repeat: 0
random: 0
single: 0
consume: 0
playlist: 184
playlistlength: 14
xfade: 0
mixrampdb: 0.000000
mixrampdelay: nan
state: play
song: 1
songid: 220
time: 38:213
elapsed: 37.918
bitrate: 256
audio: 44100:24:2
nextsong: 2
OK
`,
			want: Status{
				State:    "play",
				SongID:   "220",
				Elapsed:  37.918,
				Duration: 213,
				Volume:   61,
			},
		},

		// 0.20
		{
			payload: `volume: 30
repeat: 0
random: 0
single: 0
consume: 0
playlist: 190
playlistlength: 1
mixrampdb: 0.000000
state: play
song: 0
songid: 505
time: 11:199
elapsed: 11.342
bitrate: 320
duration: 198.896
audio: 44100:24:2
OK
`,
			want: Status{
				State:    "play",
				SongID:   "505",
				Elapsed:  11.342,
				Duration: 198.896,
				Volume:   30,
			},
		},
		// 0.20 stopped
		{
			payload: `volume: -1
repeat: 0
random: 0
single: 0
consume: 0
playlist: 206
playlistlength: 13
mixrampdb: 0.000000
state: stop
song: 5
songid: 705
nextsong: 6
nextsongid: 706
OK
`,
			want: Status{
				State:    "stop",
				SongID:   "705",
				Elapsed:  0,
				Duration: 0,
				Volume:   -1,
			},
		},
	} {
		kv, err := readKVmap(bufio.NewReader(strings.NewReader(c.payload)))
		if err != nil {
			t.Fatal(err)
		}
		s, err := readStatus(kv)
		if err != nil {
			t.Fatal(err)
		}
		if have, want := s, c.want; !reflect.DeepEqual(have, want) {
			t.Errorf("case %d: have %#v, want %#v", n, have, want)
		}
	}
}
