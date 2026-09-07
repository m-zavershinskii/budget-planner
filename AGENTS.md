# AGENTS.md — Budget Planner

This file is the persistent project context and implementation contract for Codex/AI coding agents working in this repository.

## 1. Product

Budget Planner is a private, invite-only web application for personal and shared budget planning.

Core goals:
- Record income, expenses, and transfers.
- Plan monthly spending by category and compare plan vs actual.
- Support multiple financial accounts.
- Associate transactions with configurable merchants/places such as REWE, Lidl, Amazon, Deutsche Bahn, a landlord, clinic, etc.
- Provide useful budget and merchant analytics.
- Work well on desktop and mobile.
- Keep deployment simple: preferably one Go application binary plus PostgreSQL.

This is a modular monolith. Do not introduce microservices unless the architecture is explicitly changed later.

## 2. Current technical direction

Backend:
- Go.
- Standard `net/http` is acceptable; add a small router only if it materially improves the code.
- PostgreSQL.
- `pgx/v5` for PostgreSQL connectivity.
- `sqlc` for typed database access.
- `goose` for versioned SQL migrations; Goose CLI runs in a Docker container, not on the host.
- `log/slog` for structured logging.

Frontend direction:
- Server-rendered HTML.
- Prefer Go templates / templ + HTMX and minimal JavaScript.
- Responsive UI for desktop and mobile.
- Avoid a separate Node.js frontend runtime unless a future requirement genuinely needs it.
- Static assets/templates should ultimately be embedded with Go `embed` so production can be distributed as a single application binary.

Deployment target:
- One Go binary + PostgreSQL.
- Docker may be used for local development and optional deployment.
- Runtime configuration must come from environment variables, not committed secrets.

## 3. Authentication and registration

There is NO public registration.

A user may register only through an administrator-created invitation.

Intended flow:
1. Admin creates an invitation for a specific email address.
2. Application generates a cryptographically random one-time token.
3. Only a hash of the token is stored in PostgreSQL.
4. Invitation has an expiration time and can be revoked.
5. User follows the invitation URL.
6. User authenticates with Google OAuth 2.0 / OpenID Connect.
7. The verified Google email must match the invitation email, case-insensitively.
8. Only then is the user account created/activated.
9. Invitation is marked as used.
10. Reuse, expired invitations, revoked invitations, and mismatched emails must be rejected.

Do not implement a generic "Sign up with Google" path that bypasses invitations.

The invitation sender/delivery mechanism is not fixed yet. Do not add an email provider until requested. The admin UI may initially generate a copyable invite URL.

Sessions:
- Use secure server-side authentication semantics.
- Cookies must be HttpOnly and SameSite-protected; Secure in production.
- Do not put OAuth tokens or sensitive user data in client-readable cookies.
- OAuth `state` must be validated.
- Prefer OIDC identity claims and verified email rather than treating an arbitrary OAuth email as trusted.

Bootstrap admin:
- The first administrator mechanism is not finalized.
- Current likely approach: `INITIAL_ADMIN_EMAIL` environment variable or an explicit bootstrap command.
- Avoid creating an insecure public bootstrap endpoint.

Authorization:
- Global roles/permissions exist for application-level administration.
- Initial roles: `admin`, `user`.
- Current permission names:
  - `users.manage`
  - `budgets.manage`
  - `transactions.manage`
  - `categories.manage`
  - `merchants.manage`
- Budget membership separately controls access to an individual budget:
  - `owner`
  - `editor`
  - `viewer`
- Do not conflate global admin permissions with per-budget membership.

## 4. Domain model

### User
A registered person authenticated through Google after a valid invitation.

Important fields currently include:
- `id`
- `email`
- `google_id`
- `name`
- `avatar_url`
- `is_active`

### Invite
Admin-created registration authorization for one email.

Important fields:
- `email`
- `token_hash`
- `created_by`
- `expires_at`
- `used_at`
- `revoked_at`

### Budget
A logical budget/workspace.

A user may eventually participate in multiple budgets, for example:
- Personal
- Family
- Vacation
- Renovation

Each budget has a base currency.

### BudgetMember
Links users to budgets with one of:
- `owner`
- `editor`
- `viewer`

### Account
A money-holding account within a budget.

Examples:
- Cash
- N26
- Revolut
- Sparkasse
- Credit card

Current account types:
- `cash`
- `bank`
- `credit_card`
- `savings`
- `other`

### Category
Classification of income or expense.

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

Category and merchant are deliberately separate concepts.

Example:
- category = `Groceries`
- merchant = `REWE`

The same merchant may be used with different categories.

### Merchant
Configurable transaction counterparty/place/vendor.

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

Current fields:
- `name`
- `website_url`
- `icon`
- `notes`
- `archived`

Merchant names are unique per budget case-insensitively.

Important UX requirement:
While creating/editing a transaction, merchant selection is an autocomplete/typeahead field.
- Search existing merchants as the user types.
- If no suitable merchant exists, show an action such as `Create "REWE Center"`.
- Creating the merchant should immediately select it in the transaction form.
- This flow must be fast on mobile and desktop.

Merchant's `website_url` is NOT the same as a transaction's `external_url`.

Example:
- merchant.website_url = REWE corporate/site URL
- transaction.external_url = optional URL to the specific order, receipt, invoice, booking, etc.

### Transaction
Represents:
- `income`
- `expense`
- `transfer`

Important fields:
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

Rules:
- Amount must be positive.
- Money is stored as integer minor units (`BIGINT`), never floating point.
  - EUR 12.50 => `1250`.
- Expense/income requires a category.
- Transfer requires a destination `transfer_account_id`.
- Transfer must not use a category or merchant.
- Source and destination account must differ.
- Merchant is optional for normal income/expense transactions.
- `external_url` is optional.

### BudgetPlan
Monthly planned amount for a category.

Identity:
- budget
- category
- year
- month

Purpose:
Compare monthly planned spending/income with actual transactions.

## 5. Database invariants and security

The database is PostgreSQL and should enforce important invariants in addition to application validation.

Critical rule for future implementation:
A referenced account/category/merchant must belong to the SAME budget as the transaction.

The current initial migration does not yet fully enforce all cross-budget relationships at the database level. Before treating the transaction subsystem as production-ready, add constraints or transaction-safe application checks so it is impossible to attach:
- an account from Budget A to a transaction in Budget B;
- a category from Budget A to Budget B;
- a merchant from Budget A to Budget B;
- a transfer destination from another budget.

Do not trust IDs supplied by the browser. Every read/write must be scoped by the authenticated user's accessible budget(s).

Use database transactions for multi-step operations such as:
- consuming an invite and creating a user;
- creating related records that must succeed atomically;
- future transfer/account operations when multiple rows are involved.

Email comparisons should be normalized/case-insensitive where relevant.

Do not store plaintext invitation tokens.

## 6. Money and currency

Never use `float32` or `float64` for monetary values.

Current representation:
- PostgreSQL: `BIGINT`
- Go: `int64`
- Value represents the currency's minor unit.

Example for EUR:
- `€1.00` => `100`
- `€12.50` => `1250`

Current schema stores a three-letter currency code on budgets/accounts/transactions. Do not silently perform FX conversion. Multi-currency conversion/exchange-rate behavior is not designed yet.

## 7. UI direction

Desktop:
- Persistent/compact navigation is acceptable.
- Main areas expected:
  - Dashboard
  - Transactions
  - Budget/Plan
  - Categories
  - Merchants
  - Accounts
  - Reports
  - Admin (authorized users only)

Mobile:
- Responsive, touch-friendly controls.
- Transaction creation should require minimal taps.
- Merchant autocomplete + inline creation is a priority.
- Do not build a separate mobile application at this stage.

The visual design system is not finalized. Avoid hard-coding architecture around a specific CSS framework until one is selected.

## 8. Intended HTTP areas

Exact routes are not frozen, but likely areas are:

- `/healthz`
- `/auth/...`
- `/invite/...`
- `/dashboard`
- `/transactions`
- `/accounts`
- `/categories`
- `/merchants`
- `/budget`
- `/admin/users`
- `/admin/invites`

Merchant interaction will need equivalents of:
- search merchants for current budget;
- create merchant;
- select newly created merchant in transaction form.

Whether these are JSON endpoints or HTMX HTML fragment endpoints should be chosen consistently with the server-rendered UI.

## 9. Repository layout

Current/target shape:

```text
cmd/server/                 application entry point

internal/config/            environment configuration
internal/database/          pgx connection and DB infrastructure
internal/database/db/       sqlc-generated code (generated; do not hand-edit)
internal/database/queries/  SQL queries consumed by sqlc

internal/auth/              future OAuth/session/invite auth logic
internal/user/              future user domain
internal/admin/             future administration
internal/budget/            future budget domain
internal/account/           future account domain
internal/category/          future category domain
internal/merchant/          future merchant domain
internal/transaction/       future transaction domain
internal/dashboard/         future dashboard/read models

migrations/                 goose versioned SQL migrations
web/                        future templates/static assets
```

Keep domain code under `internal/`. Avoid a generic `utils` dumping ground.

For a domain package, prefer clear separation such as:
- HTTP handler
- service/use-case logic
- repository/database access

Do not force interfaces everywhere. Introduce interfaces at meaningful boundaries, especially when they improve testing or decouple infrastructure.

## 10. Migration rules

`goose` is the migration system.

- Use SQL migrations with `-- +goose Up` and `-- +goose Down` sections.
- New development migrations should be created with `make migrate-create name=<description>`; Goose generates timestamped filenames.
- Never edit a migration that has already been shared/applied; add a new migration.
- Keep `Down` migrations correct when a safe rollback is practical. If rollback would be destructive or misleading, make that risk explicit in the migration/review instead of pretending it is safe.
- Constraints and indexes are part of the schema design, not an afterthought.
- Run migrations explicitly; application startup must not silently mutate production schema.
- The Goose schema version table is authoritative for migration state.
- Developers must not need a host-installed Goose binary. Migration commands run through the Compose `migrate` service.
- Standard commands are `make migrate-up`, `make migrate-down`, `make migrate-status`, `make migrate-version`, and `make migrate-create name=<description>`.
- `make db-reset` is the preferred destructive reset for local development; it recreates PostgreSQL and reapplies all migrations.
- Pin the Goose container version; do not silently switch to `latest`.

Current initial migration:
- `migrations/000001_initial.sql`

## 11. sqlc rules

`sqlc` is the preferred database query layer.

- Write explicit SQL.
- Keep queries scoped by `budget_id` and authorization context where appropriate.
- Prefer returning only fields actually needed for a use case.
- Generated code under `internal/database/db/` must not be manually edited.
- Regenerate after changing SQL/schema.

## 12. Configuration

Current:
- `APP_ADDR`
- `DATABASE_URL`

Expected future auth configuration:
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URL`
- session/auth secret(s)
- optional `INITIAL_ADMIN_EMAIL`

Never commit real secrets or credentials.
Keep `.env.example` non-sensitive.

## 13. Engineering constraints

Prefer:
- boring, idiomatic Go;
- explicit errors;
- `context.Context` propagated into database/network calls;
- graceful HTTP shutdown;
- structured logging;
- small cohesive packages;
- table-driven unit tests where useful;
- integration tests for PostgreSQL-dependent behavior;
- database constraints for critical invariants.

Avoid:
- microservices;
- Redis/Kafka without a demonstrated requirement;
- GraphQL without a demonstrated requirement;
- large ORM abstractions;
- hidden global mutable state;
- floating-point money;
- public registration;
- authorization checks only in the frontend;
- business logic embedded directly in templates;
- premature generic frameworks.

## 14. Current implementation status

Implemented in v0.1:
- Go module.
- HTTP server.
- Graceful shutdown.
- `/healthz` endpoint that checks PostgreSQL.
- PostgreSQL Docker Compose service.
- `pgx` pool setup.
- Goose migration executed through a Docker Compose tool container.
- Initial database schema.
- `sqlc` configuration.
- Initial user lookup queries.
- Merchant search/create/get queries.
- Makefile commands.

Not implemented yet:
- Google OAuth/OIDC.
- Sessions.
- Invitation HTTP/admin flow.
- First-admin bootstrap.
- Authorization middleware.
- HTML UI.
- Budget CRUD.
- Accounts CRUD.
- Categories CRUD.
- Merchant UI.
- Transactions CRUD.
- Monthly planning UI.
- Dashboard/reports.
- Tests.

## 15. Recommended implementation sequence

Unless the user changes priorities:

1. Authentication foundation:
   - configuration for Google;
   - secure session storage;
   - Google OAuth/OIDC;
   - invite validation/consumption;
   - bootstrap first admin.
2. Admin:
   - create/list/revoke invites;
   - list/disable users;
   - assign global roles/permissions.
3. Budget:
   - create budget;
   - membership and authorization.
4. Accounts.
5. Categories.
6. Merchants:
   - CRUD;
   - autocomplete;
   - inline creation.
7. Transactions:
   - income;
   - expense;
   - transfer;
   - validation and cross-budget integrity.
8. Budget plans.
9. Dashboard and reporting.
10. UI refinement for mobile/desktop.
11. Embed templates/static assets and verify single-binary production build.

## 16. Decisions that are intentionally NOT finalized

Do not invent these as settled requirements:
- CSS framework/design system.
- `html/template` vs `templ`.
- HTMX endpoint conventions.
- exact session persistence implementation.
- email delivery provider for invitations.
- recurring transactions.
- split transactions.
- attachments/receipt uploads.
- bank import/open-banking integrations.
- exchange-rate conversion.
- tags.
- merchant logos fetched from external services.
- localization.
- exact reporting/chart set.

When one of these becomes necessary, propose the smallest coherent design before implementing it.

## 17. Definition of done for a change

Before calling a feature complete:
- `go test ./...` passes where dependencies/environment allow.
- `go vet ./...` should be clean where practical.
- SQL changes have migrations.
- `sqlc generate` is run when schema/queries change.
- authorization is checked server-side.
- invalid cross-budget IDs cannot leak or mutate another budget.
- errors are handled, not discarded without reason.
- no credentials are committed.
- README/AGENTS.md is updated when architecture or product decisions change.

When implementing with Codex, preserve these product decisions unless the user explicitly changes them.
