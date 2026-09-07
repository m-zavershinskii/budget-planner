# ADR-005: Category and merchant are separate transaction dimensions

- Status: Accepted
- Date: 2026-09-07

## Context

A transaction needs both a semantic spending/income classification and, optionally, information about where/who the transaction was with.

For example, REWE may usually mean groceries, but the same merchant concept must not be hard-wired to one category.

## Decision

Model Category and Merchant as separate budget-owned entities.

Example:
- Category: Groceries
- Merchant: REWE

Merchant is configurable by the user and optional on ordinary transactions.

The transaction entry UI must support merchant autocomplete and inline creation:
- search as the user types;
- offer existing matches;
- if necessary, offer `Create "<name>"`;
- immediately select the new merchant without leaving the transaction form.

`merchant.website_url` is a general merchant URL.

`transaction.external_url` is a separate optional URL for a specific receipt, order, invoice, booking or other transaction reference.

Transfers do not use merchants.

## Consequences

Reporting can independently aggregate by category and merchant.

A merchant can be used with different categories, and the UI can remain fast for repeated transaction entry.
