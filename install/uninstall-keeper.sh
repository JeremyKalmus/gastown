#!/bin/bash
#
# Keeper of the Seeds - Uninstallation Script
# Removes Keeper governance system from a Gas Town rig
#
# Usage: ./uninstall-keeper.sh [options] <rig-path>
#
# Options:
#   --keep-decisions    Don't delete existing decisions (ADRs)
#   --keep-seeds        Don't delete seed files
#   -y, --yes           Skip confirmation prompt
#   -h, --help          Show this help message
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEEP_DECISIONS=false
KEEP_SEEDS=false
SKIP_CONFIRM=false

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}→${NC} $1"; }

usage() {
    echo "Usage: $0 [options] <rig-path>"
    echo ""
    echo "Remove Keeper governance system from a Gas Town rig."
    echo ""
    echo "Options:"
    echo "  --keep-decisions   Don't delete existing decisions (ADRs)"
    echo "  --keep-seeds       Don't delete seed files"
    echo "  -y, --yes          Skip confirmation prompt"
    echo "  -h, --help         Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-decisions)
            KEEP_DECISIONS=true
            shift
            ;;
        --keep-seeds)
            KEEP_SEEDS=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
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

if [[ -z "$RIG_PATH" ]]; then
    print_error "No rig path specified"
    usage
    exit 1
fi

if [[ ! -d "$RIG_PATH" ]]; then
    print_error "Rig path does not exist: $RIG_PATH"
    exit 1
fi

RIG_PATH="$(cd "$RIG_PATH" && pwd)"
RIG_NAME="$(basename "$RIG_PATH")"
TOWN_ROOT="$(dirname "$RIG_PATH")"

echo ""
echo -e "${YELLOW}Uninstalling Keeper from: $RIG_NAME${NC}"
echo "Path: $RIG_PATH"
echo ""

if [[ "$SKIP_CONFIRM" != true ]]; then
    echo "This will remove:"
    [[ "$KEEP_SEEDS" != true ]] && echo "  - keeper/seeds/*.yaml"
    [[ "$KEEP_DECISIONS" != true ]] && echo "  - keeper/decisions/*.yaml"
    echo "  - keeper/keeper.yaml"
    echo "  - Slash commands from Mayor and Refinery"
    echo ""
    read -p "Are you sure? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Remove slash commands from Mayor
print_info "Removing Mayor commands..."
for dir in "$TOWN_ROOT/mayor/.claude/commands" "$RIG_PATH/mayor/rig/.claude/commands"; do
    if [[ -f "$dir/keeper-review.md" ]]; then
        rm "$dir/keeper-review.md"
        print_success "Removed keeper-review.md from Mayor"
    fi
done

# Remove slash commands from Refinery
print_info "Removing Refinery commands..."
for dir in "$RIG_PATH/refinery/rig/.claude/commands" "$RIG_PATH/refinery/.claude/commands"; do
    if [[ -f "$dir/keeper-validate.md" ]]; then
        rm "$dir/keeper-validate.md"
        print_success "Removed keeper-validate.md from Refinery"
    fi
done

# Remove from town-level commands
if [[ -f "$TOWN_ROOT/.claude/commands/keeper-review.md" ]]; then
    rm "$TOWN_ROOT/.claude/commands/keeper-review.md"
    print_success "Removed keeper-review.md from town commands"
fi
if [[ -f "$TOWN_ROOT/.claude/commands/keeper-validate.md" ]]; then
    rm "$TOWN_ROOT/.claude/commands/keeper-validate.md"
    print_success "Removed keeper-validate.md from town commands"
fi

# Remove keeper directory contents
if [[ -d "$RIG_PATH/keeper" ]]; then
    print_info "Removing Keeper files..."

    # Seeds
    if [[ "$KEEP_SEEDS" != true ]] && [[ -d "$RIG_PATH/keeper/seeds" ]]; then
        rm -rf "$RIG_PATH/keeper/seeds"
        print_success "Removed seeds/"
    elif [[ "$KEEP_SEEDS" == true ]]; then
        print_warning "Keeping seeds/ (--keep-seeds)"
    fi

    # Decisions
    if [[ "$KEEP_DECISIONS" != true ]] && [[ -d "$RIG_PATH/keeper/decisions" ]]; then
        rm -rf "$RIG_PATH/keeper/decisions"
        print_success "Removed decisions/"
    elif [[ "$KEEP_DECISIONS" == true ]]; then
        print_warning "Keeping decisions/ (--keep-decisions)"
    fi

    # Config and instructions
    [[ -f "$RIG_PATH/keeper/keeper.yaml" ]] && rm "$RIG_PATH/keeper/keeper.yaml"
    [[ -f "$RIG_PATH/keeper/KEEPER-INSTRUCTIONS.md" ]] && rm "$RIG_PATH/keeper/KEEPER-INSTRUCTIONS.md"

    # Remove keeper dir if empty
    if [[ -z "$(ls -A "$RIG_PATH/keeper" 2>/dev/null)" ]]; then
        rmdir "$RIG_PATH/keeper"
        print_success "Removed empty keeper/ directory"
    else
        print_warning "keeper/ directory not empty, keeping it"
    fi
fi

echo ""
echo -e "${GREEN}Keeper uninstalled from $RIG_NAME${NC}"
echo ""
