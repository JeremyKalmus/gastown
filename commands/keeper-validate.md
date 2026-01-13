---
description: Validate polecat changes against keeper_decision before merge
allowed-tools: Read,Glob,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(cat:*),Bash(ls:*)
argument-hint: <adr-id-or-branch>
---

# Keeper Validate

You are now acting as the **Keeper of the Seeds** validating polecat output at the back gate.

**Input**: $ARGUMENTS (ADR ID like "001" or branch name)

## Step 1: Identify the Keeper Decision

If input is an ADR number (e.g., "001"):
```bash
cat keeper/decisions/*$ARGUMENTS*.yaml 2>/dev/null || cat decisions/*$ARGUMENTS*.yaml 2>/dev/null
```

If input is a branch name, find the ADR referenced in the PR/commit messages:
```bash
git log --oneline -10 | grep -i "ADR\|keeper"
```

If no ADR found, this work was NOT approved by Keeper - **REJECT immediately**.

## Step 2: Load the Original Decision

Read the keeper_decision file and extract:
- `reuse` - what existing patterns should be used
- `extensions` - what extensions were approved
- `new_seeds` - what new patterns were approved
- `forbidden` - what is explicitly blocked
- `constraints` - specific rules polecats must follow

## Step 3: Get the Changes

Get the diff of changes to validate:
```bash
git diff main...HEAD --name-only
```

For detailed diff:
```bash
git diff main...HEAD
```

## Step 4: Validate Against Decision

Check each category for violations:

### 4A. Frontend Violations

Scan for new component files:
```bash
git diff main...HEAD --name-only | grep -E '\.(tsx|jsx)$' | grep -i component
```

For each new file, check:
- Was this component in `new_seeds` or `extensions`?
- Is it in `forbidden`?
- Does it duplicate existing seed vault components?

**VIOLATION if**: New component created that wasn't approved

### 4B. Backend Violations

Scan for new route definitions:
```bash
git diff main...HEAD -S "router\." --name-only
git diff main...HEAD -S "app.get\|app.post\|app.put\|app.delete" --name-only
```

For each new route, check:
- Was this route in `new_seeds`?
- Does it follow REST patterns required in constraints?

**VIOLATION if**: New route created that wasn't approved

### 4C. Data Violations

Scan for enum changes:
```bash
git diff main...HEAD -S "enum\|ENUM\|type.*="
```

Scan for schema/migration changes:
```bash
git diff main...HEAD --name-only | grep -E 'migration|schema|\.sql$'
```

For each change, check:
- Was this enum/field in `new_seeds` or `extensions`?
- Does it follow append-only policy if required?
- Is it in `forbidden`?

**VIOLATION if**:
- New enum created that wasn't approved
- Enum values removed (violates append-only)
- Schema change outside approved scope

### 4D. Auth Violations

Scan for auth-related changes:
```bash
git diff main...HEAD -S "scope\|permission\|auth\|token"
```

For each change, check:
- Was this scope in `new_seeds`?
- Does it follow the token_shape requirements?
- Is it in `forbidden`?

**VIOLATION if**: New auth pattern that wasn't approved

### 4E. Constraint Violations

For each item in the `constraints` list, verify compliance:
- If constraint says "MUST use X", verify X is used
- If constraint says "MUST NOT create Y", verify Y wasn't created
- If constraint says "MUST extend Z", verify Z was extended not replaced

## Step 5: Check Forbidden Patterns

For each item in `forbidden`, scan the diff:
```bash
git diff main...HEAD | grep -i "<forbidden_pattern>"
```

**VIOLATION if**: Any forbidden pattern appears in diff

## Step 6: Generate Validation Report

### If NO violations found:

```
KEEPER VALIDATION: APPROVED

ADR: <adr-id>
Changes validated: <count> files
Violations: 0

Summary:
- Reuse compliance: PASS
- Extension compliance: PASS
- New seeds compliance: PASS
- Forbidden patterns: NONE FOUND
- Constraints: ALL MET

Ready for merge.
```

### If violations found:

```
KEEPER VALIDATION: REJECTED

ADR: <adr-id>
Changes validated: <count> files
Violations: <count>

VIOLATIONS FOUND:

1. [FORBIDDEN] <description>
   File: <path>
   Line: <line number if available>
   Rule: <which forbidden pattern was violated>

2. [UNAPPROVED] <description>
   File: <path>
   Expected: <what should have been done>
   Found: <what was actually done>

3. [CONSTRAINT] <description>
   Constraint: "<the constraint text>"
   Status: NOT MET

REQUIRED ACTIONS:
- <specific fix for violation 1>
- <specific fix for violation 2>

This PR cannot be merged until violations are resolved.
Polecat should revise and resubmit.
```

## Step 7: Record Validation Result

Append to the ADR file or create a validation record:
```yaml
validation:
  date: YYYY-MM-DD
  branch: <branch-name>
  result: approved|rejected
  violations: <count>
  validated_by: refinery
```

## Critical Rules

- **No ADR = No merge** - Work without Keeper approval is rejected
- **Any forbidden pattern = Immediate reject**
- **Unapproved new seeds = Reject** (polecat cannot create what wasn't approved)
- **Constraint violations = Reject** (constraints are non-negotiable)
- When in doubt, **REJECT** and ask for clarification
