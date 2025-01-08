# glpi.nvim

Access GLPI direclty throught nvim

This is my first attempt to write something in LUA and nvim plugin

# Usage

With lazy.nvim

```lua
{
    "TheoSarrazin/glpi.nvim",
    opts = {
        endpoint = "http://myglpi.example.org/glpi/apirest.php/",
        user_token = "",
        app_token = "",
        tech_name = "my_username",
        tech_profile_id = {}, -- Id of profile who can be add as technician
    },
    keys = {
        "<space>gi",
        function()
            require("glpi").load_tickets()
        end,
        desc = "Load all tickets",
    },
}
```

# Configuration

Default opts:

```lua
{
	endpoint = nil,
	user_token = nil,
	app_token = nil,
	tech_name = nil,
	tech_profile_id = nil,
    separate_pending_processing = false, -- show my pending and processing tickets separately?
	keymaps = {
		add_solution = "S", -- keymap to add a solution
		add_followup = "R", -- keymap to add a followup
		next_ticket = "<c-j>", -- keymap to go to the next ticket
		prev_ticket = "<c-k>", -- keymap to go to the previous ticket
		attribution = "<space>gt", -- keymap to add someone to the ticket
		attribution_to_me = "<space>ga", -- keymap to add himself to the ticket
		reload_ticket = "<space>gg", -- keymap to reload tickets list
	},
}
```
