local curl = require("plenary.curl")
local config = require("glpi.config")
local utils = require("glpi.utils")
local M = {}

M.options = {
	session_token = nil,
	user_id = nil,
}

local ticket_status = {
	Nouveau = 1,
	En_cours = 2,
	En_attente = 4,
	Resolu = 5,
	Ferme = 6,
}

M.tickets = nil
M.techs = nil

local function clean_content(content)
	content = content:gsub("&#38;nbsp;", "")
	content = content:gsub("&#60;strong&#62;", "**")
	content = content:gsub("&#60;/strong&#62;", "**")
	content = content:gsub("&#60;br&#62;", "\n")
	content = content:gsub("&lt;p&gt;", "")
	content = content:gsub("&lt;/p&gt;", "\n")
	content = content:gsub("\r\n", "\n")
	content = content:gsub("&#60;.-&#62;", "")
	content = content:gsub("&#38;lt;", "<")
	content = content:gsub("&#38;gt;", ">")
	content = content:gsub("&#38;#43;", "+")
	content = content:gsub("&#38;#8217;", "'")
	return content
end

local function get_status(status)
	for ts, i in pairs(ticket_status) do
		if i == status then
			return ts:gsub("_", " ")
		end
	end
	return "Status inconnue - " .. status
end

local function make_crit_string(data, prefix)
	if not prefix then
		prefix = "criteria"
	end

	local res = ""

	for idx, searchTerm in ipairs(data) do
		for key, value in pairs(searchTerm) do
			if type(value) == "table" then
				local pref = "criteria\\[" .. (idx - 1) .. "\\]\\[" .. key .. "\\]"
				res = res .. make_crit_string(value, pref) .. "&"
			else
				res = res .. prefix .. "\\[" .. (idx - 1) .. "\\]\\[" .. key .. "\\]\\=" .. value .. "&"
			end
		end
	end

	return res:sub(1, -2)
end
local function make_get_request(url, crit, other_params)
	url = config.endpoint .. url

	if crit ~= nil then
		local crit_string = make_crit_string(crit)
		url = url .. "?" .. crit_string
	end

	if other_params ~= nil then
		url = url .. other_params
	end

	local res = curl.get(url, {
		headers = {
			content_type = "application/json",
			session_token = M.options.session_token,
			app_token = config.app_token,
		},
	})

	local status = res.status
	local body = res.body

	if status ~= 200 and status ~= 206 then
		error("Error performing get request" .. body)
	end

	return vim.fn.json_decode(body)
end

local function make_post_request(url, data)
	url = config.endpoint .. url

	local res = curl.post(url, {
		headers = {
			content_type = "application/json",
			session_token = M.options.session_token,
			app_token = config.app_token,
		},
		body = vim.fn.json_encode(data),
	})

	local status = res.status
	local body = res.body

	if status ~= 200 and status ~= 201 then
		error("Error performing POST request \n" .. body)
	end

	return vim.fn.json_decode(body)
end

local function get_item(item_type, id, params)
	if params == nil then
		params = ""
	end
	return make_get_request("/" .. item_type .. "/" .. id .. params)
end

local function search_items(item_type, crit, other_params)
	local items = make_get_request("/search/" .. item_type, crit, other_params)
	return items.data
end

local function add_item(item_type, data)
	return make_post_request("/" .. item_type, data)
end

local function add_ITIL_followup(ticket_id, content)
	local data = {
		input = {
			itemtype = "Ticket",
			items_id = ticket_id,
			users_id = M.options.user_id,
			content = content,
			is_private = false,
			requesttypes_id = 1,
			sourceitems_id = 0,
			sourceof_items_id = 0,
		},
	}
	return add_item("ITILFollowup", data)
end

local function add_ITIL_solution(ticket_id, content)
	local data = {
		input = {
			itemtype = "Ticket",
			items_id = ticket_id,
			users_id = M.options.user_id,
			content = content,
			solutiontypes_id = 1,
			sourceitems_id = 0,
			sourceof_items_id = 0,
		},
	}
	return add_item("ITILSolution", data)
end

local function get_user(user_id)
	return get_item("User", user_id)
end

local function get_username(user_id)
	local user_name = utils.get_user_in_cache(user_id)

	if user_name ~= nil then
		return user_name
	end

	local user = get_user(user_id)
	local firstname = user["firstname"]
	local lastname = user["realname"]
	user_name = lastname .. " " .. firstname
	utils.add_user_to_cache(user_id, user_name)
	utils.write_user_cache()

	return user_name
end

local function search_tickets(opts)
	opts = opts or {}

	local ticket_type = opts.type or "new"

	local crit = {}

	if ticket_type == "new" then
		table.insert(crit, {
			field = 12,
			value = 1,
			searchtype = "equals",
		})
	elseif ticket_type == "my_pending" then
		table.insert(crit, {
			field = 5,
			value = M.options.user_id,
			searchtype = "equals",
		})

		table.insert(crit, {
			link = "AND",
			criteria = {
				{
					field = 12,
					value = 4,
					searchtype = "equals",
				},
			},
		})
	elseif ticket_type == "my_processing" then
		table.insert(crit, {
			field = 5,
			value = M.options.user_id,
			searchtype = "equals",
		})

		table.insert(crit, {
			link = "AND",
			criteria = {
				{
					field = 12,
					value = 2,
					searchtype = "equals",
				},
			},
		})
	elseif ticket_type == "my" then
		table.insert(crit, {
			field = 5,
			value = M.options.user_id,
			searchtype = "equals",
		})

		table.insert(crit, {
			link = "AND",
			criteria = {
				{
					field = 12,
					value = 2,
					searchtype = "equals",
				},
				{
					link = "OR",
					field = 12,
					value = 4,
					searchtype = "equals",
				},
			},
		})
	elseif ticket_type == "other" then
		table.insert(crit, {
			field = 5,
			value = M.options.user_id,
			searchtype = "notequals",
		})

		table.insert(crit, {
			link = "AND",
			criteria = {
				{
					field = 12,
					value = 4,
					searchtype = "equals",
				},
				{
					link = "OR",
					field = 12,
					value = 2,
					searchtype = "equals",
				},
			},
		})
	end

	local tickets = search_items("Ticket", crit, "&sort=19&order=DESC")

	if tickets == nil then
		return nil
	end

	local function parse_usernames(users)
		if type(users) == "string" then
			return get_username(users)
		end

		local names = {}
		for _, user in ipairs(users) do
			table.insert(names, get_username(user))
		end
		return names
	end

	for i, _ in ipairs(tickets) do
		local status = get_status(tickets[i]["12"])
		tickets[i]["12"] = status

		tickets[i]["4"] = parse_usernames(tickets[i]["4"])
		tickets[i]["5"] = parse_usernames(tickets[i]["5"])
	end

	return tickets
end

local function get_user_id()
	local crit = {
		{
			field = 1,
			value = config.tech_name,
			searchtype = "contains",
		},
	}

	local users = search_items("User", crit)
	return users[1]["2"]
end

local function get_tickets()
	local my = {}

	if config.separate_pending_processing then
		my = {
			pending = search_tickets({ type = "my_pending" }) or {},
			processing = search_tickets({ type = "my_processing" }) or {},
		}
	else
		my = search_tickets({ type = "my" }) or {}
	end

	return {
		new = search_tickets({ type = "new" }) or {},
		my = my,
		other = search_tickets({ type = "other" }) or {},
	}
end

local function get_techs()
	local raw_techs = {}
	if type(config.tech_profile_id) == "table" then
		for _, profile_id in pairs(config.tech_profile_id) do
			local techs = get_item("Profile", profile_id, "/User")
			for _, tech in ipairs(techs) do
				table.insert(raw_techs, tech)
			end
		end
	else
		raw_techs = get_item("Profile", config.tech_profile_id, "/User")
	end
	local techs = {}

	for _, tech in ipairs(raw_techs) do
		local name = tech["realname"] .. " " .. tech["firstname"]
		techs[name] = tech["id"]
	end
	return techs
end

function M.init_session()
	local res = curl.get(config.endpoint .. "/initSession", {
		headers = {
			content_type = "application/json",
			authorization = "user_token " .. config.user_token,
			App_Token = config.app_token,
		},
	})

	local status = res.status
	local body = res.body

	if status ~= 200 then
		error("Error during initSession! Check endpoint, user_token and app_token\n" .. body)
	end

	M.options.session_token = vim.fn.json_decode(body).session_token
	M.options.user_id = get_user_id()

	print("Glpi session initiated")
end

function M.kill_session()
	local res = make_get_request("/killSession")
	if res == false then
		error("Impossible de fermer la session")
	end

	M.options.session_token = nil
	M.tickets = nil

	print("Session killed")
end

function M.update_tickets()
	M.tickets = get_tickets()
end

function M.get_ticket(idx)
	local new_n = #M.tickets.new
	local my_n = #M.tickets.my

	if idx <= new_n then
		return M.tickets.new[idx]
	end

	if idx - new_n <= my_n then
		return M.tickets.my[idx - new_n]
	end

	return M.tickets.other[idx - new_n - my_n]
end

function M.get_ticket_id(id)
	local ticket = get_item("Ticket", id)
	local content = clean_content(ticket.content)
	local status = get_status(ticket.status)
	local title = ticket.name
	local creation_date = ticket.date_creation
	local users = ticket.users_id_recipient

	local user_names = {}
	if type(users) == "number" then
		users = { users }
	end

	for _, user_id in ipairs(users) do
		table.insert(user_names, get_username(user_id))
	end

	local results = search_items("Ticket", { { field = 1, value = id, searchtype = "equals" } })
	local ticket_data = results[1]
	local tech_ids = ticket_data["5"]
	local tech_names = {}

	if tech_ids ~= vim.NIL then
		if type(tech_ids) == "string" then
			tech_ids = { tech_ids }
		end

		for _, tech_id in ipairs(tech_ids) do
			table.insert(tech_names, get_username(tech_id))
		end
	end

	local followups = get_item("Ticket", id, "/TicketFollowup")

	for i, _ in ipairs(followups) do
		followups[i].content = clean_content(followups[i].content)
		followups[i].user = get_username(followups[i].users_id)
	end

	return {
		id = id,
		title = title,
		status = status,
		content = content,
		followups = followups,
		tech_names = tech_names,
		users = user_names,
		creation_date = creation_date,
	}
end

function M.add_solution(content, ticket)
	add_ITIL_solution(ticket.id, content)
end

function M.add_followup(content, ticket)
	add_ITIL_followup(ticket.id, content)
end

function M.attribute_ticket_to(ticket, user_id)
	local data = {
		input = {
			tickets_id = ticket.id,
			users_id = user_id,
			type = 2,
			use_notification = 1,
		},
	}
	add_item("Ticket_User", data)
	local username = get_username(user_id)
	print('"' .. ticket.title .. '" est attribué à ' .. username)
end

return setmetatable(M, {
	__index = function(_, k)
		if M.options.session_token == nil then
			M.init_session()
		end
		M.tickets = get_tickets()
		M.techs = get_techs()
		return rawget(M, k)
	end,
})
