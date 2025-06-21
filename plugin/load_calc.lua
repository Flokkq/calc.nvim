desc =

vim.api.nvim_create_user_command('CalcHistory', function()
  require('calc').fuzzy_history()
end, {
    desc = 'View fuzzy history for Calcuator'
})

vim.api.nvim_create_user_command("CalcOpen", function()
	require("calc").open()
end, {
    desc = 'Open lua powered calculator in floating window',
})

vim.api.nvim_create_user_command('CalcListVars', function()
  require('calc').list_vars()
end, { desc = 'List all defined variables for Calculator'})

vim.api.nvim_create_user_command('CalcClearVars', function()
  require('calc').clear_vars()
end, { desc = "Delete ALL defined variables in Calculaotor history"})

vim.keymap.set("n", "<leader>clo", "<Cmd>CalcOpen<CR>", {
    silent = true,
    noremap = true,
    desc = 'Open lua powered calculator in floating window',
})


vim.keymap.set("n", "<leader>clh", "<Cmd>CalcHistory<CR>", {
    silent = true,
    noremap = true,
    desc = 'View fuzzy history for Calcuator'
})

vim.keymap.set("n", "<leader>clv", "<Cmd>CalcListVars<CR>", {
    silent=true,
    noremap=true,
    desc = 'List all defined variables for Calculator'
})
