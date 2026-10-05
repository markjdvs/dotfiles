# Switch a machine to skillshare agent context

One-off, for each machine that set up dotfiles before the skillshare change (`fb17924`). New machines just run `./init.sh`.

## 1. Pull

```bash
cd ~/src/personal/dotfiles
git status --short          # discard or commit local changes to claude/.claude/settings.json first
git pull --ff-only
```

## 2. Install skillshare

```bash
HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 brew install skillshare
```

Install it on its own rather than through `init.sh`. On macOS 14, Homebrew has no prebuilt packages, so `brew bundle` may start rebuilding outdated tools (and Rust/LLVM) from source. skillshare itself builds in seconds with Go.

## 3. Clear the old layout

```bash
mv ~/.claude/skills ~/.claude/skills.pre-skillshare     # backup; delete once all is well
for l in agents commands rules CLAUDE.md; do
  [ -L ~/.claude/$l ] && [ ! -e ~/.claude/$l ] && rm ~/.claude/$l   # broken links only
done
npx -y skills@latest remove --all -g -y                 # old vercel-installed skills
ls -A ~/.agents/skills                                  # should be empty
```

## 4. Stow, link, sync

```bash
cd ~/src/personal/dotfiles
stow -n -v -d . -t ~ claude skillshare   # dry run: expect only LINK lines
stow -d . -t ~ claude skillshare
mkdir -p ~/.agents/skills
ln -sfn ~/.agents/skills ~/.claude/skills
skillshare sync --all
```

## 5. Check

```bash
ls -la ~/.claude/skills ~/.claude/CLAUDE.md ~/.claude/hooks   # all links into dotfiles or ~/.agents/skills
ls ~/.agents/skills                                           # one link per skill in agents/skills
skillshare doctor                                             # only warnings: theme, uncommitted git, "Skill not found"
skillshare diff                                               # no "Local only" or "Local override"
```

Then start a new Claude Code session. The skill list should show only the dotfiles skills: no Claude Code built-ins, no `anthropic-skills:*`.

## 6. Tidy up

- Delete `~/.claude/skills.pre-skillshare` once everything works.
- Cursor: paste `agents/AGENTS.md` into Settings → Rules → User Rules (it has no global instructions file).
