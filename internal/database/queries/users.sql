-- name: GetUserByEmail :one
SELECT *
FROM users
WHERE lower(email) = lower($1);

-- name: GetUserByGoogleID :one
SELECT *
FROM users
WHERE google_id = $1;
