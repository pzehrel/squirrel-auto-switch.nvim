local M = {}

---@param config SquirrelAutoSwitchConfig
function M.new(config)
  local last_error_at = {}

  local function send(message, level)
    if not config.notify then
      return
    end
    vim.notify("[squirrel-auto-switch] " .. message, level)
  end

  return {
    error = function(message, key)
      key = key or message
      local now = vim.uv.now()
      local last = last_error_at[key]
      if last and now - last < config.error_throttle_ms then
        return
      end
      last_error_at[key] = now
      send(message, vim.log.levels.ERROR)
    end,
    warn = function(message)
      send(message, vim.log.levels.WARN)
    end,
    info = function(message)
      send(message, vim.log.levels.INFO)
    end,
    debug = function(message)
      if config.debug then
        send(message, vim.log.levels.DEBUG)
      end
    end,
  }
end

return M
