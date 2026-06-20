local M = {}

---@param config SquirrelAutoSwitchConfig
---@param backend SquirrelAutoSwitchBackend
---@param notifier table
function M.new(config, backend, notifier)
  local controller = {
    enabled = true,
    actual_state = nil,
    target_state = nil,
    last_insert_state = nil,
    queue = {},
    running = false,
    generation = 1,
  }

  local function is_active(token)
    return controller.enabled and token == controller.generation
  end

  function controller:_drain()
    if self.running or not self.enabled then
      return
    end

    local task = table.remove(self.queue, 1)
    if not task then
      return
    end

    self.running = true
    local finished = false

    task.operation(function()
      if finished then
        return
      end
      finished = true
      self.running = false
      self:_drain()
    end, task.token)
  end

  function controller:_enqueue(name, operation)
    if not self.enabled then
      return
    end

    table.insert(self.queue, {
      name = name,
      operation = operation,
      token = self.generation,
    })
    self:_drain()
  end

  function controller:_set_state(state, force, done, token)
    if not is_active(token) then
      done()
      return
    end

    self.target_state = state

    if not force and self.actual_state == state then
      done()
      return
    end

    backend:set(state, function(ok, err)
      if is_active(token) then
        if ok then
          self.actual_state = state
        else
          notifier.error(("unable to set state to %s: %s"):format(state, tostring(err)), "controller-set-" .. state)
        end
      end
      done()
    end)
  end

  function controller:_get_state(callback, done, token)
    if not is_active(token) then
      done()
      return
    end

    backend:get(function(state, err)
      if is_active(token) then
        if state == "ascii" or state == "nascii" then
          self.actual_state = state
        elseif err then
          notifier.error("unable to query state: " .. tostring(err), "controller-get")
        end
        callback(state, err)
      end
      done()
    end)
  end

  function controller:on_start()
    self:_enqueue("start", function(done, token)
      self:_set_state("ascii", true, done, token)
    end)
  end

  function controller:on_insert_enter()
    if not config.restore_on_insert_enter then
      return
    end

    self:_enqueue("insert-enter", function(done, token)
      local state = self.last_insert_state or config.default_insert_state
      self:_set_state(state, false, done, token)
    end)
  end

  function controller:on_insert_leave()
    self:_enqueue("insert-leave", function(done, token)
      backend:get(function(state, err)
        if not is_active(token) then
          done()
          return
        end

        if state == "ascii" or state == "nascii" then
          self.actual_state = state
          self.last_insert_state = state
        elseif err then
          notifier.error("unable to remember Insert state: " .. tostring(err), "remember-insert")
        end

        self:_set_state("ascii", false, done, token)
      end)
    end)
  end

  function controller:on_focus_gained(insert_like)
    if not config.sync_on_focus then
      return
    end

    if insert_like then
      self:_enqueue("focus-gained-insert", function(done, token)
        self:_get_state(function(state)
          if state == "ascii" or state == "nascii" then
            self.last_insert_state = state
          end
        end, done, token)
      end)
      return
    end

    self:_enqueue("focus-gained-normal", function(done, token)
      self.actual_state = nil
      self:_set_state("ascii", true, done, token)
    end)
  end

  function controller:on_focus_lost()
    self:_enqueue("focus-lost", function(done, token)
      if is_active(token) then
        self.actual_state = nil
      end
      done()
    end)
  end

  function controller:sync(insert_like)
    if insert_like then
      self:on_insert_enter()
    else
      self:_enqueue("sync-normal", function(done, token)
        self.actual_state = nil
        self:_set_state("ascii", true, done, token)
      end)
    end
  end

  function controller:enable()
    if self.enabled then
      return
    end
    self.enabled = true
    self.generation = self.generation + 1
    self:_drain()
  end

  function controller:disable()
    if not self.enabled then
      return
    end
    self.enabled = false
    self.generation = self.generation + 1
    self.queue = {}
    self.target_state = nil
  end

  function controller:status()
    return {
      enabled = self.enabled,
      actual_state = self.actual_state,
      target_state = self.target_state,
      last_insert_state = self.last_insert_state,
      pending_operations = #self.queue + (self.running and 1 or 0),
      backend_available = backend:available(),
    }
  end

  return controller
end

return M
