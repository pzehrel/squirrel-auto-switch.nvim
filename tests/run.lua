local total = 0
local failed = 0
local current_suite = ""

local function inspect(value)
  return vim.inspect(value)
end

function _G.describe(name, fn)
  current_suite = name
  io.write("\n" .. name .. "\n")
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    failed = failed + 1
    io.write("  suite error: " .. err .. "\n")
  end
end

function _G.it(name, fn)
  total = total + 1
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    io.write("  ✓ " .. name .. "\n")
  else
    failed = failed + 1
    io.write("  ✗ " .. name .. "\n")
    io.write("    " .. err:gsub("\n", "\n    ") .. "\n")
  end
end

function _G.assert_equal(expected, actual)
  if not vim.deep_equal(expected, actual) then
    error(("expected %s, got %s"):format(inspect(expected), inspect(actual)), 2)
  end
end

function _G.assert_true(value)
  if value ~= true then
    error(("expected true, got %s"):format(inspect(value)), 2)
  end
end

function _G.assert_false(value)
  if value ~= false then
    error(("expected false, got %s"):format(inspect(value)), 2)
  end
end

local specs = vim.fn.glob("tests/*_spec.lua", false, true)
table.sort(specs)

for _, path in ipairs(specs) do
  local ok, err = xpcall(dofile, debug.traceback, path)
  if not ok then
    failed = failed + 1
    io.write(("\nFailed to load %s\n%s\n"):format(path, err))
  end
end

io.write(("\n%d tests, %d failures\n"):format(total, failed))

if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
