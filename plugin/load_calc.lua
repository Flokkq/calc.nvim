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
