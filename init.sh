#!/usr/bin/env bash
# dotfiles/init.sh - Initialize symlinks for agent-agnostic content
# Run this after cloning or pulling the repository

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="agents/.agents"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}→${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}⊙${NC} $1"
}

# Create symlink if it doesn't exist or points to wrong target
create_symlink() {
    local target=$1
    local link_name=$2
    local link_dir=$(dirname "$link_name")

    # Create parent directory if needed
    mkdir -p "$link_dir"

    # Check if symlink already exists and is correct
    if [ -L "$link_name" ] && [ "$(readlink "$link_name")" = "$target" ]; then
        log_skip "$(basename $(dirname "$link_name"))/$(basename "$link_name") already linked"
        return 0
    fi

    # Remove existing file/symlink if present
    if [ -e "$link_name" ] || [ -L "$link_name" ]; then
        rm -rf "$link_name"
    fi

    # Create symlink
    ln -sf "$target" "$link_name"
    log_success "$(basename $(dirname "$link_name"))/$(basename "$link_name") → $target"
}

# Setup symlinks for a specific tool
setup_tool() {
    local tool=$1
    local tool_config_dir="$DOTFILES_DIR/$tool/.$tool"

    log_info "Setting up $tool"

    # Check if tool config directory exists
    if [ ! -d "$tool_config_dir" ]; then
        echo "  Warning: $tool config directory not found, skipping"
        return 0
    fi

    # Link each shared directory
    for dir in agents skills rules commands; do
        if [ -d "$DOTFILES_DIR/$AGENTS_DIR/$dir" ]; then
            create_symlink "../../$AGENTS_DIR/$dir" "$tool_config_dir/$dir"
        fi
    done

    echo ""
}

main() {
    echo ""
    log_info "Initializing dotfiles agent symlinks"
    echo ""

    # Verify agents directory exists
    if [ ! -d "$DOTFILES_DIR/$AGENTS_DIR" ]; then
        echo "Error: Agents directory not found at $DOTFILES_DIR/$AGENTS_DIR"
        exit 1
    fi

    # Setup for each tool
    setup_tool "claude"
    setup_tool "cursor"

    log_success "Initialization complete"
    echo ""
    log_info "Next steps:"
    echo "  cd $DOTFILES_DIR"
    echo "  stow claude"
    echo "  stow cursor"
    echo ""
}

main "$@"
