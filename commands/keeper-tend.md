---
description: Lightweight incremental seed maintenance - check recent changes against Seed Vault
allowed-tools: Read,Glob,Grep,Bash(git:*),Bash(ls:*),Bash(cat:*),Bash(date:*)
argument-hint: [--days N] [--mode seeding|growth]
---

# Keeper Tend Seeds

You are the **Keeper of the Seeds** performing incremental maintenance.

Unlike `/keeper-plant` (full discovery), this command checks **only recent changes** for new
patterns that should be documented in the Seed Vault. Runs quickly (<10 seconds).

**Arguments**: $ARGUMENTS

## Step 1: Determine Time Window

Parse `--days N` from arguments, default to 7 days.

```bash
git log --oneline --since="7 days ago" --name-status | head -30
```

## Step 2: Load Current Mode

Check for `--mode` argument. If not specified, read from keeper config:
```bash
cat keeper/keeper.yaml 2>/dev/null || echo "mode: seeding"
```

## Step 3: Identify Changed Files by Category

Run these git queries to categorize changes:

### Frontend Changes
```bash
git diff --name-only HEAD~20 -- '*.tsx' '*.jsx' 'src/ui/*' 'src/components/*' 'app/components/*' 2>/dev/null | head -20
```

### Backend Changes
```bash
git diff --name-only HEAD~20 -- 'src/api/*' 'app/api/*' 'src/routes/*' 'src/services/*' '*.route.ts' 2>/dev/null | head -20
```

### Data Changes
```bash
git diff --name-only HEAD~20 -- 'prisma/*' '*.schema.ts' 'src/types/*' 'src/enums/*' 'migrations/*' 2>/dev/null | head -20
```

### Auth Changes
```bash
git diff --name-only HEAD~20 -- '*auth*' '*permission*' '*scope*' '*role*' 'src/middleware/*' 2>/dev/null | head -20
```

## Step 4: Load Current Seeds

Read existing seed registries:
```bash
ls keeper/seeds/*.yaml 2>/dev/null
```

For each seed file found, read and note documented patterns.

## Step 5: Quick Pattern Detection

For each changed file, scan for seedable patterns:

### Component Pattern (tsx/jsx files)
Look for: `export (default |)function|const \w+` - potential component

### Enum Pattern
Look for: `enum \w+` or `type \w+ =` with union literals

### API Route Pattern
Look for: `GET|POST|PUT|DELETE|PATCH` handlers, `router.` calls

### Hook Pattern
Look for: `export function use\w+`

### Service Pattern
Look for: `class \w+Service` or `export const \w+Service`

## Step 6: Cross-Reference with Seeds

For each detected pattern:
1. Check if it exists in the corresponding seed file
2. If not found, mark as **undocumented**

## Step 7: Generate Report

```
KEEPER TEND: [DATE]

Scanned: [N] changed files from last [D] days
Mode: [seeding|growth|conservation]

─────────────────────────────────────
UNDOCUMENTED PATTERNS FOUND
─────────────────────────────────────

Frontend:
  [x] ComponentName (src/ui/ComponentName.tsx)
      Variants detected: [variant1, variant2]
  [ ] Already documented: Button, Modal, ...

Backend:
  [x] /api/new-route (src/api/new-route.ts)
      Methods: POST, GET
  [ ] Already documented: /api/users, ...

Data:
  [x] NewEnum (src/types/enums.ts)
      Values: [VALUE_A, VALUE_B]
  [ ] Already documented: StatusEnum, ...

─────────────────────────────────────
```

## Step 8: Take Action Based on Mode

### Seeding Mode
Auto-add undocumented patterns to seed files:

For each undocumented pattern, append to the appropriate seed file with minimal entry:
```yaml
  NewComponent:  # auto-discovered by keeper-tend
    variants: [detected-variants]
    location: path/to/file.tsx
    when_to_use: "TODO: Add description"
```

Report: "Added [N] patterns to seed vault. Review and complete descriptions."

### Growth/Conservation Mode
Do NOT auto-add. Instead output:

```
SUGGESTED ADDITIONS (requires manual review):

1. Add to keeper/seeds/frontend.yaml:
   NewComponent:
     variants: [default]
     location: src/ui/NewComponent.tsx
     when_to_use: "TODO"

2. Add to keeper/seeds/backend.yaml:
   /api/new-route:
     methods: [POST, GET]
     auth: TODO
```

## Step 9: Summary

```
KEEPER TEND COMPLETE

Files scanned: [N]
New patterns found: [N]
[Seeding: Added to vault | Growth: Suggestions above]

Run /keeper-plant for full codebase discovery.
Run /keeper-review <spec> before implementing new features.
```

## Performance Notes

- This command should complete in <10 seconds
- Uses git diff instead of full codebase scan
- Pattern detection is heuristic, not exhaustive
- Run regularly (daily/weekly) to keep seeds current
- Use `/keeper-plant` for comprehensive discovery
