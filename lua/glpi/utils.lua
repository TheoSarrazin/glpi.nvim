local path = require("plenary.path")

local M = {}

local data_path = path:new(vim.fn.stdpath("data") .. "/glpi")
local user_cache_file = path:new(data_path):joinpath("user_cache.json")

local user_cache = {}

function M.setup()
	if not data_path:exists() then
		data_path:mkdir({ parent = true })
	end

	if not user_cache_file:exists() then
		user_cache = {}
		return
	end

	local content = user_cache_file:read()
	user_cache = content ~= nil and vim.json.decode(content) or {}
end

function M.get_user_in_cache(user_id)
	return user_cache[tostring(user_id)]
end

function M.add_user_to_cache(user_id, user_name)
	user_cache[tostring(user_id)] = user_name
end

function M.write_user_cache()
	local content = vim.json.encode(user_cache)
	user_cache_file:write(content, "w")
end

return M
