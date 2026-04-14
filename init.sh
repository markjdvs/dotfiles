#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Homebrew packages"
brew bundle install --file="$DOTFILES_DIR/Brewfile"

for dir in "$DOTFILES_DIR"/*/; do
  name="$(basename "$dir")"

  if [ -f "$dir/install.sh" ]; then
    echo "==> Running $name/install.sh"
    "$dir/install.sh" install
  elif ls -A "$dir" | grep -q '^\.' 2>/dev/null; then
    echo "==> Stowing $name"
    stow -d "$DOTFILES_DIR" -t "$HOME" "$name"
  fi
done
