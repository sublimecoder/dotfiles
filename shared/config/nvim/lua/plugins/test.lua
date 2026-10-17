-- vim-test, run in the herdr pane below the editor (hdl's terminal pane), or in
-- a nvim terminal split when nvim is not inside herdr. Keys follow LazyVim's
-- <leader>t test group instead of the old bare <leader>t/s/l/a, because
-- <leader>s and <leader>l are LazyVim groups.
return {
  "vim-test/vim-test",
  cmd = { "TestFile", "TestNearest", "TestLast", "TestSuite", "TestVisit" },
  keys = {
    { "<leader>tt", "<cmd>TestFile<cr>", desc = "Test file" },
    { "<leader>tr", "<cmd>TestNearest<cr>", desc = "Test nearest" },
    { "<leader>tl", "<cmd>TestLast<cr>", desc = "Test last" },
    { "<leader>tT", "<cmd>TestSuite<cr>", desc = "Test suite" },
    { "<leader>tv", "<cmd>TestVisit<cr>", desc = "Visit last test file" },
  },
  init = function()
    vim.g["test#custom_strategies"] = {
      herdr = function(cmd)
        vim.fn.jobstart({ "herdr-run-below", cmd }, {
          on_exit = function(_, code)
            if code ~= 0 then
              vim.notify("herdr-run-below failed (" .. code .. "): " .. cmd, vim.log.levels.ERROR)
            end
          end,
        })
      end,
    }
    vim.g["test#strategy"] = vim.env.HERDR_PANE_ID and "herdr" or "neovim"
  end,
}
