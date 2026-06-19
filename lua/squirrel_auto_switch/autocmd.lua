local M = {}

local group_name = "SquirrelAutoSwitch"

function M.is_insert_like()
  local mode = vim.api.nvim_get_mode().mode
  local prefix = mode:sub(1, 1)
  return prefix == "i" or prefix == "R"
end

---@param controller table
---@param config SquirrelAutoSwitchConfig
function M.setup(controller, config)
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    desc = "Initialize Squirrel ASCII mode",
    callback = function()
      controller:on_start()
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    desc = "Restore the remembered Squirrel Insert state",
    callback = function()
      controller:on_insert_enter()
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    desc = "Remember the Squirrel Insert state and switch to ASCII",
    callback = function()
      controller:on_insert_leave()
    end,
  })

  if config.sync_on_focus then
    vim.api.nvim_create_autocmd("FocusGained", {
      group = group,
      desc = "Synchronize Squirrel after Neovim regains focus",
      callback = function()
        controller:on_focus_gained(M.is_insert_like())
      end,
    })

    vim.api.nvim_create_autocmd("FocusLost", {
      group = group,
      desc = "Invalidate the cached Squirrel state after focus is lost",
      callback = function()
        controller:on_focus_lost()
      end,
    })
  end
end

function M.clear()
  pcall(vim.api.nvim_del_augroup_by_name, group_name)
end

return M
