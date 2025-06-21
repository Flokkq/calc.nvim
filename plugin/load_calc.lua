desc = 'Open lua powered calculator in floating window'

vim.api.nvim_create_user_command("CalcOpen", function()
	require("calc").open()
end, {
    desc = desc,
})

vim.keymap.set("n", "<leader>lo", "<Cmd>CalcOpen<CR>", {
    silent = true,
    noremap = true,
    desc = desc,
})
