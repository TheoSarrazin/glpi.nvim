local tickets = require("telescope._extensions.glpi.tickets")

return require("telescope").register_extension({
	exports = { tickets = tickets },
})
