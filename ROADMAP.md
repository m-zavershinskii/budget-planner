# ROADMAP.md — Budget Planner

This is the active implementation plan.

Agents must read this file before starting work and update it after completing or materially changing a milestone.

Legend:

- `[x]` completed
- `[~]` in progress / partially implemented
- `[ ]` planned
- `[?]` decision required

Do not mark an item `[x]` until its acceptance criteria are actually met.

## Milestone 0 — Foundation and data model

Status: `[x]`

### Product/domain design

- [x] Choose modular monolith architecture.
- [x] Choose Go + PostgreSQL.
- [x] Define invite-only registration requirement.
- [x] Define Google authentication requirement.
- [x] Define global roles/permissions.
- [x] Define per-budget membership roles.
- [x] Define Budget model.
- [x] Define Account model.
- [x] Define income/expense Category model.
- [x] Define Merchant model.
- [x] Keep Category and Merchant as separate concepts.
- [x] Define income/expense/transfer Transaction model.
- [x] Add optional transaction-specific external URL.
- [x] Define BudgetPlan monthly planning model.
- [x] Decide money is stored as integer minor units.
- [x] Define inline Merchant creation from transaction form.

### Infrastructure

- [x] PostgreSQL Docker Compose service defined.
- [x] PostgreSQL image updated to `postgres:18.6-alpine`.
- [x] Named volume is `budget_pg`.
- [x] Migration tooling uses Goose.
- [x] Goose migration container is built using `Dockerfile.goose`.
- [x] Goose default version is `v3.28.0`.
- [x] Go server/database skeleton reconciled with the current repository.
- [x] Initial Goose schema migration added and aligned with the agreed data model, including cross-budget foreign-key integrity.
- [x] Initial sqlc user and merchant queries added against the current schema.

### Acceptance criteria before closing Milestone 0

- [x] Fresh `docker compose` PostgreSQL starts successfully.
- [x] Goose migration container successfully migrates an empty database.
- [x] Current migrations reflect the agreed schema.
- [x] `sqlc generate` succeeds against current migrations.
- [x] Go application connects to PostgreSQL.
- [x] `/healthz` succeeds with a healthy database.
- [x] `go test ./...` passes or any environment limitation is documented.

### Automated test coverage

- [x] Config defaults and environment overrides.
- [x] `/healthz` success/failure behavior.
- [x] Database URL validation.
- [x] Initial migration guard for budget-scoped foreign keys.
- [x] Docker/PostgreSQL integration test for applying Goose migrations to an empty database.

## Milestone 1 — Authentication foundation

Status: `[ ]`

Goal: establish secure authentication primitives before implementing business CRUD.

### Tasks

- [ ] Decide and document server-side session persistence.
- [ ] Add session schema migration if sessions are database-backed.
- [ ] Add Google OAuth/OIDC configuration.
- [ ] Implement OAuth state generation and validation.
- [ ] Implement Google login start endpoint.
- [ ] Implement Google callback endpoint.
- [ ] Require verified Google email.
- [ ] Implement secure session creation.
- [ ] Implement authenticated-user middleware.
- [ ] Implement logout/session revocation.
- [ ] Decide first-admin bootstrap mechanism.
- [ ] Implement first-admin bootstrap without a public bootstrap endpoint.

### Acceptance criteria

- [ ] Anonymous request cannot access authenticated routes.
- [ ] Authenticated session survives normal page navigation.
- [ ] Invalid OAuth state is rejected.
- [ ] Logout invalidates the session.
- [ ] Secure cookie attributes are correct for development/production.
- [ ] No public registration path exists.

## Milestone 2 — Invite-only registration and admin access

Status: `[ ]`

Goal: only admin-invited Google accounts can become users.

### Tasks

- [ ] Admin authorization middleware.
- [ ] Create invitation use case.
- [ ] Cryptographically secure invite token.
- [ ] Store only invite token hash.
- [ ] Invite expiration.
- [ ] Invite revocation.
- [ ] Invite listing.
- [ ] Copyable invitation URL.
- [ ] Validate invitation before Google auth.
- [ ] Preserve invitation context through OAuth flow securely.
- [ ] Compare verified Google email with invitation email.
- [ ] Atomically create user + consume invitation.
- [ ] Reject used/expired/revoked/mismatched invitations.
- [ ] Admin user list.
- [ ] Enable/disable user.
- [ ] Assign global role(s)/permissions.

### Acceptance criteria

- [ ] A non-invited Google user cannot register.
- [ ] An invite for A@example.com cannot register B@example.com.
- [ ] Invitation is single-use.
- [ ] Invitation cannot be reused after account creation.
- [ ] Only authorized admins can create/revoke invites.
- [ ] User creation and invite consumption are atomic.

## Milestone 3 — Budgets and authorization

Status: `[ ]`

### Tasks

- [ ] Budget create/read/update/archive/delete policy.
- [ ] Create owner membership when budget is created.
- [ ] Budget membership queries.
- [ ] `owner/editor/viewer` authorization rules.
- [ ] Budget switcher if user has multiple budgets.
- [ ] Ensure every budget-scoped request verifies membership.
- [ ] Tests for cross-budget access denial.

### Acceptance criteria

- [ ] User cannot access a budget without membership.
- [ ] Viewer cannot perform editor/owner writes.
- [ ] Editor permissions are enforced server-side.
- [ ] Owner-only operations are enforced server-side.

## Milestone 4 — Accounts

Status: `[ ]`

### Tasks

- [ ] Account list.
- [ ] Create account.
- [ ] Edit account.
- [ ] Archive account.
- [ ] Account types.
- [ ] Initial balance handling.
- [ ] Currency validation.
- [ ] Budget-scoped authorization.

### Acceptance criteria

- [ ] Accounts cannot leak across budgets.
- [ ] Archived account behavior is defined and tested.
- [ ] Money uses integer minor units.

## Milestone 5 — Categories

Status: `[ ]`

### Tasks

- [ ] Income category CRUD.
- [ ] Expense category CRUD.
- [ ] Archive category.
- [ ] Ordering.
- [ ] Optional icon/color.
- [ ] Case/duplicate behavior.
- [ ] Budget-scoped authorization.

### Acceptance criteria

- [ ] Income and expense category types are enforced.
- [ ] Category from another budget cannot be used.

## Milestone 6 — Merchants

Status: `[ ]`

### Tasks

- [ ] Merchant list.
- [ ] Merchant create.
- [ ] Merchant edit.
- [ ] Merchant archive.
- [ ] Case-insensitive uniqueness per budget.
- [ ] Merchant autocomplete search.
- [ ] Inline `Create "<name>"` flow.
- [ ] Newly created merchant is immediately selectable.
- [ ] Mobile-friendly merchant picker.
- [ ] Merchant website URL remains distinct from transaction external URL.

### Acceptance criteria

- [ ] Search is scoped to current budget.
- [ ] Merchant from another budget cannot be selected.
- [ ] Duplicate names are handled consistently.
- [ ] Inline creation works without leaving transaction entry flow.

## Milestone 7 — Transactions

Status: `[ ]`

This is the first major business milestone.

### Tasks

- [ ] Expense creation.
- [ ] Income creation.
- [ ] Transfer creation.
- [ ] Transaction list.
- [ ] Transaction edit.
- [ ] Transaction delete policy.
- [ ] Filters by period.
- [ ] Filters by category.
- [ ] Filters by merchant.
- [ ] Filters by account.
- [ ] Optional merchant.
- [ ] Optional transaction-specific external URL.
- [ ] Description.
- [ ] Transaction date.
- [ ] Currency behavior.
- [ ] Integrate merchant autocomplete + inline creation.

### Integrity requirements

- [ ] `amount > 0`.
- [ ] Income/expense requires category.
- [ ] Transfer requires destination account.
- [ ] Transfer has no category.
- [ ] Transfer has no merchant.
- [ ] Transfer source != destination.
- [ ] Account belongs to transaction budget.
- [ ] Destination account belongs to transaction budget.
- [ ] Category belongs to transaction budget.
- [ ] Merchant belongs to transaction budget.
- [ ] Browser-supplied IDs are never trusted without scope checks.

### Acceptance criteria

- [ ] Cross-budget references are impossible.
- [ ] Transaction operations are authorized server-side.
- [ ] Money calculations contain no floating-point arithmetic.

## Milestone 8 — Monthly budget planning

Status: `[ ]`

### Tasks

- [ ] Select year/month.
- [ ] Enter planned amount by category.
- [ ] Edit monthly plan.
- [ ] Plan totals.
- [ ] Actual totals from transactions.
- [ ] Plan vs actual.
- [ ] Remaining/overspent values.

### Acceptance criteria

- [ ] One plan value per budget/category/year/month.
- [ ] Calculations use integer minor units.
- [ ] Actuals use only transactions from the same budget and period.

## Milestone 9 — Dashboard and reporting

Status: `[ ]`

### Initial reports

- [ ] Current balance summary.
- [ ] Income for selected period.
- [ ] Expenses for selected period.
- [ ] Plan vs actual.
- [ ] Expenses by category.
- [ ] Expenses by merchant.
- [ ] Merchant total spending.
- [ ] Merchant transaction count.
- [ ] Merchant average transaction.
- [ ] Recent transactions.
- [ ] Account balances.

### Later/optional

- [?] Charts.
- [?] Period comparison.
- [?] Trend reporting.
- [?] Export.

## Milestone 10 — Responsive UI and single-binary packaging

Status: `[ ]`

### Tasks

- [ ] Finalize template technology.
- [ ] Finalize CSS approach.
- [ ] Desktop navigation.
- [ ] Mobile navigation.
- [ ] Touch-friendly transaction entry.
- [ ] Responsive tables/lists.
- [ ] Accessible forms and validation.
- [ ] Embed templates/static assets into Go binary.
- [ ] Production build.
- [ ] Production configuration documentation.

### Acceptance criteria

- [ ] Core flows usable on desktop.
- [ ] Core flows usable on mobile.
- [ ] Production app can run as one Go application binary plus PostgreSQL.
- [ ] No Node.js runtime required unless architecture is explicitly changed.

## Backlog — intentionally not scheduled

Do not implement these merely because they seem useful:

- [ ] recurring transactions
- [ ] split transactions
- [ ] receipt/image attachments
- [ ] bank CSV import
- [ ] open banking integration
- [ ] exchange-rate conversion
- [ ] tags
- [ ] merchant logo service
- [ ] localization
- [ ] notifications
- [ ] invitation email provider
- [ ] native mobile app

## Current next action

Start **Milestone 1 — Authentication foundation**.
