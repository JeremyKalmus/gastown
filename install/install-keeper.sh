#!/bin/bash
#
# Keeper of the Seeds - Installation Script
# Installs Keeper governance system on a Gas Town rig
#
# Usage: ./install-keeper.sh [options] <rig-path>
#
# Options:
#   --mode <seeding|growth|conservation>  Set initial Keeper mode (default: growth)
#   --force                               Overwrite existing seeds
#   --skip-mayor                          Don't install Mayor commands
#   --skip-refinery                       Don't install Refinery commands
#   -h, --help                            Show this help message
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MODE="growth"
FORCE=false
SKIP_MAYOR=false
SKIP_REFINERY=false

# Get the directory where this script lives (keeper plugin root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_header() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Keeper of the Seeds - Installation                  ║"
    echo "║      Governance system for architectural consistency          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

usage() {
    echo "Usage: $0 [options] <rig-path>"
    echo ""
    echo "Install Keeper governance system on a Gas Town rig."
    echo ""
    echo "Options:"
    echo "  --mode <mode>      Set initial Keeper mode (default: growth)"
    echo "                     seeding      - Early project, allows new seeds freely"
    echo "                     growth       - Default, reuse-first, extensions preferred"
    echo "                     conservation - Mature project, new seeds rarely approved"
    echo "  --force            Overwrite existing seed files"
    echo "  --skip-mayor       Don't install Mayor slash commands"
    echo "  --skip-refinery    Don't install Refinery slash commands"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ~/gt/myproject                    # Install with defaults"
    echo "  $0 --mode seeding ~/gt/newproject    # New project, seeding mode"
    echo "  $0 --force ~/gt/myproject            # Reinstall, overwrite seeds"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            if [[ ! "$MODE" =~ ^(seeding|growth|conservation)$ ]]; then
                print_error "Invalid mode: $MODE"
                echo "Valid modes: seeding, growth, conservation"
                exit 1
            fi
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --skip-mayor)
            SKIP_MAYOR=true
            shift
            ;;
        --skip-refinery)
            SKIP_REFINERY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            RIG_PATH="$1"
            shift
            ;;
    esac
done

# Validate rig path
if [[ -z "$RIG_PATH" ]]; then
    print_error "No rig path specified"
    usage
    exit 1
fi

if [[ ! -d "$RIG_PATH" ]]; then
    print_error "Rig path does not exist: $RIG_PATH"
    exit 1
fi

# Resolve to absolute path
RIG_PATH="$(cd "$RIG_PATH" && pwd)"
RIG_NAME="$(basename "$RIG_PATH")"

# Check if this looks like a Gas Town rig
if [[ ! -f "$RIG_PATH/config.json" ]] && [[ ! -d "$RIG_PATH/.beads" ]]; then
    print_warning "This doesn't look like a Gas Town rig (no config.json or .beads)"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_header

echo "Installing Keeper on rig: $RIG_NAME"
echo "Path: $RIG_PATH"
echo "Mode: $MODE"
echo ""

# Step 1: Create keeper directory structure
print_info "Creating Keeper directory structure..."

mkdir -p "$RIG_PATH/keeper/seeds"
mkdir -p "$RIG_PATH/keeper/decisions"

print_success "Created keeper/ directory"

# Step 2: Copy seed templates
print_info "Installing seed templates..."

TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    print_error "Templates directory not found: $TEMPLATES_DIR"
    exit 1
fi

for seed_file in frontend.yaml backend.yaml data.yaml auth.yaml config.yaml testing.yaml; do
    src="$TEMPLATES_DIR/seeds/$seed_file"
    dst="$RIG_PATH/keeper/seeds/$seed_file"

    if [[ -f "$dst" ]] && [[ "$FORCE" != true ]]; then
        print_warning "Skipping $seed_file (exists, use --force to overwrite)"
    else
        if [[ -f "$src" ]]; then
            cp "$src" "$dst"
            print_success "Installed seeds/$seed_file"
        else
            print_warning "Template not found: $seed_file"
        fi
    fi
done

# Step 3: Create keeper.yaml config
print_info "Creating Keeper configuration..."

KEEPER_CONFIG="$RIG_PATH/keeper/keeper.yaml"

if [[ -f "$KEEPER_CONFIG" ]] && [[ "$FORCE" != true ]]; then
    print_warning "Skipping keeper.yaml (exists, use --force to overwrite)"
else
    cat > "$KEEPER_CONFIG" << EOF
# Keeper of the Seeds Configuration
# Generated by install-keeper.sh on $(date +%Y-%m-%d)

keeper:
  mode: $MODE

# Seed vault locations
seed_vault:
  frontend: seeds/frontend.yaml
  backend: seeds/backend.yaml
  data: seeds/data.yaml
  auth: seeds/auth.yaml

# Decisions output directory
decisions_dir: decisions/

# Installation metadata
installed:
  date: "$(date +%Y-%m-%d)"
  version: "1.0.0"
EOF
    print_success "Created keeper.yaml (mode: $MODE)"
fi

# Step 4: Install Mayor slash commands and enforcement hook
if [[ "$SKIP_MAYOR" != true ]]; then
    print_info "Installing Mayor slash commands..."

    # Find Mayor's .claude directory
    MAYOR_CLAUDE=""
    MAYOR_COMMANDS=""

    # Check for town-level mayor
    TOWN_ROOT="$(dirname "$RIG_PATH")"
    if [[ -d "$TOWN_ROOT/mayor/.claude" ]]; then
        MAYOR_CLAUDE="$TOWN_ROOT/mayor/.claude"
        MAYOR_COMMANDS="$MAYOR_CLAUDE/commands"
    fi

    # Check for rig-level mayor
    if [[ -d "$RIG_PATH/mayor/rig/.claude" ]]; then
        MAYOR_CLAUDE="$RIG_PATH/mayor/rig/.claude"
        MAYOR_COMMANDS="$MAYOR_CLAUDE/commands"
    fi

    if [[ -n "$MAYOR_COMMANDS" ]]; then
        mkdir -p "$MAYOR_COMMANDS"
        cp "$SCRIPT_DIR/commands/keeper-review.md" "$MAYOR_COMMANDS/"
        cp "$SCRIPT_DIR/commands/keeper-plant.md" "$MAYOR_COMMANDS/"
        print_success "Installed /keeper-review to Mayor"
        print_success "Installed /keeper-plant to Mayor"
    else
        print_warning "Mayor .claude directory not found, skipping Mayor commands"
    fi
fi

# Step 5: Install Refinery slash commands
if [[ "$SKIP_REFINERY" != true ]]; then
    print_info "Installing Refinery slash commands..."

    REFINERY_COMMANDS=""

    if [[ -d "$RIG_PATH/refinery/rig/.claude" ]]; then
        REFINERY_COMMANDS="$RIG_PATH/refinery/rig/.claude/commands"
    elif [[ -d "$RIG_PATH/refinery/.claude" ]]; then
        REFINERY_COMMANDS="$RIG_PATH/refinery/.claude/commands"
    fi

    if [[ -n "$REFINERY_COMMANDS" ]]; then
        mkdir -p "$REFINERY_COMMANDS"
        cp "$SCRIPT_DIR/commands/keeper-validate.md" "$REFINERY_COMMANDS/"
        print_success "Installed /keeper-validate to Refinery"
    else
        print_warning "Refinery .claude directory not found, skipping Refinery commands"
    fi
fi

# Step 6: Install to town-level .claude/commands (available to all agents)
print_info "Installing to town-level commands..."

TOWN_COMMANDS="$TOWN_ROOT/.claude/commands"
if [[ -d "$TOWN_ROOT/.claude" ]]; then
    mkdir -p "$TOWN_COMMANDS"
    cp "$SCRIPT_DIR/commands/keeper-review.md" "$TOWN_COMMANDS/"
    cp "$SCRIPT_DIR/commands/keeper-validate.md" "$TOWN_COMMANDS/"
    cp "$SCRIPT_DIR/commands/keeper-plant.md" "$TOWN_COMMANDS/"
    print_success "Installed commands to town-level .claude/commands/"
fi

# Step 7: Create initial CLAUDE.md additions
print_info "Creating Keeper CLAUDE.md snippet..."

KEEPER_CLAUDE="$RIG_PATH/keeper/KEEPER-INSTRUCTIONS.md"
cat > "$KEEPER_CLAUDE" << 'EOF'
# Keeper Integration Instructions

Add this to your agent's CLAUDE.md to enable Keeper governance.

## For Mayor

```markdown
## Keeper Integration

Before creating beads for any feature work:

1. Run `/keeper-review <spec-file>` to get architectural approval
2. Wait for APPROVED status before creating beads
3. Include Keeper ADR reference in bead descriptions:
   - `Keeper ADR: NNN`
   - `Constraints: <from keeper_decision>`

If Keeper returns APPROVED_WITH_CONDITIONS:
- Address conditions before proceeding
- Get justification for questioned items
- Re-run review if spec changes
```

## For Refinery

```markdown
## Keeper Integration

Before merging any polecat PR:

1. Run `/keeper-validate <adr-id>` against the changes
2. Only merge if validation returns APPROVED
3. If REJECTED:
   - Send violations back to polecat
   - Do not merge until resolved
   - Escalate to Mayor if ADR amendment needed
```

## For Polecats

Polecats receive constraints in their bead descriptions. They should:
- Follow all constraints exactly
- Not create components/services/enums outside what's approved
- Ask Mayor for ADR amendment if scope changes are needed
EOF

print_success "Created KEEPER-INSTRUCTIONS.md"

# Done!
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Keeper installed successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Installed to: $RIG_PATH/keeper/"
echo ""
echo "Structure:"
echo "  keeper/"
echo "  ├── keeper.yaml        # Configuration (mode: $MODE)"
echo "  ├── seeds/"
echo "  │   ├── frontend.yaml  # UI components, hooks, i18n, design tokens"
echo "  │   ├── backend.yaml   # API routes, services, errors, events"
echo "  │   ├── data.yaml      # Tables, enums, validation schemas"
echo "  │   ├── auth.yaml      # Auth patterns, scopes, roles"
echo "  │   ├── config.yaml    # Feature flags, environment config"
echo "  │   └── testing.yaml   # Test fixtures, mocks, utilities"
echo "  ├── decisions/         # ADR storage"
echo "  └── KEEPER-INSTRUCTIONS.md"
echo ""
echo "Next steps:"
echo "  1. Run /keeper-plant to discover existing patterns"
echo "  2. Review and refine keeper/seeds/*.yaml"
echo "  3. Add Keeper instructions to Mayor and Refinery CLAUDE.md"
echo ""
echo "Commands available:"
echo "  /keeper-plant             # Discover existing patterns (run once after install)"
echo "  /keeper-review <spec>     # Review spec before creating beads"
echo "  /keeper-validate <adr>    # Validate changes before merge"
echo ""
