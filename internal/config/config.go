package config

import "os"

type Config struct {
	AppAddr     string
	DatabaseURL string
}

func Load() Config {
	return Config{
		AppAddr:     envOrDefault("APP_ADDR", ":8080"),
		DatabaseURL: envOrDefault("DATABASE_URL", "postgres://budget:budget@localhost:5432/budget?sslmode=disable"),
	}
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
