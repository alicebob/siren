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

func TestReadOK(t *testing.T) {
	log.SetOutput(ioutil.Discard)
	type cas struct {
		payload string
		want    error
	}
	for n, c := range []cas{
		{
			payload: "OK\n",
			want:    nil,
		},
		{
			payload: "OK MPD1.3\n",
			want:    nil,
		},
		{
			payload: "ACK [2@0] {idle} Unrecognized idle event: foo\n",
			want:    errors.New("ACK [2@0] {idle} Unrecognized idle event: foo"),
		},
		{
			payload: "FOO\n",
			want:    errors.New("unexpected answer"),
		},
	} {
		have := readOK(bufio.NewReader(strings.NewReader(c.payload)))
		if want := c.want; !reflect.DeepEqual(have, want) {
			t.Errorf("case %d: have %q, want %q", n, have, want)
		}
	}
}

func TestReadKV(t *testing.T) {
	log.SetOutput(ioutil.Discard)
	type cas struct {
		payload string
		want    [][2]string
		err     error
	}
	for n, c := range []cas{
		{
			payload: "OK\n",
			want:    [][2]string(nil),
		},
		{
			payload: "foo: bar\nOK MPD1.3\n",
			want:    [][2]string{{"foo", "bar"}},
		},
		{
			payload: "foo: bar\nbar: baz\nOK\n",
			want:    [][2]string{{"foo", "bar"}, {"bar", "baz"}},
		},
		{
			payload: "ACK [2@0] {idle} Unrecognized idle event: foo\n",
			err:     errors.New("ACK [2@0] {idle} Unrecognized idle event: foo"),
		},
		{
			payload: "foo\nOK\n",
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
		if have, want := kv, c.want; !reflect.DeepEqual(have, want) {
			t.Errorf("case %d: have %q, want %q", n, have, want)
		}
	}
}

func TestReadTracks(t *testing.T) {
	kv, err := readKV(bufio.NewReader(strings.NewReader(
		`file: Elliott Smith - New Moon/09 - Pretty Mary K (other version).mp3
Last-Modified: 2015-03-01T13:52:20Z
Time: 204
duration: 203.702
Artist: Elliott Smith
AlbumArtist: Elliott Smith
Title: Pretty Mary K (other version)
Album: New Moon
Track: 9
Date: 2007
Genre: (81)
Disc: 2
file: Elliott Smith - XO/14 - I Didn't Understand.mp3
Last-Modified: 2015-03-01T13:52:57Z
Time: 138
duration: 137.564
Artist: Elliott Smith
Title: I Didn't Understand
Album: XO
Track: 14
Date: 1998
Genre: (81)
OK
`)))
	if err != nil {
		t.Fatal(err)
	}
	want := []Track{
		{
			ID:          "Elliott Smith - New Moon/09 - Pretty Mary K (other version).mp3",
			File:        "09 - Pretty Mary K (other version).mp3",
			Artist:      "Elliott Smith",
			AlbumArtist: "Elliott Smith",
			Album:       "New Moon",
			Title:       "Pretty Mary K (other version)",
			Track:       "9",
			Duration:    203.702,
		},
		{
			ID:          "Elliott Smith - XO/14 - I Didn't Understand.mp3",
			File:        "14 - I Didn't Understand.mp3",
			Artist:      "Elliott Smith",
			AlbumArtist: "",
			Album:       "XO",
			Title:       "I Didn't Understand",
			Track:       "14",
			Duration:    137.564,
		},
	}
	if have := readTracks(kv); !reflect.DeepEqual(have, want) {
		t.Errorf("have %#v, want %#v", have, want)
	}
}
