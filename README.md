# Budget Planner v0.2

Технический фундамент приватного budget planner:

- Go HTTP server
- PostgreSQL 18.6
- `pgx/v5`
- `sqlc`
- `goose` SQL migrations
- Goose запускается только в Docker-контейнере через `Makefile`
- базовая схема users / invites / roles / budgets / accounts / categories / merchants / transactions / budget plans
- merchant search/create queries

## Требования для локальной разработки

- Go 1.25+
- Docker + Docker Compose
- `sqlc` для генерации database layer

Локальная установка `goose` не требуется.

## Быстрый запуск

### 1. Поднять PostgreSQL

```bash
make db-up
```

### 2. Применить миграции

```bash
make migrate-up
```

`make migrate-up` запускает одноразовый контейнер `migrate`. Goose не запускается через `go run` и не требуется на host-машине.

### 3. Запустить приложение

```bash
make run
```

Проверка:

```bash
curl http://localhost:8080/healthz
```

Ожидаемый ответ:

```text
ok
```

## Миграции

Версия Goose закреплена в `Makefile` и `Dockerfile.goose` (`v3.28.0` по умолчанию).

Применить все pending migrations:

```bash
make migrate-up
```

Статус:

```bash
make migrate-status
```

Текущая версия базы:

```bash
make migrate-version
```

Откатить одну миграцию:

```bash
make migrate-down
```

Создать новую timestamped SQL migration:

```bash
make migrate-create name=add_sessions
```

Файл появится в `migrations/` и должен содержать секции:

```sql
-- +goose Up

-- SQL for applying the migration

-- +goose Down

-- SQL for reverting the migration
```

Полностью пересоздать локальную БД и сразу применить миграции:

```bash
make db-reset
```

Приложение само миграции при старте не применяет.

## sqlc

Установить CLI:

```bash
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
```

Сгенерировать код:

```bash
make sqlc
```

`make sqlc` использует `sqlc` из `PATH` или `$(go env GOPATH)/bin/sqlc`.
Generated code находится в `internal/database/db/` и не редактируется вручную.

## Тесты

Быстрые тесты:

```bash
make test
```

Они покрывают конфигурацию, `/healthz`, базовую database URL validation и guard-проверки initial migration.

Интеграционный migration smoke test с Docker/PostgreSQL:

```bash
make test-integration
```

Он поднимает временный PostgreSQL container, применяет Goose migrations к пустой базе и проверяет budget-scoped foreign keys. Обычный `make test` этот Docker-сценарий не запускает.

## Основная структура

```text
cmd/server/                  application entry point
internal/config/             environment configuration
internal/database/           pgx infrastructure
internal/database/queries/   SQL queries for sqlc
internal/database/db/        sqlc-generated code
migrations/                  goose SQL migrations
Dockerfile.goose             reproducible Goose CLI container
docker-compose.yml           PostgreSQL + migration tool service
Makefile                     developer commands
AGENTS.md                    persistent context for Codex/AI agents
```

## Следующий этап

1. server-side sessions
2. invitation flow
3. Google OAuth/OIDC
4. bootstrap первого admin
5. authorization middleware
6. admin UI for invitations/users
