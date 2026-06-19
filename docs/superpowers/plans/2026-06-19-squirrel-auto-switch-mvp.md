# Squirrel Auto Switch MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Neovim plugin that keeps Squirrel in ASCII mode outside Insert/Replace, remembers the user's Insert input state, restores it on re-entry, and remains responsive and diagnosable.

**Architecture:** Separate Neovim event policy from the Squirrel CLI backend. A serialized controller owns `actual_state`, `target_state`, and `last_insert_state`; the backend performs asynchronous `vim.system()` calls and only reports successful, validated state transitions. Public setup, commands, and health checks wrap these components without depending on the user's existing Neovim configuration.

**Tech Stack:** Lua, Neovim Lua API, `vim.system`, Neovim health API, headless Neovim tests, GitHub Actions.

---

## File map

- `.gitignore`: ignore editor files, test output, Lua coverage files, and local development artifacts.
- `lua/squirrel_auto_switch/init.lua`: public `setup()`, enable/disable/toggle/sync/status API.
- `lua/squirrel_auto_switch/config.lua`: defaults, merge, normalization, and validation.
- `lua/squirrel_auto_switch/controller.lua`: serialized mode/input-state state machine.
- `lua/squirrel_auto_switch/autocmd.lua`: Neovim lifecycle and mode event registration.
- `lua/squirrel_auto_switch/commands.lua`: user commands.
- `lua/squirrel_auto_switch/notify.lua`: throttled notifications and debug logging.
- `lua/squirrel_auto_switch/runner.lua`: asynchronous process execution with timeout.
- `lua/squirrel_auto_switch/backend/squirrel.lua`: Squirrel CLI availability, activation, query, and set operations.
- `lua/squirrel_auto_switch/health.lua`: health-check implementation shared by both health entrypoint styles.
- `lua/squirrel_auto_switch/types.lua`: LuaLS annotations for configuration and backend interfaces.
- `health/squirrel_auto_switch.lua`: Neovim 0.10 health entrypoint.
- `lua/squirrel_auto_switch/health/init.lua`: Neovim 0.11+ health entrypoint.
- `tests/minimal_init.lua`: isolated runtime path for tests.
- `tests/run.lua`: zero-dependency test harness.
- `tests/config_spec.lua`: configuration validation tests.
- `tests/controller_spec.lua`: state-machine and failure-path tests with a fake backend.
- `Makefile`: reproducible `test` and `check` entrypoints.
- `.luacheckrc`: Lua static-analysis globals and style configuration.
- `.github/workflows/ci.yml`: headless Neovim test workflow.
- `README.md`: Chinese installation, configuration, behavior, commands, health, and troubleshooting guide.
- `LICENSE`: MIT license.

### Task 1: Repository foundation

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `.luacheckrc`
- Create: `Makefile`
- Create: `tests/minimal_init.lua`
- Create: `tests/run.lua`

- [ ] **Step 1: Add repository hygiene**

Create `.gitignore` with:

```gitignore
.DS_Store
*.swp
*.swo
*~
.luacov
luacov.*
coverage/
tmp/
.nvimlog
```

- [ ] **Step 2: Add isolated headless test bootstrap**

`tests/minimal_init.lua` must prepend the repository root to `runtimepath`, disable swap files, and avoid loading user configuration.

- [ ] **Step 3: Add a zero-dependency test runner**

`tests/run.lua` must expose `describe`, `it`, and equality helpers, load every `tests/*_spec.lua`, print failures, and exit Neovim non-zero when any test fails.

- [ ] **Step 4: Add project commands**

`Makefile` must define:

```make
test:
	nvim --headless -u tests/minimal_init.lua -l tests/run.lua

check: test
```

- [ ] **Step 5: Verify the empty harness**

Run: `make test`

Expected: exit code `0` with a summary showing zero failures.

### Task 2: Configuration contract

**Files:**
- Create: `lua/squirrel_auto_switch/types.lua`
- Create: `lua/squirrel_auto_switch/config.lua`
- Create: `tests/config_spec.lua`

- [ ] **Step 1: Write failing configuration tests**

Cover these exact defaults:

```lua
{
  executable = "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel",
  input_source = "im.rime.inputmethod.Squirrel.Hans",
  auto_activate = true,
  default_insert_state = "ascii",
  restore_on_insert_enter = true,
  sync_on_focus = true,
  timeout_ms = 3000,
  notify = true,
  debug = false,
}
```

Also assert that invalid states and non-positive timeouts produce errors.

- [ ] **Step 2: Run tests and confirm failure**

Run: `make test`

Expected: FAIL because `squirrel_auto_switch.config` does not exist.

- [ ] **Step 3: Implement configuration**

Expose:

```lua
config.defaults
config.resolve(user_config) -> normalized_config
```

Accept `"english"`/`"chinese"` as aliases for `"ascii"`/`"nascii"` and reject unknown keys to catch misspellings.

- [ ] **Step 4: Run tests**

Run: `make test`

Expected: all configuration tests pass.

### Task 3: Asynchronous Squirrel backend

**Files:**
- Create: `lua/squirrel_auto_switch/notify.lua`
- Create: `lua/squirrel_auto_switch/runner.lua`
- Create: `lua/squirrel_auto_switch/backend/squirrel.lua`

- [ ] **Step 1: Implement throttled diagnostics**

Provide `notify.error(message)`, `notify.warn(message)`, and `notify.debug(message)`. Error messages with the same key must be suppressed for 30 seconds; debug output is conditional.

- [ ] **Step 2: Implement async execution**

Wrap:

```lua
vim.system(command, { text = true, timeout = timeout_ms }, callback)
```

Normalize stdout/stderr, convert spawn and non-zero exits to structured errors, and always invoke the callback through `vim.schedule()`.

- [ ] **Step 3: Implement backend availability and query**

Expose:

```lua
backend:available() -> boolean
backend:get(callback)
```

`get()` calls `--getascii` and only accepts `ascii` or `nascii`.

- [ ] **Step 4: Implement activation and state setting**

When `auto_activate` is true:

1. call `--select-input-source <id>`;
2. on failure call `--enable-input-source <id>`;
3. retry selection;
4. only after successful activation call `--ascii` or `--nascii`.

Expose `backend:set(state, callback)` and never report success after a failed activation.

- [ ] **Step 5: Smoke-test the real CLI**

Run:

```sh
nvim --headless -u tests/minimal_init.lua \
  +"lua require('squirrel_auto_switch.backend.squirrel').new(require('squirrel_auto_switch.config').resolve()):get(function(state, err) print(state or err) vim.cmd('qa!') end)"
```

Expected: prints `ascii` or `nascii` and exits successfully on a machine with Squirrel installed.

### Task 4: Serialized input-state controller

**Files:**
- Create: `lua/squirrel_auto_switch/controller.lua`
- Create: `tests/controller_spec.lua`

- [ ] **Step 1: Write failing state-machine tests**

Use an in-memory fake backend and cover:

- startup/Normal requests `ascii`;
- first Insert uses `default_insert_state`;
- InsertLeave queries real state before setting `ascii`;
- a remembered `nascii` state is restored on the next InsertEnter;
- Insert FocusGained queries and remembers but does not set;
- Normal FocusGained invalidates assumptions and forces `ascii`;
- backend failures do not overwrite `actual_state` or `last_insert_state`;
- queued rapid leave/enter operations finish with the latest requested state.

- [ ] **Step 2: Run tests and confirm failure**

Run: `make test`

Expected: FAIL because the controller does not exist.

- [ ] **Step 3: Implement a serialized operation queue**

The controller must expose:

```lua
controller:on_start()
controller:on_insert_enter()
controller:on_insert_leave()
controller:on_focus_gained(is_insert_like)
controller:on_focus_lost()
controller:sync(is_insert_like)
controller:status()
controller:enable()
controller:disable()
```

Maintain separate `actual_state`, `target_state`, and `last_insert_state`. Every asynchronous operation must complete before the next queued operation starts, ensuring stale callbacks cannot overtake newer events.

- [ ] **Step 4: Implement correctness-first InsertLeave**

InsertLeave must always query the real Squirrel state, save a valid result as `last_insert_state`, fall back to the configured default only when no prior valid state exists, and then request ASCII.

- [ ] **Step 5: Run tests**

Run: `make test`

Expected: all controller tests pass.

### Task 5: Neovim integration and public API

**Files:**
- Create: `lua/squirrel_auto_switch/autocmd.lua`
- Create: `lua/squirrel_auto_switch/commands.lua`
- Create: `lua/squirrel_auto_switch/init.lua`

- [ ] **Step 1: Implement mode detection and autocmd lifecycle**

Register one clearable augroup with:

- `VimEnter` → `on_start()`;
- `InsertEnter` → `on_insert_enter()`;
- `InsertLeave` → `on_insert_leave()`;
- `FocusGained` → query current mode and call `on_focus_gained()`;
- `FocusLost` → `on_focus_lost()`.

Treat modes beginning with `i` or `R` as Insert-like.

- [ ] **Step 2: Implement public lifecycle**

`require("squirrel_auto_switch").setup(opts)` must:

1. resolve configuration at setup time;
2. replace any previous controller safely;
3. register autocmds and commands exactly once;
4. synchronize immediately if setup runs after `VimEnter`.

Expose `enable`, `disable`, `toggle`, `sync`, and `status`.

- [ ] **Step 3: Implement commands**

Create:

```text
:SquirrelAutoSwitchEnable
:SquirrelAutoSwitchDisable
:SquirrelAutoSwitchToggle
:SquirrelAutoSwitchSync
:SquirrelAutoSwitchStatus
```

- [ ] **Step 4: Verify isolated setup**

Run:

```sh
nvim --headless -u tests/minimal_init.lua \
  +"lua require('squirrel_auto_switch').setup({ notify = false })" \
  +"lua print(vim.inspect(require('squirrel_auto_switch').status()))" \
  +qa
```

Expected: prints an enabled status table and exits without loading the user's Neovim configuration.

### Task 6: Health checks and documentation

**Files:**
- Create: `lua/squirrel_auto_switch/health.lua`
- Create: `health/squirrel_auto_switch.lua`
- Create: `lua/squirrel_auto_switch/health/init.lua`
- Create: `README.md`
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Implement health diagnostics**

`:checkhealth squirrel_auto_switch` must report:

- supported operating system;
- Neovim version and `vim.system` availability;
- configured executable path and executable status;
- configured input source ID;
- current `--getascii` result when available.

- [ ] **Step 2: Write Chinese user documentation**

Document Lazy.nvim installation from `pzehrel/squirrel-auto-switch.nvim`, defaults, full setup example, behavior table, commands, health check, troubleshooting, and the fact that the plugin does not edit user configuration.

- [ ] **Step 3: Add CI**

Run tests on macOS and Ubuntu with stable Neovim. Controller/config tests must not require Squirrel; only the local smoke check is platform-dependent.

- [ ] **Step 4: Run health check**

Run:

```sh
nvim --headless -u tests/minimal_init.lua \
  +"lua require('squirrel_auto_switch').setup({ notify = false })" \
  +"checkhealth squirrel_auto_switch" \
  +qa
```

Expected: no Lua errors and a readable health report.

### Task 7: Final verification and release-ready commit

**Files:**
- Modify only files created in Tasks 1–6.

- [ ] **Step 1: Run the full test suite**

Run: `make check`

Expected: all tests pass.

- [ ] **Step 2: Inspect repository hygiene**

Run:

```sh
git status --short
git diff --check
rg -n "TODO|FIXME|vim\\.fn\\.system" .
```

Expected: no whitespace errors, placeholders, or synchronous CLI execution.

- [ ] **Step 3: Run an isolated load test**

Run:

```sh
nvim --headless --clean \
  +"set runtimepath^=$PWD" \
  +"lua require('squirrel_auto_switch').setup({ notify = false })" \
  +qa
```

Expected: exit code `0`.

- [ ] **Step 4: Commit and push**

```sh
git add .
git commit -m "feat: implement Squirrel input method auto switching"
git push -u origin main
```

Expected: the initial plugin commit is present on `origin/main`.
