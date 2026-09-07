package database

import (
	"context"
	"strings"
	"testing"
)

func TestOpenRejectsInvalidDatabaseURL(t *testing.T) {
	pool, err := Open(context.Background(), "://not-a-postgres-url")
	if err == nil {
		if pool != nil {
			pool.Close()
		}
		t.Fatal("Open returned nil error for invalid database URL")
	}
	if !strings.Contains(err.Error(), "parse database config") {
		t.Fatalf("error = %q, want it to contain %q", err.Error(), "parse database config")
	}
}
