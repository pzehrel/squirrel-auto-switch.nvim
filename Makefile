.PHONY: test check

test:
	NVIM_LOG_FILE=/tmp/squirrel-auto-switch-nvim.log nvim --headless -u tests/minimal_init.lua -l tests/run.lua

check: test
