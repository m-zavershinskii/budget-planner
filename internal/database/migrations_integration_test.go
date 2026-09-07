//go:build integration

package database

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestGooseMigrationsApplyToEmptyPostgres(t *testing.T) {
	requireDocker(t)

	root := repoRoot(t)
	migrationsDir, err := filepath.Abs(filepath.Join(root, "migrations"))
	if err != nil {
		t.Fatalf("resolve migrations dir: %v", err)
	}

	suffix := fmt.Sprintf("%d", time.Now().UnixNano())
	networkName := "budget-planner-m0-" + suffix
	postgresName := "budget-planner-m0-postgres-" + suffix
	gooseImage := "budget-planner-goose-test:" + suffix

	runDocker(t, root, "network", "create", networkName)
	defer runDockerBestEffort(t, root, "network", "rm", networkName)

	runDocker(t, root,
		"build",
		"-t", gooseImage,
		"--build-arg", "GOOSE_VERSION="+envOrDefault("GOOSE_VERSION", "v3.28.0"),
		"-f", "Dockerfile.goose",
		".",
	)
	defer runDockerBestEffort(t, root, "image", "rm", gooseImage)

	runDocker(t, root,
		"run",
		"-d",
		"--rm",
		"--name", postgresName,
		"--network", networkName,
		"-e", "POSTGRES_DB=budget",
		"-e", "POSTGRES_USER=budget",
		"-e", "POSTGRES_PASSWORD=budget",
		"postgres:18.6-alpine",
	)
	defer runDockerBestEffort(t, root, "rm", "-f", postgresName)

	waitForPostgres(t, root, networkName, postgresName)

	runDocker(t, root,
		"run",
		"--rm",
		"--network", networkName,
		"-v", migrationsDir+":/migrations:ro",
		"-e", "GOOSE_DRIVER=postgres",
		"-e", "GOOSE_DBSTRING=postgres://budget:budget@"+postgresName+":5432/budget?sslmode=disable",
		"-e", "GOOSE_MIGRATION_DIR=/migrations",
		gooseImage,
		"up",
	)

	const constraintQuery = `
SELECT count(*)
FROM pg_constraint
WHERE conrelid IN ('transactions'::regclass, 'budget_plans'::regclass)
  AND contype = 'f'
  AND pg_get_constraintdef(oid) IN (
    'FOREIGN KEY (account_id, budget_id) REFERENCES accounts(id, budget_id)',
    'FOREIGN KEY (transfer_account_id, budget_id) REFERENCES accounts(id, budget_id)',
    'FOREIGN KEY (category_id, budget_id) REFERENCES categories(id, budget_id)',
    'FOREIGN KEY (merchant_id, budget_id) REFERENCES merchants(id, budget_id)'
  );
`

	output := runDocker(t, root,
		"exec",
		postgresName,
		"psql",
		"-U", "budget",
		"-d", "budget",
		"-At",
		"-c", constraintQuery,
	)

	if got := strings.TrimSpace(output); got != "5" {
		t.Fatalf("budget-scoped FK count = %q, want 5", got)
	}
}

func requireDocker(t *testing.T) {
	t.Helper()

	if _, err := exec.LookPath("docker"); err != nil {
		t.Skipf("docker not found: %v", err)
	}
	if err := exec.Command("docker", "version").Run(); err != nil {
		t.Skipf("docker is not available: %v", err)
	}
}

func repoRoot(t *testing.T) string {
	t.Helper()

	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}
	return filepath.Clean(filepath.Join(wd, "..", ".."))
}

func waitForPostgres(t *testing.T, root, networkName, containerName string) {
	t.Helper()

	deadline := time.Now().Add(30 * time.Second)
	for {
		cmd := exec.Command(
			"docker",
			"run",
			"--rm",
			"--network", networkName,
			"postgres:18.6-alpine",
			"pg_isready",
			"-h", containerName,
			"-U", "budget",
			"-d", "budget",
		)
		cmd.Dir = root
		if err := cmd.Run(); err == nil {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("postgres container %s did not become ready within 30s", containerName)
		}
		time.Sleep(500 * time.Millisecond)
	}
}

func runDocker(t *testing.T, dir string, args ...string) string {
	t.Helper()

	cmd := exec.Command("docker", args...)
	cmd.Dir = dir
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("docker %s failed: %v\n%s", strings.Join(args, " "), err, output)
	}
	return string(output)
}

func runDockerBestEffort(t *testing.T, dir string, args ...string) {
	t.Helper()

	cmd := exec.Command("docker", args...)
	cmd.Dir = dir
	_ = cmd.Run()
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
