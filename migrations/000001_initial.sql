-- +goose Up

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT NOT NULL,
    google_id   TEXT UNIQUE,
    name        TEXT,
    avatar_url  TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX users_email_unique_ci ON users (lower(email));

CREATE TABLE roles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE permissions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE role_permissions (
    role_id       UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE invites (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT NOT NULL,
    token_hash  TEXT NOT NULL UNIQUE,
    created_by  UUID REFERENCES users(id),
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (expires_at > created_at),
    CHECK (used_at IS NULL OR revoked_at IS NULL)
);

CREATE UNIQUE INDEX invites_one_active_per_email
    ON invites (lower(email))
    WHERE used_at IS NULL AND revoked_at IS NULL;

CREATE TABLE budgets (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    currency    VARCHAR(3) NOT NULL DEFAULT 'EUR'
                CHECK (currency ~ '^[A-Z]{3}$'),
    owner_id    UUID NOT NULL REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE budget_members (
    budget_id   UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role        TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (budget_id, user_id)
);

CREATE INDEX budget_members_user_id_idx ON budget_members (user_id);

CREATE TABLE accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id       UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    account_type    TEXT NOT NULL DEFAULT 'other'
                    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'savings', 'other')),
    currency        VARCHAR(3) NOT NULL DEFAULT 'EUR'
                    CHECK (currency ~ '^[A-Z]{3}$'),
    initial_balance BIGINT NOT NULL DEFAULT 0,
    archived        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (budget_id, name),
    UNIQUE (id, budget_id)
);

CREATE TABLE categories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id       UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    category_type   TEXT NOT NULL CHECK (category_type IN ('income', 'expense')),
    icon            TEXT,
    color           TEXT,
    archived        BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (budget_id, category_type, name),
    UNIQUE (id, budget_id)
);

CREATE TABLE merchants (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id   UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    website_url TEXT,
    icon        TEXT,
    notes       TEXT,
    archived    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id, budget_id)
);

CREATE UNIQUE INDEX merchants_name_unique_ci
    ON merchants (budget_id, lower(name));

CREATE INDEX merchants_name_search_idx
    ON merchants (budget_id, lower(name))
    WHERE archived = FALSE;

CREATE TABLE transactions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id           UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    account_id          UUID NOT NULL,
    transfer_account_id UUID,
    category_id         UUID,
    merchant_id         UUID,
    transaction_type    TEXT NOT NULL
                        CHECK (transaction_type IN ('income', 'expense', 'transfer')),
    amount              BIGINT NOT NULL CHECK (amount > 0),
    currency            VARCHAR(3) NOT NULL DEFAULT 'EUR'
                        CHECK (currency ~ '^[A-Z]{3}$'),
    description         TEXT,
    external_url        TEXT,
    transaction_date    DATE NOT NULL,
    created_by          UUID NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    FOREIGN KEY (account_id, budget_id)
        REFERENCES accounts(id, budget_id),
    FOREIGN KEY (transfer_account_id, budget_id)
        REFERENCES accounts(id, budget_id),
    FOREIGN KEY (category_id, budget_id)
        REFERENCES categories(id, budget_id),
    FOREIGN KEY (merchant_id, budget_id)
        REFERENCES merchants(id, budget_id),

    CHECK (
        (
            transaction_type = 'transfer'
            AND transfer_account_id IS NOT NULL
            AND category_id IS NULL
            AND merchant_id IS NULL
            AND account_id <> transfer_account_id
        )
        OR
        (
            transaction_type IN ('income', 'expense')
            AND transfer_account_id IS NULL
            AND category_id IS NOT NULL
        )
    )
);

CREATE INDEX transactions_budget_date_idx
    ON transactions (budget_id, transaction_date DESC);
CREATE INDEX transactions_category_idx ON transactions (category_id);
CREATE INDEX transactions_merchant_idx ON transactions (merchant_id);
CREATE INDEX transactions_account_idx ON transactions (account_id);
CREATE INDEX transactions_transfer_account_idx
    ON transactions (transfer_account_id)
    WHERE transfer_account_id IS NOT NULL;

CREATE TABLE budget_plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id       UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    category_id     UUID NOT NULL,
    year            INTEGER NOT NULL CHECK (year BETWEEN 2000 AND 2200),
    month           INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    planned_amount  BIGINT NOT NULL CHECK (planned_amount >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    FOREIGN KEY (category_id, budget_id)
        REFERENCES categories(id, budget_id),

    UNIQUE (budget_id, category_id, year, month)
);

CREATE INDEX budget_plans_period_idx
    ON budget_plans (budget_id, year, month);

INSERT INTO roles (name) VALUES ('admin'), ('user');

INSERT INTO permissions (name, description) VALUES
    ('users.manage', 'Manage users and invitations'),
    ('budgets.manage', 'Manage budgets'),
    ('transactions.manage', 'Manage transactions'),
    ('categories.manage', 'Manage categories'),
    ('merchants.manage', 'Manage merchants');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'admin';

-- +goose Down

DROP TABLE IF EXISTS budget_plans;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS merchants;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS budget_members;
DROP TABLE IF EXISTS budgets;
DROP TABLE IF EXISTS invites;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS users;
