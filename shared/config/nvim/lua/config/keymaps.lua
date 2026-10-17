-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Carried over from the old vimrc where they do not collide with a LazyVim
-- leader group (<leader>s search, <leader>f file, <leader>d debug, <leader>g git).

local map = vim.keymap.set

map("n", "<leader><leader>", "<C-^>", { desc = "Alternate file" })
map("n", "<C-p>", LazyVim.pick("files"), { desc = "Find files" })
map("n", "\\", LazyVim.pick("live_grep"), { desc = "Grep" })

-- Dot and macros over a visual selection
map("x", ".", ":normal .<CR>", { desc = "Repeat over selection" })
map("x", "@", function()
  return ":normal @" .. vim.fn.getcharstr() .. "<CR>"
end, { expr = true, desc = "Macro over selection" })
