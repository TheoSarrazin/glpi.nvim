local config = require("glpi.config")
local view = require("glpi.view")
local api = require("glpi.api")
local utils = require("glpi.utils")

local M = {}

local function browse_ticket(ticket)
	local commands = {
		Linux = "xdg-open",
		Windows = "start",
		Darwin = "open",
	}

	---@diagnostic disable-next-line: undefined-field
	local os_type = vim.loop.os_uname().sysname

	os.execute(commands[os_type] .. " " .. config.base_url .. "/front/ticket.form.php?id=" .. ticket.id)
end

local function select_ticket(win, buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
	local cursor = vim.api.nvim_win_get_cursor(win)
	local ticket_number = 0
	local search = "- "

	for i, line in ipairs(lines) do
		if string.sub(line, 1, #search) == search then
			ticket_number = ticket_number + 1
		end
		if i == cursor[1] then
			break
		end
	end

	local ticket = api.get_ticket(ticket_number)
	ticket = api.get_ticket_id(ticket["2"])

	M.load_ticket(ticket)
end

local function reload_tickets()
	api.update_tickets()
	view.update_tickets(api.tickets)
end

function M.setup(opts)
	config.setup(opts)
	utils.setup()

	vim.keymap.set("n", config.keymaps.reload_ticket, reload_tickets, {})
	vim.keymap.set("n", config.keymaps.toggle_separation, function()
		config.toggle_processing_pending_separation()
		reload_tickets()
	end, {})
end

function M.load_tickets()
	if view.main_is_open() then
		return
	end

	view.open_tab()
	local buf = vim.api.nvim_get_current_buf() -- (1) get the buffer created by the tab

	view.open_tickets(api.tickets, {
		on_quit = function()
			api.kill_session()
		end,
		on_selection = select_ticket,
	})

	vim.api.nvim_buf_delete(buf, { force = true }) -- (2) When UI is load, close the buffer
end

function M.load_ticket(ticket)
	view.open_ticket(ticket, {
		on_selection = function()
			browse_ticket(ticket)
		end,
		on_solution = function(content)
			api.add_solution(content, ticket)
		end,
		on_followup = function(content)
			api.add_followup(content, ticket)
		end,
		on_attribution = function()
			local techs = api.techs
			vim.ui.select(vim.tbl_keys(techs), { prompt = "Veuillez choisir un technicien" }, function(user)
				if user == nil then
					return
				end
				api.attribute_ticket_to(ticket, techs[user])
			end)
		end,
		on_attribution_to_me = function()
			api.attribute_ticket_to(ticket, api.options.user_id)
		end,
		on_next = function(w, b)
			local lcursor = vim.api.nvim_win_get_cursor(w)
			lcursor[1] = lcursor[1] + 1
			vim.api.nvim_win_set_cursor(w, lcursor)
			select_ticket(w, b)
		end,
		on_prev = function(w, b)
			local lcursor = vim.api.nvim_win_get_cursor(w)
			lcursor[1] = lcursor[1] - 1
			if lcursor[1] < 0 then
				lcursor[1] = 0
			end
			vim.api.nvim_win_set_cursor(w, lcursor)
			select_ticket(w, b)
		end,
	})
end

return M
