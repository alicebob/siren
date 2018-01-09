package main

import (
	"context"
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

type Watch chan Msg

func goWatch(ctx context.Context, url string) Watch {
	var w Watch = make(chan Msg)
	go w.run(ctx, url)
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
			if err := w.status(c); err != nil {
				log.Printf("player: %s", err)
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
	kv, err := c.readKV()
	if err != nil {
		return err
	}
	w <- Status{
		State:   kv["state"],
		SongID:  kv["songid"],
		Time:    kv["time"],
		Elapsed: kv["elapsed"],
	}
	return nil
}
