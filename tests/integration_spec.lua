local plugin = require("squirrel_auto_switch")

describe("Neovim integration", function()
  it("registers one stable set of autocmds and commands across repeated setup", function()
    local options = {
      executable = "/usr/bin/true",
      auto_activate = false,
      notify = false,
    }

    plugin.setup(options)
    plugin.setup(options)

    local autocmds = vim.api.nvim_get_autocmds({
      group = "SquirrelAutoSwitch",
    })

    assert_equal(5, #autocmds)
    assert_equal(2, vim.fn.exists(":SquirrelAutoSwitchEnable"))
    assert_equal(2, vim.fn.exists(":SquirrelAutoSwitchDisable"))
    assert_equal(2, vim.fn.exists(":SquirrelAutoSwitchToggle"))
    assert_equal(2, vim.fn.exists(":SquirrelAutoSwitchSync"))
    assert_equal(2, vim.fn.exists(":SquirrelAutoSwitchStatus"))
  end)

  it("can disable, enable, and toggle without duplicating setup", function()
    plugin.disable()
    assert_false(plugin.status().enabled)

    plugin.enable()
    assert_true(plugin.status().enabled)

    plugin.toggle()
    assert_false(plugin.status().enabled)
  end)
end)
