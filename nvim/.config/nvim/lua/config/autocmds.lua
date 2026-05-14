-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Reload buffers and refresh gitsigns when switching back from another tmux pane
-- (e.g. after Claude Code or Cursor modifies files on disk)
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("external_file_changes", { clear = true }),
  callback = function()
    vim.cmd("checktime")
    -- refresh gitsigns for all visible buffers
    if package.loaded["gitsigns"] then
      require("gitsigns").refresh()
    end
  end,
})
