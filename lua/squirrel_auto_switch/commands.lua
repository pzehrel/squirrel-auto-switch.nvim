local M = {}

local command_names = {
  "SquirrelAutoSwitchEnable",
  "SquirrelAutoSwitchDisable",
  "SquirrelAutoSwitchToggle",
  "SquirrelAutoSwitchSync",
  "SquirrelAutoSwitchStatus",
}

local function create(name, callback, description)
  vim.api.nvim_create_user_command(name, callback, {
    desc = description,
    force = true,
  })
end

---@param api table
function M.setup(api)
  create("SquirrelAutoSwitchEnable", api.enable, "Enable automatic Squirrel input state switching")
  create("SquirrelAutoSwitchDisable", api.disable, "Disable automatic Squirrel input state switching")
  create("SquirrelAutoSwitchToggle", api.toggle, "Toggle automatic Squirrel input state switching")
  create("SquirrelAutoSwitchSync", api.sync, "Synchronize Squirrel with the current Neovim mode")
  create("SquirrelAutoSwitchStatus", function()
    vim.notify(vim.inspect(api.status()), vim.log.levels.INFO, {
      title = "squirrel-auto-switch.nvim",
    })
  end, "Show squirrel-auto-switch.nvim status")
end

function M.clear()
  for _, name in ipairs(command_names) do
    pcall(vim.api.nvim_del_user_command, name)
  end
end

return M
