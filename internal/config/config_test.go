package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("APP_ADDR", "")
	t.Setenv("DATABASE_URL", "")

	cfg := Load()

	if cfg.AppAddr != ":8080" {
		t.Fatalf("AppAddr = %q, want %q", cfg.AppAddr, ":8080")
	}

	const wantDatabaseURL = "postgres://budget:budget@localhost:5432/budget?sslmode=disable"
	if cfg.DatabaseURL != wantDatabaseURL {
		t.Fatalf("DatabaseURL = %q, want %q", cfg.DatabaseURL, wantDatabaseURL)
	}
}

func TestLoadOverridesFromEnvironment(t *testing.T) {
	t.Setenv("APP_ADDR", ":9090")
	t.Setenv("DATABASE_URL", "postgres://example:example@localhost:15432/example?sslmode=disable")

	cfg := Load()

	if cfg.AppAddr != ":9090" {
		t.Fatalf("AppAddr = %q, want %q", cfg.AppAddr, ":9090")
	}

	const wantDatabaseURL = "postgres://example:example@localhost:15432/example?sslmode=disable"
	if cfg.DatabaseURL != wantDatabaseURL {
		t.Fatalf("DatabaseURL = %q, want %q", cfg.DatabaseURL, wantDatabaseURL)
	}
}
