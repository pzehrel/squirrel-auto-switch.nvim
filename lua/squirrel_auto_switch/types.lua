---@alias SquirrelAutoSwitchState "ascii"|"nascii"
---@alias SquirrelAutoSwitchGetCallback fun(state: SquirrelAutoSwitchState|nil, err: string|nil)
---@alias SquirrelAutoSwitchSetCallback fun(ok: boolean, err: string|nil)
---@alias SASBackend SquirrelAutoSwitchBackend
---@alias SASState SquirrelAutoSwitchState
---@alias SASSetCallback SquirrelAutoSwitchSetCallback
---@alias SquirrelAutoSwitchSet fun(self: SASBackend, state: SASState, callback: SASSetCallback)

---@class SquirrelAutoSwitchConfig
---@field executable string
---@field input_source string
---@field auto_activate boolean
---@field default_insert_state SquirrelAutoSwitchState
---@field restore_on_insert_enter boolean
---@field sync_on_focus boolean
---@field timeout_ms integer
---@field notify boolean
---@field debug boolean
---@field error_throttle_ms integer

---@class SquirrelAutoSwitchBackend
---@field available fun(self: SquirrelAutoSwitchBackend): boolean
---@field get fun(self: SquirrelAutoSwitchBackend, callback: SquirrelAutoSwitchGetCallback)
---@field set SquirrelAutoSwitchSet

return {}
