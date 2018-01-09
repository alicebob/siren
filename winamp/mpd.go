package main

import (
	"bufio"
	"context"
	"errors"
	"log"
	"net"
	"strings"
)

type MPD struct {
	url string
}

type conn struct {
	c net.Conn
	r *bufio.Reader
}

func NewMPD(url string) (*MPD, error) {
	m := &MPD{
		url: url,
	}
	return m, nil
}

// watch events, returns a channel. Stays open until there is a connection
// error, or ctx closes.
func (m *MPD) Watch(ctx context.Context) Watch {
	return goWatch(ctx, m.url)
}

func (m *MPD) connect() (*conn, error) {
	return newConn(m.url)
}

// Write simple command
func (m *MPD) Write(cmd string) error {
	c, err := m.connect()
	if err != nil {
		return err
	}
	defer c.Close()

	if err := c.write(cmd); err != nil {
		return err
	}
	return c.readOK()
}

func newConn(url string) (*conn, error) {
	c, err := net.Dial("tcp", url)
	if err != nil {
		return nil, err
	}
	cn := &conn{
		c: c,
		r: bufio.NewReader(c),
	}
	return cn, cn.readOK()
}

func (c *conn) Close() error {
	return c.c.Close()
}

func (c *conn) write(cmd string) error {
	// TODO: timeouts
	payload := cmd + "\n"
	for len(payload) > 0 {
		n, err := c.c.Write([]byte(payload))
		if err != nil {
			c.Close()
			return err
		}
		payload = payload[n:]
	}
	return nil
}

func (c *conn) readOK() error {
	return readOK(c.r)
}

func (c *conn) readKV() ([][2]string, error) {
	return readKV(c.r)
}

func (c *conn) readKVmap() (map[string]string, error) {
	kv, err := readKV(c.r)
	if err != nil {
		return nil, err
	}
	r := map[string]string{}
	for _, v := range kv {
		r[v[0]] = v[1]
	}
	return r, nil
}

func readOK(r *bufio.Reader) error {
	s, err := r.ReadString('\n')
	if err != nil {
		return err
	}
	line := s[:len(s)-1]
	log.Printf("res: %q", line)
	switch {
	case line == "OK" || strings.HasPrefix(line, "OK "):
		return nil
	case line == "ACK" || strings.HasPrefix(line, "ACK "):
		return errors.New(line)
	default:
		return errors.New("unexpected answer")
	}
}

func readKV(r *bufio.Reader) ([][2]string, error) {
	var kv [][2]string
	for {
		s, err := r.ReadString('\n')
		if err != nil {
			return kv, err
		}
		line := s[:len(s)-1]
		switch {
		case line == "OK" || strings.HasPrefix(line, "OK "):
			return kv, nil
		case line == "ACK" || strings.HasPrefix(line, "ACK "):
			return kv, errors.New(line)
		default:
			fs := strings.SplitN(line, ": ", 2)
			if len(fs) != 2 {
				return kv, errors.New("unexpected line")
			}
			kv = append(kv, [...]string{fs[0], fs[1]})
		}
	}
}
