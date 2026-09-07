-- name: SearchMerchants :many
SELECT
    id,
    budget_id,
    name,
    website_url,
    icon,
    notes,
    archived,
    created_at,
    updated_at
FROM merchants
WHERE budget_id = sqlc.arg(budget_id)
  AND archived = FALSE
  AND lower(name) LIKE lower(sqlc.arg(query)) || '%'
ORDER BY name
LIMIT 10;

-- name: CreateMerchant :one
INSERT INTO merchants (budget_id, name, website_url, icon, notes)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetMerchant :one
SELECT *
FROM merchants
WHERE id = $1
  AND budget_id = $2;
