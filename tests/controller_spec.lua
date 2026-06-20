local Controller = require("squirrel_auto_switch.controller")
local config = require("squirrel_auto_switch.config").resolve({
  notify = false,
})

local notifier = {
  error = function() end,
  debug = function() end,
}

local function fake_backend(initial_state)
  local backend = {
    state = initial_state or "ascii",
    get_calls = 0,
    set_calls = {},
    fail_get = false,
    fail_set = false,
  }

  function backend.available()
    return true
  end

  function backend:get(callback)
    self.get_calls = self.get_calls + 1
    if self.fail_get then
      callback(nil, "query failed")
    else
      callback(self.state, nil)
    end
  end

  function backend:set(state, callback)
    table.insert(self.set_calls, state)
    if self.fail_set then
      callback(false, "set failed")
    else
      self.state = state
      callback(true, nil)
    end
  end

  return backend
end

describe("input-state controller", function()
  it("forces ascii on startup", function()
    local backend = fake_backend("nascii")
    local controller = Controller.new(config, backend, notifier)

    controller:on_start()

    assert_equal({ "ascii" }, backend.set_calls)
    assert_equal("ascii", controller:status().actual_state)
  end)

  it("uses the configured state on first InsertEnter", function()
    local backend = fake_backend("ascii")
    local chinese_config = vim.tbl_extend("force", {}, config, { default_insert_state = "nascii" })
    local controller = Controller.new(chinese_config, backend, notifier)

    controller:on_insert_enter()

    assert_equal({ "nascii" }, backend.set_calls)
  end)

  it("queries and remembers the real Insert state before switching to ascii", function()
    local backend = fake_backend("nascii")
    local controller = Controller.new(config, backend, notifier)

    controller:on_insert_leave()

    assert_equal(1, backend.get_calls)
    assert_equal({ "ascii" }, backend.set_calls)
    assert_equal("nascii", controller:status().last_insert_state)
  end)

  it("restores a remembered nascii state", function()
    local backend = fake_backend("nascii")
    local controller = Controller.new(config, backend, notifier)

    controller:on_insert_leave()
    controller:on_insert_enter()

    assert_equal({ "ascii", "nascii" }, backend.set_calls)
    assert_equal("nascii", controller:status().actual_state)
  end)

  it("observes Insert state on focus without setting it", function()
    local backend = fake_backend("nascii")
    local controller = Controller.new(config, backend, notifier)

    controller:on_focus_gained(true)

    assert_equal(1, backend.get_calls)
    assert_equal({}, backend.set_calls)
    assert_equal("nascii", controller:status().last_insert_state)
  end)

  it("forces ascii when Normal mode regains focus", function()
    local backend = fake_backend("nascii")
    local controller = Controller.new(config, backend, notifier)

    controller:on_focus_gained(false)

    assert_equal({ "ascii" }, backend.set_calls)
  end)

  it("does not overwrite remembered state after backend failures", function()
    local backend = fake_backend("nascii")
    local controller = Controller.new(config, backend, notifier)

    controller:on_insert_leave()
    backend.fail_get = true
    backend.fail_set = true
    controller:on_insert_leave()

    assert_equal("nascii", controller:status().last_insert_state)
    assert_equal("ascii", controller:status().actual_state)
  end)

  it("serializes rapid leave and enter operations", function()
    local pending_get
    local backend = {
      state = "nascii",
      set_calls = {},
      available = function()
        return true
      end,
      get = function(_, callback)
        pending_get = callback
      end,
      set = function(self, state, callback)
        table.insert(self.set_calls, state)
        self.state = state
        callback(true, nil)
      end,
    }
    local controller = Controller.new(config, backend, notifier)

    controller:on_insert_leave()
    controller:on_insert_enter()

    assert_equal({}, backend.set_calls)
    pending_get("nascii", nil)

    assert_equal({ "ascii", "nascii" }, backend.set_calls)
    assert_equal("nascii", controller:status().actual_state)
    assert_equal(0, controller:status().pending_operations)
  end)
end)
