#!/bin/bash
# lib/keeper-review.sh - Shared keeper review logic
#
# This library provides functions for keeper review operations:
# - Loading and parsing seed vault files
# - Finding and parsing keeper decisions (ADRs)
# - Generating ADR files from templates
# - Outputting bead frontmatter for convoy creation
#
# Usage:
#   source lib/keeper-review.sh
#   # or: source "$(dirname "$0")/../lib/keeper-review.sh"
#
# Reference: keeper-spec.md

# Configuration
KEEPER_LIB_VERSION="1.0.0"
KEEPER_ROOT="${KEEPER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SEEDS_DIR="${KEEPER_ROOT}/seeds"
TEMPLATES_SEEDS_DIR="${KEEPER_ROOT}/templates/seeds"
DECISIONS_DIR="${KEEPER_ROOT}/decisions"
ADR_TEMPLATE="${KEEPER_ROOT}/templates/adr.yaml"
KEEPER_CONFIG="${KEEPER_ROOT}/keeper/keeper.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

keeper_log_error() {
    echo -e "${RED}[keeper] ERROR: $1${NC}" >&2
}

keeper_log_warn() {
    echo -e "${YELLOW}[keeper] WARNING: $1${NC}" >&2
}

keeper_log_success() {
    echo -e "${GREEN}[keeper] $1${NC}"
}

keeper_log_info() {
    echo "[keeper] $1"
}

keeper_log_debug() {
    if [[ "${KEEPER_DEBUG:-}" == "1" ]]; then
        echo -e "${CYAN}[keeper:debug] $1${NC}" >&2
    fi
}

# =============================================================================
# SEED VAULT FUNCTIONS
# =============================================================================

# Get the seeds directory (check both keeper/seeds and templates/seeds)
keeper_get_seeds_dir() {
    if [[ -d "$SEEDS_DIR" ]]; then
        echo "$SEEDS_DIR"
    elif [[ -d "$TEMPLATES_SEEDS_DIR" ]]; then
        echo "$TEMPLATES_SEEDS_DIR"
    else
        echo ""
    fi
}

# Load all seed files and output as combined YAML
# Returns: merged seed content or empty string if no seeds found
keeper_load_seeds() {
    local seeds_dir
    seeds_dir=$(keeper_get_seeds_dir)

    if [[ -z "$seeds_dir" || ! -d "$seeds_dir" ]]; then
        keeper_log_warn "No seeds directory found"
        return 1
    fi

    local seed_files=()
    while IFS= read -r -d '' file; do
        seed_files+=("$file")
    done < <(find "$seeds_dir" -name "*.yaml" -type f -print0 2>/dev/null)

    if [[ ${#seed_files[@]} -eq 0 ]]; then
        keeper_log_warn "No seed files found in $seeds_dir"
        return 1
    fi

    keeper_log_debug "Found ${#seed_files[@]} seed files"

    # Output seed content with file markers
    for file in "${seed_files[@]}"; do
        local name
        name=$(basename "$file" .yaml)
        echo "# === $name ==="
        cat "$file"
        echo ""
    done
}

# Extract specific seed category
# Args: $1 = category (frontend, backend, data, auth, config, testing)
keeper_get_seed_category() {
    local category="$1"
    local seeds_dir
    seeds_dir=$(keeper_get_seeds_dir)

    local seed_file="${seeds_dir}/${category}.yaml"
    if [[ -f "$seed_file" ]]; then
        cat "$seed_file"
    else
        return 1
    fi
}

# =============================================================================
# KEEPER MODE FUNCTIONS
# =============================================================================

# Get the current keeper mode from keeper.yaml
# Returns: seeding | growth | conservation (default: growth)
keeper_get_mode() {
    local config_file="${KEEPER_CONFIG}"

    # Try alternate locations
    if [[ ! -f "$config_file" ]]; then
        config_file="${KEEPER_ROOT}/keeper.yaml"
    fi

    if [[ -f "$config_file" ]]; then
        local mode
        mode=$(grep -E '^\s*mode:\s*' "$config_file" 2>/dev/null | head -1 | sed 's/.*mode:\s*//' | tr -d '[:space:]"'"'" | tr '[:upper:]' '[:lower:]')
        echo "${mode:-growth}"
    else
        echo "growth"
    fi
}

# Check if current mode allows bypass
# Returns: 0 if bypass allowed (seeding mode), 1 otherwise
keeper_mode_allows_bypass() {
    local mode
    mode=$(keeper_get_mode)
    [[ "$mode" == "seeding" ]]
}

# =============================================================================
# ADR FUNCTIONS
# =============================================================================

# Get the next ADR number
# Returns: next number (e.g., "003")
keeper_get_next_adr_number() {
    mkdir -p "$DECISIONS_DIR"

    local last_num
    last_num=$(ls "$DECISIONS_DIR" 2>/dev/null | grep -E '^[0-9]+' | sort -n | tail -1 | grep -oE '^[0-9]+' || echo "0")

    local next_num=$((10#${last_num:-0} + 1))
    printf "%03d" "$next_num"
}

# Find an existing keeper decision file
# Args: $1 = optional ADR ID or spec reference
# Returns: path to decision file or empty string
keeper_find_decision() {
    local search="${1:-}"

    # Search paths in order of preference
    local search_paths=(
        "${GT_KEEPER_DECISION:-}"
        "${DECISIONS_DIR}/keeper_decision.yaml"
        "${DECISIONS_DIR}/latest.yaml"
        "${KEEPER_ROOT}/keeper_decision.yaml"
    )

    # If search term provided, look for matching ADR
    if [[ -n "$search" ]]; then
        local adr_file
        adr_file=$(find "$DECISIONS_DIR" -name "*${search}*" -type f 2>/dev/null | head -1)
        if [[ -n "$adr_file" ]]; then
            echo "$adr_file"
            return 0
        fi
    fi

    # Check standard paths
    for path in "${search_paths[@]}"; do
        if [[ -n "$path" && -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Parse the status from a keeper decision file
# Args: $1 = path to decision file
# Returns: approved | rejected | deferred | pending | unknown
keeper_parse_decision_status() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "unknown"
        return 1
    fi

    local status
    status=$(grep -E '^\s*status:\s*' "$file" | head -1 | sed 's/.*status:\s*//' | tr -d '[:space:]"'"'" | tr '[:upper:]' '[:lower:]')

    echo "${status:-unknown}"
}

# Parse the ADR ID from a keeper decision file
# Args: $1 = path to decision file
# Returns: ADR ID (e.g., "ADR-003") or empty string
keeper_parse_decision_id() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    local adr_id
    adr_id=$(grep -E '^\s*id:\s*' "$file" | head -1 | sed 's/.*id:\s*//' | tr -d '[:space:]"'"'")

    echo "$adr_id"
}

# Parse constraints from a keeper decision file
# Args: $1 = path to decision file
# Returns: newline-separated list of constraints
keeper_parse_decision_constraints() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Extract constraints from keeper_decision block only
    # Find first "  constraints:" block and extract items until next field
    awk '
        /^  constraints:$/ && !found { found=1; next }
        found && /^    - / { gsub(/^    - /, ""); print }
        found && /^  [a-z]/ { exit }
    ' "$file" || true  # Don't fail if no constraints found
}

# Generate a new ADR from template
# Args: $1 = spec reference/description
#       $2 = optional output file (default: decisions/NNN-pending.yaml)
# Returns: path to generated file
keeper_generate_adr() {
    local spec_ref="$1"
    local output_file="${2:-}"

    mkdir -p "$DECISIONS_DIR"

    local adr_num
    adr_num=$(keeper_get_next_adr_number)
    local adr_id="ADR-${adr_num}"
    local today
    today=$(date +%Y-%m-%d)
    local mode
    mode=$(keeper_get_mode)

    # Default output file name
    if [[ -z "$output_file" ]]; then
        # Create a short name from spec (first 30 chars, alphanumeric only)
        local short_name
        short_name=$(echo "$spec_ref" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-30 | sed 's/-*$//')
        output_file="${DECISIONS_DIR}/${adr_num}-${short_name:-pending}.yaml"
    fi

    # Generate from template
    if [[ -f "$ADR_TEMPLATE" ]]; then
        sed -e "s/{NNN}/${adr_num}/g" \
            -e "s/{DATE}/${today}/g" \
            -e "s/{SPEC_REFERENCE}/${spec_ref}/g" \
            -e "s/{ADR_ID}/${adr_id}/g" \
            -e "s/{RATIONALE}/Pending review by Keeper of the Seeds./g" \
            -e "s/mode: growth/mode: ${mode}/" \
            "$ADR_TEMPLATE" > "$output_file"
    else
        # Inline template if file not found
        cat > "$output_file" << EOF
keeper_decision:
  id: ${adr_id}
  date: ${today}
  spec: "${spec_ref}"
  mode: ${mode}
  status: pending
  reuse:
    frontend: []
    backend: []
    data: []
    auth: []
  extensions: {}
  new_seeds: []
  forbidden: []
  constraints: []
  rationale: |
    Pending review by Keeper of the Seeds.

bead_frontmatter:
  keeper: "${adr_id}"
  constraints: []
EOF
    fi

    echo "$output_file"
}

# =============================================================================
# BEAD FRONTMATTER FUNCTIONS
# =============================================================================

# Generate bead frontmatter YAML from a keeper decision
# Args: $1 = path to decision file
# Outputs: YAML frontmatter for beads
keeper_generate_bead_frontmatter() {
    local decision_file="$1"

    if [[ ! -f "$decision_file" ]]; then
        keeper_log_error "Decision file not found: $decision_file"
        return 1
    fi

    local adr_id
    adr_id=$(keeper_parse_decision_id "$decision_file")

    local constraints
    constraints=$(keeper_parse_decision_constraints "$decision_file")

    # Output YAML format
    echo "---"
    echo "keeper: ${adr_id}"
    if [[ -n "$constraints" ]]; then
        echo "constraints:"
        echo "$constraints" | while IFS= read -r constraint; do
            echo "  - \"$constraint\""
        done
    else
        echo "constraints: []"
    fi
    echo "---"
}

# Output keeper result as YAML (for hook output)
# Args: $1 = status (approved|rejected|deferred|pending)
#       $2 = decision file path
#       $3 = optional message
keeper_output_result() {
    local status="$1"
    local decision_file="$2"
    local message="${3:-}"

    local adr_id=""
    local constraints=""

    if [[ -f "$decision_file" ]]; then
        adr_id=$(keeper_parse_decision_id "$decision_file")
        constraints=$(keeper_parse_decision_constraints "$decision_file" | head -5)
    fi

    cat << EOF
keeper_result:
  status: ${status}
  decision_file: "${decision_file}"
  bead_frontmatter:
    keeper: "${adr_id}"
    constraints:
$(echo "$constraints" | sed 's/^/      - "/;s/$/"/' | grep -v '^      - ""$' || echo '      []')
  message: |
    ${message:-Decision status: $status}
EOF
}

# =============================================================================
# SPEC ANALYSIS FUNCTIONS
# =============================================================================

# Analyze a spec for proposed changes (basic heuristic analysis)
# Args: $1 = spec content (from GT_CONVOY_SPEC or file)
# Outputs: categories detected (frontend, backend, data, auth)
keeper_analyze_spec_categories() {
    local spec="$1"

    local categories=()

    # Frontend indicators
    if echo "$spec" | grep -qiE 'component|button|modal|form|ui|view|page|screen|widget|icon'; then
        categories+=("frontend")
    fi

    # Backend indicators
    if echo "$spec" | grep -qiE 'api|route|endpoint|service|controller|handler|middleware'; then
        categories+=("backend")
    fi

    # Data indicators
    if echo "$spec" | grep -qiE 'database|schema|table|enum|field|migration|model|entity'; then
        categories+=("data")
    fi

    # Auth indicators
    if echo "$spec" | grep -qiE 'auth|login|logout|permission|scope|role|token|session|identity'; then
        categories+=("auth")
    fi

    # Output space-separated
    echo "${categories[*]}"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Create symlink to latest decision
# Args: $1 = path to decision file
keeper_link_latest() {
    local decision_file="$1"
    local latest="${DECISIONS_DIR}/latest.yaml"

    if [[ -f "$decision_file" ]]; then
        ln -sf "$(basename "$decision_file")" "$latest"
    fi
}

# Check if this library is being executed directly (for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Keeper Review Library v${KEEPER_LIB_VERSION}"
    echo "KEEPER_ROOT: ${KEEPER_ROOT}"
    echo "Seeds dir: $(keeper_get_seeds_dir)"
    echo "Mode: $(keeper_get_mode)"
    echo "Next ADR: $(keeper_get_next_adr_number)"

    if decision=$(keeper_find_decision); then
        echo "Current decision: $decision"
        echo "Status: $(keeper_parse_decision_status "$decision")"
    else
        echo "No current decision found"
    fi
fi
