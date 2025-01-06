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
