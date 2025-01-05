local M = {}

local options = {
	session_token = nil,
}

M.tickets = nil

function M.init_session()
	print("session initialisation")
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

function M.get_tickets()
	return {
		new = {
			"Problème d'imprimante",
		},
		my = {
			"Astre GF ne marche pas",
			"Astre RH ne marche pas non plus",
		},
		other = {},
	}
end

return setmetatable(M, {
	__index = function(_, k)
		if options.session_token == nil then
			M.init_session()
		end
		M.tickets = M.get_tickets()
		return rawget(M, k)
	end,
})
