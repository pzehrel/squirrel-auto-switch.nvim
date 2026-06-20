LUA_PATHS := lua health tests

.PHONY: test format format-check lint check

test:
	NVIM_LOG_FILE=/tmp/squirrel-auto-switch-nvim.log nvim --headless -u tests/minimal_init.lua -l tests/run.lua

format:
	stylua $(LUA_PATHS)

format-check:
	stylua --check $(LUA_PATHS)

lint: format-check
	luacheck $(LUA_PATHS)
	actionlint

check: lint test
