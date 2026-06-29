#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS=(claude cursor)

is_ours() {
  [ -L "$1" ] && [[ "$(realpath "$1" 2>/dev/null)" == "$REPO_DIR/"* ]]
}

iterate_items() {
  local source_dir="$1" target_dir="$2" callback="$3"

  for item in "$source_dir"/*; do
    [ -e "$item" ] || continue
    [[ "$(basename "$item")" == ".gitkeep" ]] && continue
    "$callback" "$item" "$target_dir/$(basename "$item")"
  done
}

for_each_item() {
  local callback="$1"

  for tool in "${TOOLS[@]}"; do
    local target="$HOME/.$tool"

    for type_dir in "$REPO_DIR"/skills "$REPO_DIR"/agents; do
      [ -d "$type_dir" ] || continue
      iterate_items "$type_dir" "$target/$(basename "$type_dir")" "$callback"
    done
  done
}

install() {
  local has_conflicts=0

  check_conflict() {
    local source="$1" target="$2"
    if [ -e "$target" ] || [ -L "$target" ]; then
      is_ours "$target" && return 0
      echo "  conflict: $target" >&2
      has_conflicts=1
    fi
  }
  for_each_item check_conflict
  [ "$has_conflicts" -eq 0 ] || exit 1

  create_link() {
    local source="$1" target="$2"
    mkdir -p "$(dirname "$target")"
    ln -sfn "$source" "$target"
    echo "  linked: $target"
  }
  for_each_item create_link
}

uninstall() {
  remove_link() {
    local source="$1" target="$2"
    if is_ours "$target"; then
      rm "$target"
      echo "  removed: $target"
    fi
  }
  for_each_item remove_link
}

status() {
  local issues=0

  check_status() {
    local source="$1" target="$2"
    if is_ours "$target"; then
      echo "  ok: $target"
    elif [ -e "$target" ] || [ -L "$target" ]; then
      echo "  conflict: $target" >&2
      issues=$((issues + 1))
    else
      echo "  missing: $target" >&2
      issues=$((issues + 1))
    fi
  }
  for_each_item check_status

  if [ "$issues" -gt 0 ]; then
    echo "Run ./agents/install.sh install to fix" >&2
    exit 1
  fi
}

case "${1:-}" in
  install)   install ;;
  uninstall) uninstall ;;
  status)    status ;;
  *)         echo "Usage: $(basename "$0") {install|uninstall|status}"; exit 1 ;;
esac
