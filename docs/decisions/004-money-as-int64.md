# ADR-004: Store money as integer minor units

- Status: Accepted
- Date: 2026-09-07

## Context

Floating-point arithmetic is inappropriate for exact financial values and can produce rounding artifacts.

## Decision

Store monetary amounts as integer minor units.

- PostgreSQL: `BIGINT`
- Go: `int64`

Examples for EUR:
- €1.00 -> 100
- €12.50 -> 1250
- €1349.99 -> 134999

Do not use `float32` or `float64` for persisted or calculated money.

Currency is represented using a three-letter currency code.

FX conversion is not part of this decision and is not currently designed.

## Consequences

Formatting/parsing belongs at application boundaries. Business calculations remain exact integer arithmetic.
