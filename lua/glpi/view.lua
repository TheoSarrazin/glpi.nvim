local config = require("glpi.config")
local api = require("glpi.api")
local M = {}

M.windows = {
	main = {
		win = nil,
		buf = nil,
	},
	sidebar = {
		win = nil,
		buf = nil,
	},
	searchbar = {
		win = nil,
		buf = nil,
	},
}

local followup_bufs = {
	solution = nil,
	followup = nil,
}

local augroup = vim.api.nvim_create_augroup("GLPI-group", { clear = true })

local function close_ui(window_type)
	local function close_win(win)
		local wins = vim.api.nvim_list_wins()
		if #wins == 1 then
			return
		end
		if win ~= nil and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	local function close_buf(current_buf)
		if current_buf ~= nil and vim.api.nvim_buf_is_valid(current_buf) then
			vim.api.nvim_buf_delete(current_buf, { force = true })
		end
	end

	if window_type ~= "main" then -- when leaving non main window, close this window
		close_buf(M.windows[window_type].buf)
		close_win(M.windows[window_type].win)
		M.windows[window_type].win = nil
		M.windows[window_type].buf = nil
		return
	end

	for _, win in pairs(vim.tbl_keys(M.windows)) do -- else, we are leaving main, so we close all the UI
		close_buf(M.windows[win].buf)
		close_win(M.windows[win].win)
		M.windows[win].win = nil
		M.windows[win].buf = nil
	end
end

local function create_buf(window_type)
	local buf = M.windows[window_type].buf
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, { force = true })
	end

	buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
	vim.api.nvim_set_option_value("wrap", true, { win = M.windows[window_type].win })
	vim.keymap.set("n", "q", function()
		close_ui(window_type)
	end, { buffer = buf })

	return buf
end

local function open_floating_win(opts)
	opts = opts or {}

	local width = opts.width or math.floor(vim.o.columns * 0.8)
	local height = opts.height or math.floor(vim.o.lines * 0.8)
	local col = (vim.o.columns - width) / 2
	local row = (vim.o.lines - height) / 2
	local border = opts.border or "rounded"
	local title = opts.title

	local buf = opts.buf

	if buf == nil or vim.api.nvim_buf_is_valid(buf) == false then
		buf = vim.api.nvim_create_buf(false, true)
	end

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		width = width,
		height = height,
		col = col,
		row = row,
		title = title,
		title_pos = "center",
		border = border,
	})

	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	return win, buf
end

local function open_win(opts)
	opts = opts or {}

	local window_type = opts.window_type or "main"
	local buf = create_buf(window_type)

	local win = M.windows[window_type].win

	if window_type == "main" then
		win = win or vim.api.nvim_get_current_win()
	else
		if win == nil then
			vim.api.nvim_command("vsplit")
			win = vim.api.nvim_get_current_win()
		end
	end

	vim.api.nvim_create_autocmd("WinClosed", {
		group = augroup,
		pattern = tostring(win),
		callback = function()
			close_ui(window_type)
		end,
	})

	vim.api.nvim_win_set_buf(win, buf)

	M.windows[window_type].win = win
	M.windows[window_type].buf = buf

	return win, buf
end

local function add_followup(title, buf, callbacks)
	callbacks = callbacks or {}

	local win = nil
	win, buf = open_floating_win({ buf = buf, title = title })

	if callbacks.on_validation ~= nil then
		local function on_validation()
			local content = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
			local str_content = table.concat(content, "\n")
			callbacks.on_validation(str_content)
			vim.api.nvim_win_close(win, true)
		end

		vim.keymap.set("n", "<cr>", on_validation, { buffer = buf })
		vim.keymap.set("i", "<c-s>", on_validation, { buffer = buf })
	end

	return win, buf
end

local function format_tickets_view(tickets)
	local lines = {}

	local function insert_tickets(title, tickets_list)
		if tickets_list ~= nil and #tickets_list > 0 then
			table.insert(lines, "# " .. title .. " (" .. #tickets_list .. ")")
			table.insert(lines, "")
			for _, ticket in ipairs(tickets_list) do
				local ticket_4 = ticket["4"]
				local name = type(ticket_4) == "table" and ticket_4[1] or ticket_4

				table.insert(lines, "- " .. ticket["1"] .. " (" .. ticket["12"] .. " | " .. name .. ")")
			end
			table.insert(lines, "")
			table.insert(lines, "")
		end
	end

	insert_tickets("Nouveau Tickets", tickets.new)

	if config.separate_pending_processing then
		insert_tickets("Mes tickets en cours", tickets.my.processing)
		insert_tickets("Mes tickets en attente", tickets.my.pending)
	else
		insert_tickets("Mes tickets", tickets.my)
	end

	insert_tickets("Autres tickets", tickets.other)

	return lines
end

function M.open_tab()
	vim.api.nvim_command("tabnew")
end

function M.open_tickets(tickets, callbacks)
	callbacks = callbacks or {}

	local win, buf = open_win()

	vim.api.nvim_buf_set_name(buf, "GLPI")

	if callbacks.on_quit then
		vim.api.nvim_create_autocmd("WinClosed", {
			group = augroup,
			pattern = tostring(win),
			callback = callbacks.on_quit,
		})
		vim.api.nvim_create_autocmd("ExitPre", {
			group = augroup,
			callback = function()
				if api.options.session_token == nil then
					return
				end
				callbacks.on_quit()
			end,
		})
	end

	local lines = format_tickets_view(tickets)
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

	vim.api.nvim_win_set_cursor(win, { 3, 0 })

	if callbacks.on_selection ~= nil then
		vim.keymap.set("n", "<CR>", function()
			callbacks.on_selection(win, buf)
		end, { buffer = buf })
	end
end

function M.update_tickets(tickets)
	local buf = M.windows.main.buf

	if buf == nil then
		return
	end

	local lines = format_tickets_view(tickets)
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
end

function M.open_ticket(ticket, callbacks)
	callbacks = callbacks or {}

	-- Reset buffers, new ticket = new buffer
	followup_bufs.followup = nil
	followup_bufs.solution = nil

	local title = ticket.title

	local _, buf = open_win({ window_type = "sidebar" })
	vim.api.nvim_buf_set_name(buf, title)

	local lines = {}

	table.insert(lines, "# " .. title .. " (" .. ticket.status .. ")")
	table.insert(lines, "")
	table.insert(lines, "## Le " .. ticket.creation_date .. ", " .. ticket.users[1] .. " a écrit : ")
	table.insert(lines, "")

	for _, line in ipairs(vim.split(ticket.content, "\n")) do
		table.insert(lines, line)
	end

	if #ticket.followups > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Suivi")
		table.insert(lines, "")

		for _, followup in ipairs(ticket.followups) do
			local private = followup.is_private == 1 and "🔒" or ""
			table.insert(
				lines,
				"### " .. private .. " Le " .. followup.date_creation .. ", " .. followup.user .. " a écrit :"
			)
			table.insert(lines, "")
			for _, line in ipairs(vim.split(followup.content, "\n")) do
				table.insert(lines, line)
			end
			table.insert(lines, "")
		end
	end

	if #ticket.observers > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Observateur(s) sur le ticket")
		table.insert(lines, "")
		for _, observer in ipairs(ticket.observers) do
			table.insert(lines, "- " .. observer)
		end
	end

	if #ticket.tech_names > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Technicien(s) sur le ticket")
		table.insert(lines, "")
		for _, tech in ipairs(ticket.tech_names) do
			table.insert(lines, "- " .. tech)
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

	if callbacks.on_selection ~= nil then
		vim.keymap.set("n", "<CR>", callbacks.on_selection, { buffer = buf })
	end

	if callbacks.on_solution ~= nil then
		vim.keymap.set("n", config.keymaps.add_solution, function()
			M.open_solution({ on_validation = callbacks.on_solution })
		end, { buffer = buf })
	end

	if callbacks.on_followup ~= nil then
		vim.keymap.set("n", config.keymaps.add_followup, function()
			M.open_followup({ on_validation = callbacks.on_followup })
		end, { buffer = buf })
	end

	if callbacks.on_attribution ~= nil then
		vim.keymap.set("n", config.keymaps.attribution, callbacks.on_attribution, { buffer = buf })
	end

	if callbacks.on_attribution_to_me ~= nil then
		vim.keymap.set("n", config.keymaps.attribution_to_me, callbacks.on_attribution_to_me, { buffer = buf })
	end

	if callbacks.on_next ~= nil then
		vim.keymap.set("n", config.keymaps.next_ticket, function()
			callbacks.on_next(M.windows.main.win, M.windows.main.buf)
		end, { buffer = buf })
	end

	if callbacks.on_prev ~= nil then
		vim.keymap.set("n", config.keymaps.prev_ticket, function()
			callbacks.on_prev(M.windows.main.win, M.windows.main.buf)
		end, { buffer = buf })
	end
end

function M.open_solution(callbacks)
	local _, buf = add_followup("Solution", followup_bufs.solution, callbacks)
	followup_bufs.solution = buf
end

function M.open_followup(callbacks)
	local _, buf = add_followup("Suivi", followup_bufs.followup, callbacks)
	followup_bufs.followup = buf
end

function M.main_is_open()
	return M.windows.main.win ~= nil and vim.api.nvim_win_is_valid(M.windows.main.win)
end

return M
