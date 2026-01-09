# Keeper of the Seeds

Governance plugin for Gas Town that prevents architectural drift by enforcing reuse, consistency, and deliberate evolution across UI, API, data, and auth layers.

## What It Does

The Keeper acts as a hard gate: **convoys do not launch without Keeper approval**.

For every feature, the Keeper answers four questions:
1. **What already exists?** - Scans the seed vault for applicable patterns
2. **Is it sufficient?** - Determines if existing seeds meet the need
3. **If not, what is the smallest extension?** - Prefers extension over creation
4. **If a new seed is required, how is it preserved?** - Records new patterns

This transforms architecture from culture into infrastructure.

## Installation

### 1. Copy Templates to Your Rig

```bash
# From your rig root
cp -r templates/keeper.yaml ./keeper.yaml
cp -r templates/seeds ./seeds
mkdir -p decisions
```

### 2. Configure keeper.yaml

Edit `keeper.yaml` to set your mode based on project maturity:

```yaml
keeper:
  mode: seeding    # Early project: allows new seeds freely
  # mode: growth   # Default: reuse-first, extensions preferred
  # mode: conservation  # Mature: new seeds almost always rejected
```

### 3. Populate Your Seed Vault

Edit the files in `seeds/` to document your project's existing patterns:

- `seeds/frontend.yaml` - UI components
- `seeds/backend.yaml` - API routes and services
- `seeds/data.yaml` - Database schemas and enums
- `seeds/auth.yaml` - Authentication patterns

### Directory Structure

```
/rigs/<rig-name>/
  keeper.yaml       # Configuration
  seeds/            # The Seed Vault
    frontend.yaml
    backend.yaml
    data.yaml
    auth.yaml
  decisions/        # Immutable Keeper decisions
```

## Seed Vault Format

The seed vault is a machine-readable registry. Polecats don't interpret it—the Keeper does.

### Frontend Seeds (frontend.yaml)

```yaml
components:
  Button:
    variants: [primary, secondary, danger]
    location: src/ui/Button.tsx
    when_to_use: "Any clickable action"
    forbidden_extensions:
      - custom colors outside design system
      - inline styles
```

### Backend Seeds (backend.yaml)

```yaml
api_routes:
  POST /auth/login:
    purpose: "User authentication"
    auth_required: false

  GET /users/:id:
    purpose: "User profile retrieval"
    auth_required: true
    scopes: [user:read]

services:
  AuthService:
    responsibilities:
      - token issuance
      - token validation
    forbidden:
      - user creation
```

### Data Seeds (data.yaml)

```yaml
enums:
  user_status:
    values: [active, suspended, deleted]
    extension_policy: append-only    # append-only|frozen|controlled
    scope: global                    # global|table:tablename

tables:
  users:
    primary_key: id
    enum_fields:
      - status: user_status
    indexes: [email, created_at]
    constraints:
      - email must be unique
```

### Auth Seeds (auth.yaml)

```yaml
auth_model:
  type: jwt
  token_types: [access, refresh]
  forbidden_patterns:
    - localStorage for tokens
    - tokens in URL params

scopes:
  user:read:
    description: "Read own user profile"
    granted_to: [user, admin]

  admin:read:
    implies: [user:read]
    granted_to: [admin]
```

## Decision Matrix

The Keeper uses a deterministic matrix—not opinions.

### Frontend Components

| Question | Yes | No |
|----------|-----|-----|
| Component exists? | Use it | Continue |
| Variant fits use case? | Use variant | Extend variant |
| Extension breaks design system? | **Reject** | Approve |
| Extension reused ≥2 times? | Promote to core | Local only |

### API Routes

| Question | Yes | No |
|----------|-----|-----|
| Route exists with same resource? | Extend | Continue |
| Extension is backward-compatible? | Modify | New route |
| New route matches REST shape? | Approve | **Reject** |
| Auth model consistent? | Proceed | Fix auth |

### Database Enums/Fields

| Question | Yes | No |
|----------|-----|-----|
| Enum exists? | Extend | Continue |
| Extension append-only? | OK | **Reject** |
| New enum scoped to one table? | Approve | Global enum |
| Requires migration? | Generate plan | **Block** |

### Auth/Identity

| Question | Yes | No |
|----------|-----|-----|
| Auth service exists? | Use it | **Block** |
| New permission required? | Add scope | Reject new role |
| Token shape consistent? | Proceed | **Reject** |

## Keeper Modes

The mode determines strictness. Set in `keeper.yaml`:

### Seeding Mode (early project)

```yaml
keeper:
  mode: seeding
```

- Allows new seeds freely
- Still records them to the vault
- Warns instead of blocks
- **Use when:** Project is brand new, establishing patterns
- **Transition after:** Founding Convoy completes, patterns stabilize

### Growth Mode (default)

```yaml
keeper:
  mode: growth
```

- Reuse-first: existing seeds must be used when applicable
- Extension preferred over creation
- New seeds gated: requires justification and ≥2 usage instances
- **Use when:** Project has established patterns but is evolving
- **Transition when:** Churn decreases, patterns stabilize

### Conservation Mode (mature project)

```yaml
keeper:
  mode: conservation
```

- New seeds almost always rejected
- Focus on stability over new features
- Extensions require strong justification
- **Use when:** Project is stable, in maintenance, or preparing for handoff

## Example Workflow

### Scenario: Adding a "warning" button variant

1. **Polecat requests feature** that needs a warning-styled button

2. **Keeper checks seed vault:**
   ```yaml
   # seeds/frontend.yaml shows:
   Button:
     variants: [primary, secondary, danger]
   ```

3. **Keeper evaluates:**
   - Component exists? ✓ Yes → Use Button
   - Variant fits? ✗ No "warning" variant
   - Would extension break design system? No
   - Has "warning" been needed elsewhere? Checking...

4. **Keeper outputs decision:**
   ```yaml
   keeper_decision:
     status: approved
     reuse:
       frontend:
         - Button
     extensions:
       frontend:
         Button:
           add_variant: "warning"
     forbidden:
       - new button implementations
   ```

5. **Decision becomes immutable input** for the convoy. If polecat creates a new `WarningButton` component instead of extending `Button`, the output is rejected automatically.

### Scenario: Rejected request

1. **Polecat wants new auth service** for social login

2. **Keeper checks:**
   ```yaml
   # seeds/auth.yaml shows AuthService exists
   ```

3. **Decision matrix (Auth D):**
   - Auth service exists? ✓ Yes → Use it

4. **Keeper output:**
   ```yaml
   keeper_decision:
     status: rejected
     reason: "Auth service exists. Extend AuthService to support social providers."
     forbidden:
       - new auth services
   ```

## Key Principles

From the Keeper prompt (spec section 5):

- "Prefer reuse over extension."
- "Prefer extension over creation."
- "Reject if uncertain."
- "You are accountable for long-term system coherence."

The Keeper is not a "helpful" agent. It is a **librarian with veto power**.

## Adding New Seeds (Controlled Evolution)

### Path 1: Emergence (preferred)

A pattern must appear at least twice as an extension before promotion:

1. Feature A extends existing pattern
2. Feature B extends same pattern
3. Keeper promotes extension → new seed

This prevents speculative abstractions.

### Path 2: Explicit Proposal (rare)

For foundational changes (new auth model, new data paradigm):

- Requires Seed Proposal Convoy
- Must include justification, migration plan, rollback strategy
- Default outcome: rejection

## The Rule

> **No Keeper, no convoy. No seeds, no Keeper.**

That ordering matters.
