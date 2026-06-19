local Backend = require("squirrel_auto_switch.backend.squirrel")
local Config = require("squirrel_auto_switch.config")

local notifier = {
  error = function() end,
  debug = function() end,
}

local function make_runner(responses)
  local runner = {
    calls = {},
  }

  function runner.run(args, callback)
    table.insert(runner.calls, args)
    local response = table.remove(responses, 1)
    callback(response[1], response[2], response[3])
  end

  return runner
end

local function make_backend(responses, overrides)
  local options = vim.tbl_extend("force", {
    executable = "/bin/sh",
    notify = false,
  }, overrides or {})
  local runner = make_runner(responses)
  return Backend.new(Config.resolve(options), notifier, runner), runner
end

describe("Squirrel backend", function()
  it("accepts a valid queried state", function()
    local backend = make_backend({
      { true, "nascii", nil },
    })
    local received

    backend:get(function(state)
      received = state
    end)

    assert_equal("nascii", received)
  end)

  it("rejects unexpected queried output", function()
    local backend = make_backend({
      { true, "unknown", nil },
    })
    local received
    local received_err

    backend:get(function(state, err)
      received = state
      received_err = err
    end)

    assert_equal(nil, received)
    assert_true(type(received_err) == "string")
  end)

  it("does not set state when activation cannot be recovered", function()
    local backend, runner = make_backend({
      { false, nil, "select failed" },
      { false, nil, "enable failed" },
    })
    local succeeded

    backend:set("ascii", function(ok)
      succeeded = ok
    end)

    assert_false(succeeded)
    assert_equal({
      { "--select-input-source", "im.rime.inputmethod.Squirrel.Hans" },
      { "--enable-input-source", "im.rime.inputmethod.Squirrel.Hans" },
    }, runner.calls)
  end)

  it("retries selection before setting state", function()
    local backend, runner = make_backend({
      { false, nil, "select failed" },
      { true, "", nil },
      { true, "", nil },
      { true, "", nil },
    })
    local succeeded

    backend:set("nascii", function(ok)
      succeeded = ok
    end)

    assert_true(succeeded)
    assert_equal({
      { "--select-input-source", "im.rime.inputmethod.Squirrel.Hans" },
      { "--enable-input-source", "im.rime.inputmethod.Squirrel.Hans" },
      { "--select-input-source", "im.rime.inputmethod.Squirrel.Hans" },
      { "--nascii" },
    }, runner.calls)
  end)

  it("can set state without activating the input source", function()
    local backend, runner = make_backend({
      { true, "", nil },
    }, {
      auto_activate = false,
    })
    local succeeded

    backend:set("ascii", function(ok)
      succeeded = ok
    end)

    assert_true(succeeded)
    assert_equal({
      { "--ascii" },
    }, runner.calls)
  end)
end)
