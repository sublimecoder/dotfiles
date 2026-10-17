-- Fugitive for :G habits; LazyVim already brings gitsigns and lazygit (<leader>gg).
return {
  {
    "tpope/vim-fugitive",
    dependencies = { "tpope/vim-rhubarb" },
    cmd = { "G", "Git", "Gdiffsplit", "Gread", "Gwrite", "GBrowse" },
  },
}
