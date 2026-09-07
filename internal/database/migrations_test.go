package database

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInitialMigrationContainsBudgetScopedForeignKeys(t *testing.T) {
	migration := readMigration(t, "000001_initial.sql")

	required := []string{
		"FOREIGN KEY (account_id, budget_id)\n        REFERENCES accounts(id, budget_id)",
		"FOREIGN KEY (transfer_account_id, budget_id)\n        REFERENCES accounts(id, budget_id)",
		"FOREIGN KEY (category_id, budget_id)\n        REFERENCES categories(id, budget_id)",
		"FOREIGN KEY (merchant_id, budget_id)\n        REFERENCES merchants(id, budget_id)",
		"CHECK (amount > 0)",
		"UNIQUE (id, budget_id)",
	}

	for _, want := range required {
		if !strings.Contains(migration, want) {
			t.Fatalf("initial migration does not contain required schema fragment:\n%s", want)
		}
	}
}

func TestInitialMigrationDefinesGooseUpAndDownSections(t *testing.T) {
	migration := readMigration(t, "000001_initial.sql")

	if strings.Count(migration, "-- +goose Up") != 1 {
		t.Fatalf("initial migration must contain exactly one goose Up section")
	}
	if strings.Count(migration, "-- +goose Down") != 1 {
		t.Fatalf("initial migration must contain exactly one goose Down section")
	}
}

func readMigration(t *testing.T, name string) string {
	t.Helper()

	path := filepath.Join("..", "..", "migrations", name)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read migration %s: %v", path, err)
	}
	return string(data)
}
