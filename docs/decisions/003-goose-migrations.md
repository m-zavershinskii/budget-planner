# ADR-003: Goose for database migrations

- Status: Accepted
- Date: 2026-09-07
- Supersedes: previous temporary Flyway direction

## Context

Migration tooling was initially discussed with Goose, temporarily changed to Flyway, and then explicitly changed back by the user.

The current repository infrastructure builds a dedicated Goose migration container.

## Decision

Use Pressly Goose for PostgreSQL schema migrations.

Current migration tooling:
- Goose default version: `v3.28.0`;
- migration container built from `Dockerfile.goose`;
- base image: `alpine:3.24`;
- Compose service: `migrate`;
- Compose profile: `tools`;
- migrations mounted at `/migrations`;
- `GOOSE_DRIVER=postgres`;
- database connection targets the Compose `postgres` service.

Do not replace Goose with Flyway unless explicitly requested later.

## Consequences

Schema changes are represented as Goose migrations and must remain reproducible against an empty database.

Any documentation or generated code that still references Flyway is obsolete and must be corrected when encountered.
