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
	c   net.Conn
	r   *bufio.Reader
}

func NewMPD(url string) (*MPD, error) {
	return &MPD{
		url: url,
	}, nil
}

func (m *MPD) connect() error {
	c, err := net.Dial("tcp", m.url)
	if err != nil {
		m.r = nil
		m.reset()
		return err
	}
	m.c = c
	m.r = bufio.NewReader(c)
	return m.readOK()
}

func (m *MPD) reset() {
	if m.c != nil {
		m.c.Close()
	}
	m.c = nil
	m.r = nil
}

// Write simple command
func (m *MPD) Write(cmd string) error {
	if err := m.connect(); err != nil {
		return err
	}

	if err := m.write(cmd); err != nil {
		return err
	}
	return m.readOK()
}

func (m *MPD) write(cmd string) error {
	// TODO: timeouts
	payload := cmd + "\n"
	for len(payload) > 0 {
		n, err := m.c.Write([]byte(payload))
		if err != nil {
			m.reset()
			return err
		}
		payload = payload[n:]
	}
	return nil
}

func (m *MPD) readOK() error {
	r, err := m.r.ReadString('\n')
	if err != nil {
		m.reset()
		return err
	}
	line := r[:len(r)-1]
	log.Printf("res: %q", line)
	if strings.HasPrefix(line, "ACK") {
		return errors.New(line)
	}
	return nil
}
