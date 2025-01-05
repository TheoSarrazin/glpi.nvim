local config = require("glpi.config")
local view = require("glpi.view")
local api = require("glpi.api")
local M = {}

function M.setup(opts)
	config.setup(opts)
end

function M.init()
	view.open_tickets(api.tickets, {
		on_selection = function(win, buf)
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
			local current_line = vim.api.nvim_get_current_line()
			local ticket_number = 0
			local search = "- "

			for _, line in ipairs(lines) do
				if string.sub(line, 1, #search) == search then
					ticket_number = ticket_number + 1
				end
				if current_line == line then
					break
				end
			end

			print(api.get_ticket(ticket_number))
		end,
	})
end

return M
