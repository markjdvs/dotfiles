-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Per-worktree ShaDa. Every Task session runs its own `nvim`, and they all
-- shared one global shada file — concurrent instances race on the write-tmp-
-- then-rename dance, orphaning `.tmp.a`..`.tmp.z` until the 26-slot budget is
-- exhausted (E138) and the file corrupts (E576). Keying the shada path to the
-- git root gives exactly one writer per file, so the race cannot happen.
local root = vim.fs.root(0, ".git") or (vim.uv or vim.loop).cwd()
if root then
  local dir = vim.fn.stdpath("state") .. "/shada"
  vim.fn.mkdir(dir, "p")
  vim.o.shadafile = dir .. "/" .. root:gsub("[^%w]", "%%") .. ".shada"
end
