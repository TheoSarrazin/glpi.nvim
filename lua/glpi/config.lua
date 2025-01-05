local M = {}

local defaults = {
	endpoint = "",
	user_token = "",
	app_token = "",
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
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
