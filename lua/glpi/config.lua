local M = {}

local defaults = {
	endpoint = nil,
	user_token = nil,
	app_token = nil,
	tech_name = nil,
	tech_profile_id = nil,
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
	M.options.endpoint = M.options.endpoint:gsub("/$", "")
	M.options.base_url = M.options.endpoint:gsub("/apirest.php$", "")
end

return setmetatable(M, {
	__index = function(_, k)
		if rawget(M, "options") == nil then
			M.setup()
		end
		local opts = rawget(M, "options")
		return k == "options" and opts or opts[k]
	end,
})
