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

# Claude Code reads skills only from ~/.claude/skills; Codex, Cursor and most
# other harnesses read ~/.agents/skills. Making the former a link to the latter
# gives every harness one skills dir, which skillshare fills below. Linking
# both separately would make Cursor (which reads both) list every skill twice.
if [ -d "$HOME/.claude/skills" ] && [ ! -L "$HOME/.claude/skills" ]; then
  echo "~/.claude/skills is a real directory. Move it aside and re-run." >&2
  exit 1
fi
mkdir -p "$HOME/.agents/skills"
ln -sfn "$HOME/.agents/skills" "$HOME/.claude/skills"

echo "==> Syncing agent context"
skillshare sync --all
