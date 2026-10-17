-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Only what differs from LazyVim is here; 2-space soft tabs, relative numbers,
-- smartcase and right/below splits are already its defaults.

local opt = vim.opt

opt.textwidth = 80
opt.colorcolumn = "+1"
opt.listchars = { tab = "»·", trail = "·", nbsp = "·" }
opt.swapfile = false
opt.background = "dark"

-- Files the old vimrc forced to a filetype that nvim does not detect itself.
vim.filetype.add({
  filename = {
    aliases = "sh",
    shellrc = "sh",
    DockerQA = "dockerfile",
    ["DockerQA-B"] = "dockerfile",
    DockerTest = "dockerfile",
    HistoricalSyncDockerfile = "dockerfile",
  },
})
