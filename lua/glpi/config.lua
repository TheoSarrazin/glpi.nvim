local M = {}

local defaults = {
	endpoint = nil,
	user_token = nil,
	app_token = nil,
	tech_name = nil,
	tech_profile_id = nil,
	keymaps = {
		add_solution = "S",
		add_followup = "R",
		next_ticket = "<c-j>",
		prev_ticket = "<c-k>",
        attribution = "<space>gt",
        attribution_to_me = "<space>ga",
	},
}

M.options = {}

function M.setup(opts)
	local function check_madatory_key(keys)
		for _, key in ipairs(keys) do
			if opts[key] == nil then
				error(key .. " doit être renseigné")
			end
		end
	end

	check_madatory_key({ "endpoint", "user_token", "app_token", "tech_name", "tech_profile_id" })

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
