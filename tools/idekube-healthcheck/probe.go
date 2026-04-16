package main

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

const probeTimeout = 1 * time.Second

// Prober checks whether a service is healthy.
type Prober interface {
	Probe(svc ServiceConfig) bool
}

// HTTPProber probes a service via an HTTP GET through the nginx reverse proxy on port 80.
type HTTPProber struct{}

func (p *HTTPProber) Probe(svc ServiceConfig) bool {
	client := &http.Client{Timeout: probeTimeout}
	probePath := svc.ProbePath
	if probePath == "" {
		probePath = "/"
	}
	url := fmt.Sprintf("http://127.0.0.1:%d%s", svc.Port, probePath)
	resp, err := client.Get(url)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode >= 200 && resp.StatusCode < 400
}

// WebSocketProber probes a service by attempting a WebSocket handshake
// through the nginx reverse proxy on port 80.
type WebSocketProber struct{}

func (p *WebSocketProber) Probe(svc ServiceConfig) bool {
	dialer := websocket.Dialer{
		HandshakeTimeout: probeTimeout,
	}
	probePath := svc.ProbePath
	if probePath == "" {
		probePath = "/"
	}
	url := fmt.Sprintf("ws://127.0.0.1:%d%s", svc.Port, probePath)
	conn, _, err := dialer.Dial(url, nil)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

// FallbackProber tries each prober in order, returning true on the first success.
type FallbackProber struct {
	Probers []Prober
}

func (p *FallbackProber) Probe(svc ServiceConfig) bool {
	for _, prober := range p.Probers {
		if prober.Probe(svc) {
			return true
		}
	}
	return false
}

// DefaultProber returns a FallbackProber that tries HTTP first, then WebSocket.
func DefaultProber() Prober {
	return &FallbackProber{
		Probers: []Prober{
			&HTTPProber{},
			&WebSocketProber{},
		},
	}
}
