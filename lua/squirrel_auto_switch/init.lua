local Autocmd = require("squirrel_auto_switch.autocmd")
local Backend = require("squirrel_auto_switch.backend.squirrel")
local Commands = require("squirrel_auto_switch.commands")
local Config = require("squirrel_auto_switch.config")
local Controller = require("squirrel_auto_switch.controller")
local Notify = require("squirrel_auto_switch.notify")

local M = {}

local current = {
  config = nil,
  controller = nil,
}

local function require_setup()
  if not current.controller then
    error("squirrel-auto-switch.nvim: call setup() before using this function")
  end
  return current.controller
end

---@param opts? table
function M.setup(opts)
  if current.controller then
    current.controller:disable()
  end

  Autocmd.clear()
  Commands.clear()

  local config = Config.resolve(opts)
  local notifier = Notify.new(config)
  local backend = Backend.new(config, notifier)
  local controller = Controller.new(config, backend, notifier)

  current.config = config
  current.controller = controller

  Autocmd.setup(controller, config)
  Commands.setup(M)

  if vim.v.vim_did_enter == 1 then
    vim.schedule(function()
      if current.controller == controller then
        controller:sync(Autocmd.is_insert_like())
      end
    end)
  end

  return M
end

function M.enable()
  local controller = require_setup()
  controller:enable()
  controller:sync(Autocmd.is_insert_like())
end

function M.disable()
  require_setup():disable()
end

function M.toggle()
  local controller = require_setup()
  if controller:status().enabled then
    controller:disable()
  else
    controller:enable()
    controller:sync(Autocmd.is_insert_like())
  end
end

function M.sync()
  require_setup():sync(Autocmd.is_insert_like())
end

function M.status()
  if not current.controller then
    return {
      configured = false,
      enabled = false,
    }
  end

  local status = current.controller:status()
  status.configured = true
  return status
end

function M._get_config()
  return current.config or Config.resolve()
end

return M
