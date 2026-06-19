local M = {}

local function trim(value)
  return (value or ""):gsub("%s+$", "")
end

---@param config SquirrelAutoSwitchConfig
---@param notifier table
function M.new(config, notifier)
  local runner = {}

  ---@param args string[]
  ---@param callback fun(ok: boolean, output: string|nil, err: string|nil)
  function runner.run(args, callback)
    local command = vim.list_extend({ config.executable }, vim.deepcopy(args))
    notifier.debug("running: " .. table.concat(command, " "))

    local ok, process_or_error = pcall(vim.system, command, {
      text = true,
      timeout = config.timeout_ms,
    }, function(result)
      vim.schedule(function()
        local stdout = trim(result.stdout)
        local stderr = trim(result.stderr)

        if result.code ~= 0 then
          local detail = stderr ~= "" and stderr or stdout
          local message = ("command exited with code %d"):format(result.code)
          if detail ~= "" then
            message = message .. ": " .. detail
          end
          callback(false, nil, message)
          return
        end

        callback(true, stdout, nil)
      end)
    end)

    if not ok then
      vim.schedule(function()
        callback(false, nil, "failed to spawn command: " .. tostring(process_or_error))
      end)
    end
  end

  return runner
end

return M
