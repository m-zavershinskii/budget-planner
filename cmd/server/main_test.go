package main

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"budget-planner/internal/config"
)

type fakePinger struct {
	err    error
	called bool
}

func (p *fakePinger) Ping(ctx context.Context) error {
	p.called = true
	if _, ok := ctx.Deadline(); !ok {
		return errors.New("missing ping deadline")
	}
	return p.err
}

func TestHealthzReturnsOKWhenDatabasePings(t *testing.T) {
	db := &fakePinger{}
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()

	newHandler(db).ServeHTTP(response, request)

	if !db.called {
		t.Fatal("database Ping was not called")
	}
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if body := response.Body.String(); body != "ok" {
		t.Fatalf("body = %q, want %q", body, "ok")
	}
	if got := response.Header().Get("Content-Type"); got != "text/plain; charset=utf-8" {
		t.Fatalf("Content-Type = %q, want %q", got, "text/plain; charset=utf-8")
	}
}

func TestHealthzReturnsUnavailableWhenDatabasePingFails(t *testing.T) {
	db := &fakePinger{err: errors.New("database down")}
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()

	newHandler(db).ServeHTTP(response, request)

	if !db.called {
		t.Fatal("database Ping was not called")
	}
	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusServiceUnavailable)
	}
	if body := response.Body.String(); !strings.Contains(body, "database unavailable") {
		t.Fatalf("body = %q, want it to contain %q", body, "database unavailable")
	}
}

func TestNewServerUsesConfiguredAddressAndTimeouts(t *testing.T) {
	server := newServer(config.Config{AppAddr: ":9090"}, http.NewServeMux())

	if server.Addr != ":9090" {
		t.Fatalf("Addr = %q, want %q", server.Addr, ":9090")
	}
	if server.ReadHeaderTimeout != 5*time.Second {
		t.Fatalf("ReadHeaderTimeout = %s, want %s", server.ReadHeaderTimeout, 5*time.Second)
	}
	if server.ReadTimeout != 15*time.Second {
		t.Fatalf("ReadTimeout = %s, want %s", server.ReadTimeout, 15*time.Second)
	}
	if server.WriteTimeout != 15*time.Second {
		t.Fatalf("WriteTimeout = %s, want %s", server.WriteTimeout, 15*time.Second)
	}
	if server.IdleTimeout != 60*time.Second {
		t.Fatalf("IdleTimeout = %s, want %s", server.IdleTimeout, 60*time.Second)
	}
}
