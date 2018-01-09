package main

import (
	"bufio"
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
	r, err := c.r.ReadString('\n')
	if err != nil {
		c.Close()
		return err
	}
	line := r[:len(r)-1]
	log.Printf("res: %q", line)
	if strings.HasPrefix(line, "ACK") {
		return errors.New(line)
	}
	return nil
}
