local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local state = require("telescope.actions.state")

local api = require("glpi.api")
local config = require("glpi.config")
local glpi = require("glpi")

local separate_pending_processing = config.separate_pending_processing
local tickets = {}

local function get_tickets()
	tickets = {}

	local function extract_ticket(t)
		for _, ticket in ipairs(t) do
			tickets[ticket["1"]] = ticket["2"]
		end
	end

	extract_ticket(api.tickets.new)
	if separate_pending_processing then
		extract_ticket(api.tickets.new.pending)
		extract_ticket(api.tickets.new.processing)
	else
		extract_ticket(api.tickets.new)
	end
	extract_ticket(api.tickets.other)

	return vim.tbl_keys(tickets)
end

return function()
	pickers
		.new(nil, {
			prompt_title = "Tickets en attente",
			finder = finders.new_table({
				results = get_tickets(),
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)

					local selection = state.get_selected_entry()
					local ticket_id = tickets[selection[1]]
					local ticket = api.get_ticket_id(ticket_id)
					glpi.load_tickets()
					glpi.load_ticket(ticket)
				end)
				return true
			end,
		})
		:find()
end
