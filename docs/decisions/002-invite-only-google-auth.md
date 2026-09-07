# ADR-002: Invite-only Google authentication

- Status: Accepted
- Date: 2026-09-07

## Context

The application must not permit arbitrary public registration. Administrators control who can obtain access.

Google is the selected identity provider for user authentication.

## Decision

Registration is invitation-only.

An administrator creates an invitation for a specific email address. A cryptographically random single-use token is generated, but only its hash is persisted.

The invited user authenticates through Google OAuth 2.0 / OpenID Connect. The application requires a verified Google email matching the invitation email case-insensitively.

User creation and invitation consumption must be atomic.

Expired, revoked, used, invalid and email-mismatched invitations are rejected.

There is no public Google signup flow that bypasses invitations.

## Consequences

Authentication proves identity through Google, while the application's invitation and authorization model decides whether that identity may use Budget Planner.

The first administrator needs a separate secure bootstrap mechanism.
