local config = require("glpi.config")
local view = require("glpi.view")
local api = require("glpi.api")

local M = {}

local function browse_ticket(ticket)
    os.execute("open " .. config.base_url .. "/front/ticket.form.php?id=" .. ticket.id)
end

function M.setup(opts)
	config.setup(opts)
end

function M.load_tickets()
	view.open_tab()
	view.open_tickets(api.tickets, {
		on_quit = function()
			api.kill_session()
		end,
		on_selection = function()
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

			local ticket = api.get_ticket(ticket_number)
			ticket = api.get_ticket_id(ticket["2"])

			view.open_ticket(ticket, {
				on_selection = function()
					browse_ticket(ticket)
				end,
			})
		end,
	})
end

return M
