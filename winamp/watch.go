package main

import (
	"log"
)

type Msg interface {
	isMsg()
}

type Status struct {
	State   string `json:"state"`
	SongID  string `json:"songid"`
	Time    string `json:"time"`
	Elapsed string `json:"elapsed"`
}

func (Status) isMsg() {}

type watch struct {
	msgs chan Msg
}

func newWatch(url string) *watch {
	w := &watch{
		msgs: make(chan Msg),
	}
	go w.loop(url)
	return w
}

func (w *watch) C() chan Msg {
	return w.msgs
}

func (w *watch) loop(url string) error {
	c, err := newConn(url)
	if err != nil {
		return err
	}

	// init
	w.status(c)

	for {
		if err := c.write("idle player"); err != nil {
			return err
		}

		kv, err := c.readKV()
		if err != nil {
			return err
		}
		switch s := kv["changed"]; s {
		case "player":
			w.status(c)
		default:
			log.Printf("unknown idle subsystem: %q", s)
		}
	}
}

func (w *watch) broadcast(m Msg) error {
	w.msgs <- m
	return nil
}

func (w *watch) status(c *conn) error {
	if err := c.write("status"); err != nil {
		return err
	}
	kv, err := c.readKV()
	if err != nil {
		return err
	}
	return w.broadcast(Status{
		State:   kv["state"],
		SongID:  kv["songid"],
		Time:    kv["time"],
		Elapsed: kv["elapsed"],
	})
}
