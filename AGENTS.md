# AGENTS.md — Budget Planner

This file is the long-lived implementation contract for Codex and other coding agents working on Budget Planner.

## Agent workflow

Before making changes:

1. Read this file.
2. Read `ROADMAP.md`.
3. Read relevant ADRs under `docs/decisions/`.
4. Inspect the existing implementation before proposing replacements.
5. Treat the repository code and migrations as the source of truth when they are newer than this document.

While working:

- Work on the current roadmap milestone unless the user explicitly changes priority.
- Prefer small, reviewable vertical slices.
- Do not silently change product requirements, architecture, database semantics, authentication rules, or infrastructure.
- If a requested implementation conflicts with an ADR or this file, follow the user's newest explicit decision and update the documentation.
- Do not mark roadmap work complete merely because code was generated. Verify it as far as the environment permits.

After completing work:

- Update `ROADMAP.md`.
- Update this file if a durable product/architecture rule changed.
- Add or supersede an ADR when an important architectural decision changes.
- Update README/developer commands when operational behavior changes.
- Never leave documentation claiming an obsolete stack choice.

## Product

Budget Planner is a private, invite-only web application for personal and shared budget planning.

Core capabilities:

- income, expenses and transfers;
- monthly planning by category;
- plan-vs-actual reporting;
- multiple financial accounts;
- configurable categories;
- configurable merchants/transaction counterparties;
- desktop and mobile web UI;
- shared budgets with access levels;
- administrative user access management.

Deployment should remain simple: one Go application plus PostgreSQL. The Go application should ultimately be distributable as a single binary with web assets embedded where practical.

## Architecture

Use a modular monolith.

Do not introduce microservices, Kafka, Redis, GraphQL, or a separate frontend runtime without a concrete requirement.

Preferred application stack:

- Go
- PostgreSQL
- `pgx/v5`
- `sqlc`
- Goose migrations
- `log/slog`
- standard Go HTTP facilities unless a small router clearly improves the implementation
- server-rendered responsive HTML
- HTMX/minimal JavaScript is preferred when interactivity is needed
- Go `embed` for production web assets when the UI is introduced

Keep domain code under `internal/`.

Do not create a generic `utils` dumping ground.

Prefer clear boundaries between:
- HTTP handlers;
- services/use cases;
- persistence/database queries.

Do not create interfaces mechanically. Add them at meaningful boundaries where they improve isolation or testing.

## Current infrastructure source of truth

### PostgreSQL

Docker Compose currently uses:

- image: `postgres:18.6-alpine`
- container: `budget-postgres`
- database: `budget`
- user: `budget`
- password: `budget` for local development
- host port: `5432`
- volume: `budget_pg:/var/lib/postgresql`

Health check:

```yaml
test: ["CMD-SHELL", "pg_isready -U budget -d budget"]
interval: 5s
timeout: 5s
retries: 10
```

Do not revert the PostgreSQL image/version or volume path to an older generated configuration unless explicitly requested.

### Database migrations

The migration system is Goose, not Flyway.

Docker Compose has a tools-profile service named `migrate`.

Current migration container contract:

```yaml
migrate:
  build:
    context: .
    dockerfile: Dockerfile.goose
    args:
      GOOSE_VERSION: ${GOOSE_VERSION:-v3.28.0}
  depends_on:
    postgres:
      condition: service_healthy
  environment:
    GOOSE_DRIVER: postgres
    GOOSE_DBSTRING: postgres://budget:budget@postgres:5432/budget?sslmode=disable
    GOOSE_MIGRATION_DIR: /migrations
  volumes:
    - ./migrations:/migrations
  profiles:
    - tools
```

`Dockerfile.goose` currently uses:

- `alpine:3.24`
- Goose default version `v3.28.0`
- release binary downloaded from Pressly Goose GitHub releases
- `/usr/local/bin/goose`
- `WORKDIR /migrations`
- `ENTRYPOINT ["goose"]`

Preserve the user's actual `Dockerfile.goose` implementation when editing the repository.

Migration rules:

- use Goose SQL migrations;
- do not replace Goose with Flyway unless explicitly requested;
- migrations already applied/shared should be treated as immutable;
- schema changes get new migrations;
- keep migration state reproducible from an empty PostgreSQL database;
- important invariants belong in PostgreSQL as well as application validation.

## Authentication and registration

There is no public registration.

Users can register only after an administrator creates an invitation for a specific email address.

Intended flow:

1. Administrator creates an invitation for an email.
2. Generate a cryptographically random one-time invitation token.
3. Store only a secure hash of the token.
4. Invitation has an expiry and can be revoked.
5. User follows the invite link.
6. User authenticates with Google OAuth 2.0 / OpenID Connect.
7. Require a verified Google email.
8. Google email must match the invitation email case-insensitively.
9. Create/activate the user atomically with consuming the invitation.
10. Reject expired, revoked, used, invalid, or mismatched invitations.

Do not create a generic Google signup route that bypasses invitations.

Invitation email delivery is not decided yet. Initially the admin UI may generate a copyable invite URL.

### Sessions

Sessions must use secure server-side authentication semantics.

Requirements:

- HttpOnly cookie;
- SameSite protection;
- Secure cookie in production;
- OAuth state validation;
- do not expose OAuth tokens in browser-readable storage;
- session revocation/logout support;
- authorization is always checked server-side.

Exact session persistence design is intentionally not finalized until the auth milestone is implemented.

### First administrator

Bootstrap mechanism is not finalized.

Likely options:
- `INITIAL_ADMIN_EMAIL`;
- explicit bootstrap CLI/command.

Do not create an unauthenticated public admin-bootstrap HTTP endpoint.

## Authorization

Global application authorization and per-budget authorization are separate.

Initial global roles:
- `admin`
- `user`

Current permissions:
- `users.manage`
- `budgets.manage`
- `transactions.manage`
- `categories.manage`
- `merchants.manage`

Per-budget membership:
- `owner`
- `editor`
- `viewer`

Never rely on frontend hiding for authorization.

Every budget-scoped read/write must verify that the authenticated user can access that budget.

## Domain model

### User

Registered user authenticated through Google after invitation validation.

Current conceptual fields:
- `id`
- `email`
- `google_id`
- `name`
- `avatar_url`
- `is_active`
- timestamps

### Invite

Admin-issued registration authorization.

Fields include:
- `id`
- `email`
- `token_hash`
- `created_by`
- `expires_at`
- `used_at`
- `revoked_at`
- `created_at`

### Budget

Logical budget/workspace with a base currency.

A user may eventually participate in multiple budgets, such as Personal, Family, Vacation or Renovation.

### BudgetMember

Links a user to a budget with:
- `owner`
- `editor`
- `viewer`

### Account

Money-holding account within a budget.

Examples:
- cash;
- N26;
- Revolut;
- Sparkasse;
- credit card.

Current account types:
- `cash`
- `bank`
- `credit_card`
- `savings`
- `other`

### Category

Income/expense classification.

Types:
- `income`
- `expense`

Examples:
- Salary
- Groceries
- Rent
- Transport
- Cat
- Health
- Entertainment

Category and merchant are deliberately separate.

Example:

```text
Category: Groceries
Merchant: REWE
```

A single merchant can appear under different categories.

### Merchant

Configurable vendor/place/counterparty associated with a transaction.

Examples:
- REWE
- Lidl
- Amazon
- dm
- Deutsche Bahn
- Shell
- Netflix
- local pharmacy
- clinic
- landlord

Current conceptual fields:
- `id`
- `budget_id`
- `name`
- `website_url`
- `icon`
- `notes`
- `archived`
- timestamps

Merchant names should be unique per budget case-insensitively.

Important UX requirement:

The transaction form has merchant autocomplete/typeahead.

As the user types:
- search existing merchants;
- show matching merchants;
- if no suitable merchant exists, offer `Create "<entered name>"`;
- creating the merchant immediately selects it in the current transaction form.

This must work efficiently on both mobile and desktop.

`merchant.website_url` and `transaction.external_url` are different:

- merchant URL = general merchant website;
- transaction URL = optional link to the specific receipt/order/invoice/booking/etc.

### Transaction

Types:
- `income`
- `expense`
- `transfer`

Fields include:
- `budget_id`
- `account_id`
- `transfer_account_id`
- `category_id`
- `merchant_id`
- `transaction_type`
- `amount`
- `currency`
- `description`
- `external_url`
- `transaction_date`
- `created_by`
- timestamps

Rules:

- `amount > 0`;
- expense/income requires a category;
- transfer requires a destination account;
- transfer does not use a category or merchant;
- source and destination accounts differ;
- merchant is optional for ordinary income/expense;
- external transaction URL is optional.

### BudgetPlan

Monthly planned amount by category.

Logical uniqueness:
- budget
- category
- year
- month

Used for plan-vs-actual analysis.

## Money

Never use floating-point types for money.

Use integer minor units:

- PostgreSQL: `BIGINT`
- Go: `int64`

For EUR:
- €1.00 => 100
- €12.50 => 1250
- €1349.99 => 134999

Currency codes are three-letter codes such as `EUR`, `USD`, `RUB`.

Do not silently implement FX conversion. Exchange-rate behavior is not designed yet.

## Database integrity

Important cross-budget invariant:

A transaction and all referenced budget-owned entities must belong to the same budget.

It must not be possible to attach:
- Account from Budget A to Transaction in Budget B;
- Category from Budget A to Transaction in Budget B;
- Merchant from Budget A to Transaction in Budget B;
- transfer destination from another budget.

Do not trust IDs supplied by the browser.

Enforce these rules using appropriate database constraints and/or transaction-safe server-side validation before the transaction module is considered production-ready.

Use PostgreSQL transactions for multi-step atomic operations, including invite consumption + user creation.

## UI direction

One responsive web application, not separate desktop/mobile applications.

Expected primary areas:
- Dashboard
- Transactions
- Budget/Plan
- Accounts
- Categories
- Merchants
- Reports
- Admin

Mobile transaction entry is a priority. Avoid workflows that require excessive taps.

Exact CSS framework and visual design system are not finalized.

## Repository direction

Target structure:

```text
cmd/server/

internal/config/
internal/database/
internal/database/db/       # sqlc generated; do not edit manually
internal/database/queries/

internal/auth/
internal/user/
internal/admin/
internal/budget/
internal/account/
internal/category/
internal/merchant/
internal/transaction/
internal/dashboard/

migrations/
web/
docs/decisions/
```

## sqlc

Use explicit SQL through sqlc for the main query layer.

Rules:
- generated code is not hand-edited;
- regenerate after query/schema changes;
- scope budget-owned queries appropriately;
- prefer explicit queries over a large ORM abstraction.

## Engineering rules

Prefer:
- idiomatic Go;
- explicit error handling;
- `context.Context` propagation;
- graceful shutdown;
- `slog`;
- database constraints;
- table-driven unit tests where useful;
- PostgreSQL integration tests for persistence-sensitive behavior;
- small coherent changes.

Avoid:
- floating-point money;
- public registration;
- frontend-only authorization;
- committed credentials;
- hidden global mutable state;
- premature generic frameworks;
- replacing working infrastructure merely because an agent prefers another tool.

## Definition of done

A feature is not complete until applicable checks are satisfied:

- implementation compiles;
- `go test ./...` passes where the environment permits;
- `go vet ./...` is clean where practical;
- schema changes have Goose migrations;
- sqlc output is regenerated when necessary;
- authorization is server-side;
- budget isolation is preserved;
- errors are handled;
- secrets are not committed;
- ROADMAP is updated;
- architecture/product documentation is updated when decisions change.

## Open decisions

Do not invent these as finalized requirements:

- exact HTML templating library;
- exact CSS framework;
- exact session storage;
- invitation email provider;
- recurring transactions;
- split transactions;
- receipt attachments;
- bank import/open banking;
- FX conversion;
- tags;
- external merchant-logo service;
- localization;
- final reporting/chart set.
