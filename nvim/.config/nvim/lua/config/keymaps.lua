-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- Split windows
keymap.set("n", "ss", ":vsplit<Return>", opts)
keymap.set("n", "sv", ":split<Return>", opts)
