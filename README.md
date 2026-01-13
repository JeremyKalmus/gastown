# Keeper of the Seeds

Governance plugin for Gas Town that prevents architectural drift by enforcing reuse, consistency, and deliberate evolution across UI, API, data, and auth layers.

## What It Does

The Keeper operates as a **dual-gate system**:

1. **Front Gate (Mayor)**: Reviews specs before work is assigned to polecats
2. **Back Gate (Refinery)**: Validates polecat changes before merge

For every feature, the Keeper answers four questions:
1. **What already exists?** - Scans the seed vault for applicable patterns
2. **Is it sufficient?** - Determines if existing seeds meet the need
3. **If not, what is the smallest extension?** - Prefers extension over creation
4. **If a new seed is required, how is it preserved?** - Records new patterns

This transforms architecture from culture into infrastructure.

## Installation

### Quick Install (Recommended)

```bash
# Install on a rig with default settings (growth mode)
./install/install-keeper.sh ~/gt/myproject

# Install on a new project (seeding mode - more permissive)
./install/install-keeper.sh --mode seeding ~/gt/newproject

# Install on a mature project (conservation mode - strict)
./install/install-keeper.sh --mode conservation ~/gt/stable
```

### What Gets Installed

```
<rig>/
├── keeper/
│   ├── keeper.yaml           # Configuration
│   ├── seeds/
│   │   ├── frontend.yaml     # UI component registry
│   │   ├── backend.yaml      # API routes registry
│   │   ├── data.yaml         # Schema registry
│   │   └── auth.yaml         # Auth patterns registry
│   ├── decisions/            # ADR storage
│   └── KEEPER-INSTRUCTIONS.md
└── .claude/commands/
    ├── keeper-review.md      # For Mayor
    └── keeper-validate.md    # For Refinery
```

### Uninstall

```bash
./install/uninstall-keeper.sh ~/gt/myproject
./install/uninstall-keeper.sh --keep-decisions ~/gt/myproject  # Preserve ADRs
```

## Mayor Integration

**IMPORTANT**: The Mayor must run `/keeper-review` before creating beads for any feature work.

### Mayor Workflow

```
1. Receive feature spec/request
2. Run: /keeper-review <spec-file>
3. Wait for APPROVED status
4. Create beads with ADR reference:
   - Include "Keeper ADR: NNN" in description
   - Include constraints from keeper_decision
5. Sling to polecats
```

### Example Mayor Session

```
User: "Add a notification system to alert users when tasks complete"

Mayor: Let me review this against the Keeper first.

> /keeper-review notification-spec.md

KEEPER DECISION: APPROVED WITH CONDITIONS
- Reuse: notifications table (exists), Button component
- Extensions: Button notification variant
- Conditions: NotificationToast needs justification
- Forbidden: New auth services

Mayor: Creating beads with Keeper constraints...

> bd create --title="Add notification status field" \
    --body="Keeper ADR: 001. MUST use existing notifications table."
```

## Refinery Integration

The Refinery must run `/keeper-validate` before merging any polecat PR.

### Refinery Workflow

```
1. Polecat submits PR
2. Run: /keeper-validate <adr-id>
3. If APPROVED → merge
4. If REJECTED → return to polecat with violations
```

### Example Validation

```
> /keeper-validate 001

KEEPER VALIDATION: REJECTED

Violations: 2

1. [FORBIDDEN] NotificationToast.tsx created
   - Was in CONDITIONS, not APPROVED

2. [CONSTRAINT] Enum has unapproved value 'archived'
   - Approved: [unread, read, dismissed]
   - Found: [unread, read, dismissed, archived]

Polecat must revise and resubmit.
```

## Keeper Modes

Set in `keeper/keeper.yaml`:

| Mode | When to Use | Behavior |
|------|-------------|----------|
| `seeding` | New project | Allows new seeds freely, warns instead of blocks |
| `growth` | Default | Reuse-first, extensions preferred, new seeds gated |
| `conservation` | Mature project | New seeds almost always rejected |

## Seed Vault Format

The seed vault is a machine-readable registry in `keeper/seeds/`:

### frontend.yaml
```yaml
components:
  Button:
    variants: [primary, secondary, danger]
    location: src/ui/Button.tsx
    when_to_use: "Any clickable action"
    forbidden_extensions:
      - custom colors outside design system
```

### backend.yaml
```yaml
api_routes:
  GET /users/:id:
    purpose: "User profile retrieval"
    auth_required: true
    scopes: [user:read]

services:
  AuthService:
    responsibilities: [token issuance, token validation]
    forbidden: [user creation]
```

### data.yaml
```yaml
enums:
  user_status:
    values: [active, suspended, deleted]
    extension_policy: append-only
    scope: global
```

### auth.yaml
```yaml
auth_model:
  type: jwt
  forbidden_patterns:
    - localStorage for tokens
    - tokens in URL params

scopes:
  user:read:
    granted_to: [user, admin]
```

## Decision Matrix

The Keeper uses deterministic matrices:

### Frontend
| Question | Yes | No |
|----------|-----|-----|
| Component exists? | Use it | Continue |
| Variant fits? | Use variant | Extend |
| Breaks design system? | **REJECT** | Approve |

### Backend
| Question | Yes | No |
|----------|-----|-----|
| Route exists? | Extend | Continue |
| Backward-compatible? | Modify | New route |
| Matches REST? | Approve | **REJECT** |

### Data
| Question | Yes | No |
|----------|-----|-----|
| Enum exists? | Extend | Continue |
| Append-only? | OK | **REJECT** |

### Auth
| Question | Yes | No |
|----------|-----|-----|
| Auth service exists? | Use it | **BLOCK** |

## Commands

| Command | Who | When |
|---------|-----|------|
| `/keeper-review <spec>` | Mayor | Before creating beads |
| `/keeper-validate <adr>` | Refinery | Before merging PR |

## Key Principles

- **Prefer reuse over extension**
- **Prefer extension over creation**
- **Reject if uncertain**
- A pattern must appear **twice** as an extension before promotion to seed

The Keeper is not a "helpful" agent. It is a **librarian with veto power**.

## The Rule

> **No Keeper, no convoy. No seeds, no Keeper.**
