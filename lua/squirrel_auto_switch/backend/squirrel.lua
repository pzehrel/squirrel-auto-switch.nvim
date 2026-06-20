local Runner = require("squirrel_auto_switch.runner")

local M = {}

---@param config SquirrelAutoSwitchConfig
---@param notifier? table
---@param runner? table
function M.new(config, notifier, runner)
  notifier = notifier or require("squirrel_auto_switch.notify").new(config)
  runner = runner or Runner.new(config, notifier)

  local backend = {}

  function backend.available()
    return vim.fn.executable(config.executable) == 1
  end

  local function unavailable(callback, set_operation)
    local err = "Squirrel CLI is not executable: " .. config.executable
    notifier.error(err, "unavailable")
    if set_operation then
      callback(false, err)
    else
      callback(nil, err)
    end
  end

  function backend:get(callback)
    if not self.available() then
      unavailable(callback, false)
      return
    end

    runner.run({ "--getascii" }, function(ok, output, err)
      if not ok then
        notifier.error("failed to query state: " .. err, "get-state")
        callback(nil, err)
        return
      end

      if output ~= "ascii" and output ~= "nascii" then
        local invalid_err = "unexpected --getascii output: " .. vim.inspect(output)
        notifier.error(invalid_err, "invalid-state")
        callback(nil, invalid_err)
        return
      end

      callback(output, nil)
    end)
  end

  local function activate(callback)
    if not config.auto_activate then
      callback(true, nil)
      return
    end

    runner.run({ "--select-input-source", config.input_source }, function(selected, _, select_err)
      if selected then
        callback(true, nil)
        return
      end

      runner.run({ "--enable-input-source", config.input_source }, function(enabled, _, enable_err)
        if not enabled then
          callback(false, enable_err or select_err)
          return
        end

        runner.run({ "--select-input-source", config.input_source }, function(retried, _, retry_err)
          callback(retried, retry_err)
        end)
      end)
    end)
  end

  function backend:set(state, callback)
    if state ~= "ascii" and state ~= "nascii" then
      callback(false, "invalid state: " .. tostring(state))
      return
    end

    if not self.available() then
      unavailable(callback, true)
      return
    end

    activate(function(activated, activate_err)
      if not activated then
        local err = "failed to activate Squirrel input source: " .. tostring(activate_err)
        notifier.error(err, "activate")
        callback(false, err)
        return
      end

      runner.run({ state == "ascii" and "--ascii" or "--nascii" }, function(ok, _, err)
        if not ok then
          notifier.error(("failed to set %s state: %s"):format(state, err), "set-" .. state)
          callback(false, err)
          return
        end
        callback(true, nil)
      end)
    end)
  end

  return backend
end

return M
