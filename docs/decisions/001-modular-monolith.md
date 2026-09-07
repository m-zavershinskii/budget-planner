# ADR-001: Modular monolith and simple deployment

- Status: Accepted
- Date: 2026-09-07

## Context

Budget Planner needs authentication, administration, budget planning, transactions and reporting, but currently has no requirement that justifies distributed services.

The application should be easy to develop and deploy.

## Decision

Build Budget Planner as a modular monolith in Go backed by PostgreSQL.

The target production shape is:
- one Go application binary;
- one PostgreSQL database.

Server-rendered web assets should eventually be embedded in the Go binary where practical.

Do not introduce microservices or infrastructure such as Kafka/Redis without a demonstrated requirement.

## Consequences

Domain boundaries should remain explicit inside `internal/`, while deployment remains simple.

This decision does not prevent splitting components later if scale or operational requirements actually demand it.
