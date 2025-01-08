vim.api.nvim_create_user_command("Glpi", function()
	require("telescope").extensions.glpi.tickets()
end, { desc = "Open a telescope picker to iterate over open tickets" })
