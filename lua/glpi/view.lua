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

local function close_ui()
	local function close_win(win)
		if win ~= nil and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	close_win(M.windows.main.win)
	M.windows.main.win = nil

	close_win(M.windows.sidebar.win)
	M.windows.sidebar.win = nil

	close_win(M.windows.searchbar.win)
	M.windows.searchbar.win = nil
end

local function create_buf()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
	vim.keymap.set("n", "q", close_ui, { buffer = buf })
	return buf
end

local function get_width(win_type)
	local sidebar_win = M.windows.sidebar.win
	if win_type == "main" and sidebar_win ~= nil and vim.api.nvim_win_is_valid(sidebar_win) then
		return math.floor(vim.o.columns * 0.8 * 0.66)
	end
	return math.floor(vim.o.columns * 0.8)
end

local function get_height(win_type)
	local searchbar_win = M.windows.searchbar.win
	local height = math.floor(vim.o.lines * 0.8)
	if win_type == "main" and searchbar_win ~= nil and vim.api.nvim_win_is_valid(searchbar_win) then
		return height - 3
	end
	return height
end

local function open_win(opts)
	opts = opts or {}
	local window_type = opts.window_type or "main"

	local buf = M.windows[window_type].buf or create_buf()

	local function create_win()
		local border = opts.border or "rounded"
		local style = opts.style or "minimal"
		local width = opts.width or get_width(window_type)
		local height = opts.height or get_height(window_type)
		local col = math.floor((vim.o.columns - width) / 2)
		local row = math.floor((vim.o.lines - height) / 2)
		return vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = width,
			height = height,
			col = col,
			row = row,
			border = border,
			style = style,
		})
	end

	local win = M.windows[window_type].win or create_win()

	M.windows[window_type].win = win
	M.windows[window_type].buf = buf

	return win, buf
end

function M.open_tickets(tickets, callbacks)
	callbacks = callbacks or {}

	local win, buf = open_win()

	local lines = {}

	local function insert_tickets(title, tickets)
		if tickets ~= nil and #tickets > 0 then
			table.insert(lines, "# " .. title)
			table.insert(lines, "")
			for _, ticket in ipairs(tickets) do
				table.insert(lines, "- " .. ticket)
			end
			table.insert(lines, "")
			table.insert(lines, "")
		end
	end

	insert_tickets("Nouveau Tickets", tickets.new)
	insert_tickets("Mes tickets", tickets.my)
	insert_tickets("Autres tickets", tickets.other)

	vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

	if callbacks.on_selection ~= nil then
		vim.keymap.set("n", "<CR>", function()
			callbacks.on_selection(win, buf)
		end, { buffer = buf })
	end
end

return M
