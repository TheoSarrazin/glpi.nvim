local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local state = require("telescope.actions.state")
local conf = require("telescope.config").values

local api = require("glpi.api")
local config = require("glpi.config")
local glpi = require("glpi")

local separate_pending_processing = config.separate_pending_processing
local tickets = {}

local function get_tickets()
	tickets = {}

	local function extract_ticket(t)
		for _, ticket in ipairs(t) do
			local id = ticket["2"]
			local name = ticket["1"] .. " (" .. ticket["4"] .. ")"
			tickets[name] = id
		end
	end

	extract_ticket(api.tickets.new)
	if separate_pending_processing then
		extract_ticket(api.tickets.my.pending)
		extract_ticket(api.tickets.my.processing)
	else
		extract_ticket(api.tickets.my)
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
			sorter = conf.generic_sorter(),
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
