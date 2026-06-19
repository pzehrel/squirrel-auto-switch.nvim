local M = {}

M.defaults = {
  executable = "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel",
  input_source = "im.rime.inputmethod.Squirrel.Hans",
  auto_activate = true,
  default_insert_state = "ascii",
  restore_on_insert_enter = true,
  sync_on_focus = true,
  timeout_ms = 3000,
  notify = true,
  debug = false,
  error_throttle_ms = 30000,
}

local aliases = {
  english = "ascii",
  chinese = "nascii",
}

local function assert_type(name, value, expected)
  if type(value) ~= expected then
    error(("squirrel-auto-switch.nvim: %s must be %s, got %s"):format(name, expected, type(value)))
  end
end

---@param user_config? table
---@return SquirrelAutoSwitchConfig
function M.resolve(user_config)
  user_config = user_config or {}
  assert_type("config", user_config, "table")

  for key in pairs(user_config) do
    if M.defaults[key] == nil then
      error(("squirrel-auto-switch.nvim: unknown option %q"):format(key))
    end
  end

  local resolved = vim.tbl_deep_extend("force", {}, M.defaults, user_config)
  resolved.default_insert_state = aliases[resolved.default_insert_state] or resolved.default_insert_state

  assert_type("executable", resolved.executable, "string")
  assert_type("input_source", resolved.input_source, "string")
  assert_type("auto_activate", resolved.auto_activate, "boolean")
  assert_type("restore_on_insert_enter", resolved.restore_on_insert_enter, "boolean")
  assert_type("sync_on_focus", resolved.sync_on_focus, "boolean")
  assert_type("timeout_ms", resolved.timeout_ms, "number")
  assert_type("notify", resolved.notify, "boolean")
  assert_type("debug", resolved.debug, "boolean")
  assert_type("error_throttle_ms", resolved.error_throttle_ms, "number")

  if resolved.default_insert_state ~= "ascii" and resolved.default_insert_state ~= "nascii" then
    error("squirrel-auto-switch.nvim: default_insert_state must be 'ascii', 'nascii', 'english', or 'chinese'")
  end

  if resolved.executable == "" then
    error("squirrel-auto-switch.nvim: executable must not be empty")
  end

  if resolved.auto_activate and resolved.input_source == "" then
    error("squirrel-auto-switch.nvim: input_source must not be empty when auto_activate is enabled")
  end

  if resolved.timeout_ms <= 0 or resolved.timeout_ms % 1 ~= 0 then
    error("squirrel-auto-switch.nvim: timeout_ms must be a positive integer")
  end

  if resolved.error_throttle_ms < 0 or resolved.error_throttle_ms % 1 ~= 0 then
    error("squirrel-auto-switch.nvim: error_throttle_ms must be a non-negative integer")
  end

  return resolved
end

return M
