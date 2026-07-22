# Agent-Agnostic Dotfiles Setup

This repository uses a shared `agents/.agents/` directory for agent-agnostic content (skills, agents, rules, commands) that works across multiple AI coding tools (Claude, Cursor, etc.).

## Quick Start

### Initial Setup

```bash
cd ~/src/personal/dotfiles

# Initialize symlinks within dotfiles
./init.sh

# Apply to your home directory with stow
stow claude
stow cursor
```

### Enable Automatic Initialization

To automatically run `init.sh` after pulling changes:

```bash
cd ~/src/personal/dotfiles
git config core.hooksPath .git-hooks
```

This will run the post-merge hook that executes `init.sh` automatically.

## Directory Structure

```
dotfiles/
├── agents/
│   └── .agents/          # ← Shared agent-agnostic content (version controlled)
│       ├── agents/       # Custom agents
│       ├── skills/       # Custom skills
│       ├── rules/        # Shared rules
│       └── commands/     # Shared commands
│
├── claude/
│   └── .claude/
│       ├── settings.json     # Claude-specific settings
│       ├── agents -> ../../agents/.agents/agents  # Symlink
│       ├── skills -> ../../agents/.agents/skills  # Symlink
│       └── rules  -> ../../agents/.agents/rules   # Symlink
│
└── cursor/
    └── .cursor/
        ├── settings.json     # Cursor-specific settings
        ├── agents -> ../../agents/.agents/agents  # Symlink
        └── skills -> ../../agents/.agents/skills  # Symlink
```

## Project-Specific Setup

To link shared agents to a specific project:

```bash
# For Claude
setup-project-agents ~/projects/myapp claude

# For Cursor
setup-project-agents ~/projects/myapp cursor

# Or use current directory
cd ~/projects/myapp
setup-project-agents . claude
```

This creates symlinks in the project's `.claude/` or `.cursor/` directory pointing to the shared agents.

## How It Works

1. **Shared content** lives in `agents/.agents/`
2. **Tool-specific configs** live in `claude/.claude/`, `cursor/.cursor/`, etc.
3. **Symlinks within dotfiles** point from tool configs to shared content
4. **Stow** propagates these symlinks to `$HOME`
5. **Result**: `~/.claude/agents` → `~/src/personal/dotfiles/agents/.agents/agents`

## Benefits

- ✅ Single source of truth for agents, skills, and rules
- ✅ Works across multiple AI coding tools
- ✅ Version controlled (symlinks are committed to git)
- ✅ Portable (works on any machine after cloning)
- ✅ No duplication between tools
- ✅ Easy to extend to new tools

## Scripts

- `init.sh` - Initialize symlinks within dotfiles (run after clone/pull)
- `bin/setup-project-agents` - Link shared agents to a project directory
- `.git-hooks/post-merge` - Auto-run init.sh after git pull
