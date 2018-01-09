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
		want    map[string]string
		err     error
	}
	for n, c := range []cas{
		{
			payload: "OK\n",
			want:    map[string]string{},
		},
		{
			payload: "foo: bar\nOK MPD1.3\n",
			want:    map[string]string{"foo": "bar"},
		},
		{
			payload: "foo: bar\nbar: baz\nOK\n",
			want:    map[string]string{"foo": "bar", "bar": "baz"},
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
