#!/bin/bash
# Keeper Installation Script
# Sets up the bd wrapper to invoke keeper PostBeadCreate hooks
#
# Usage: ./install/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEEPER_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🌱 Keeper of the Seeds - Installation"
echo ""

# Find a suitable PATH location
INSTALL_DIR=""
for dir in "$HOME/.local/bin" "$HOME/bin" "$HOME/.amp/bin"; do
    if [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null; then
        # Check if this dir is in PATH and comes before homebrew
        if echo "$PATH" | tr ':' '\n' | grep -q "^$dir$"; then
            # Check if it comes before /opt/homebrew/bin
            BEFORE_HOMEBREW=$(echo "$PATH" | tr ':' '\n' | grep -nE "^($dir|/opt/homebrew/bin)$" | head -1 | cut -d: -f2)
            if [[ "$BEFORE_HOMEBREW" == "$dir" ]]; then
                INSTALL_DIR="$dir"
                break
            fi
        fi
    fi
done

if [[ -z "$INSTALL_DIR" ]]; then
    # Fallback - create ~/.local/bin and warn about PATH
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    echo "⚠️  Warning: $INSTALL_DIR may not be in your PATH before /opt/homebrew/bin"
    echo "   Add this to your shell profile:"
    echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
fi

# Install the bd wrapper
echo "📦 Installing bd wrapper to $INSTALL_DIR..."
cp "$SCRIPT_DIR/bd-wrapper" "$INSTALL_DIR/bd"
chmod +x "$INSTALL_DIR/bd"

# Verify installation
if which bd | grep -q "$INSTALL_DIR"; then
    echo "✓ bd wrapper installed successfully"
    echo "  Location: $INSTALL_DIR/bd"
else
    echo "⚠️  bd wrapper installed but may not be first in PATH"
    echo "  Installed to: $INSTALL_DIR/bd"
    echo "  Current bd: $(which bd)"
fi

echo ""
echo "🌱 Keeper installation complete!"
echo ""
echo "Next steps:"
echo "  1. Copy keeper.yaml to your rig root"
echo "  2. Copy seeds/*.yaml templates to your rig"
echo "  3. Run 'bd create' - keeper will now generate decisions"
