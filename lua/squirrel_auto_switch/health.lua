local Config = require("squirrel_auto_switch.config")

local M = {}

local health = vim.health or require("health")

local function report(name, message)
  local modern = health[name]
  local legacy = health["report_" .. name]
  return (modern or legacy)(message)
end

local function get_config()
  local ok, plugin = pcall(require, "squirrel_auto_switch")
  if ok and plugin._get_config then
    return plugin._get_config()
  end
  return Config.resolve()
end

function M.check()
  local config = get_config()
  local uname = vim.uv.os_uname()

  report("start", "squirrel-auto-switch.nvim")

  if uname.sysname == "Darwin" then
    report("ok", "Operating system is macOS")
  else
    report("warn", "Operating system is " .. uname.sysname .. "; the built-in Squirrel backend targets macOS")
  end

  if vim.system then
    report("ok", "vim.system is available")
  else
    report("error", "vim.system is unavailable; Neovim 0.10 or newer is required")
    return
  end

  report("info", "Configured executable: " .. config.executable)
  report("info", "Configured input source: " .. config.input_source)

  if vim.fn.executable(config.executable) ~= 1 then
    report("error", "Squirrel CLI is not executable at the configured path")
    return
  end

  report("ok", "Squirrel CLI is executable")

  local result = vim.system({ config.executable, "--getascii" }, {
    text = true,
    timeout = config.timeout_ms,
  }):wait()
  local output = (result.stdout or ""):gsub("%s+$", "")

  if result.code ~= 0 then
    local detail = (result.stderr or ""):gsub("%s+$", "")
    report("error", ("Squirrel state query failed with code %d: %s"):format(result.code, detail))
  elseif output == "ascii" or output == "nascii" then
    report("ok", "Current Squirrel state: " .. output)
  else
    report("error", "Unexpected Squirrel state: " .. vim.inspect(output))
  end
end

return M
