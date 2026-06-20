# squirrel-auto-switch.nvim

一个面向 macOS 鼠须管（Squirrel）的 Neovim 输入状态自动切换插件。

它会在 Normal 模式中保证鼠须管处于 ASCII 状态，并记住用户在 Insert／Replace 模式中最后使用的是中文还是英文。再次进入编辑模式时，插件会恢复该状态。

## 行为

| 场景 | 行为 |
|---|---|
| Neovim 启动 | 切换到 ASCII |
| 进入 Insert／Replace | 恢复上一次编辑状态 |
| 离开 Insert／Replace | 查询并记住真实状态，然后切换到 ASCII |
| Normal 模式重新获得焦点 | 强制同步到 ASCII |
| Insert 模式重新获得焦点 | 只读取并记住状态，不覆盖用户选择 |

插件只注册自己的自动命令和用户命令，**不会修改你的 Neovim 配置文件**。

## 要求

- macOS
- Neovim 0.10+
- 鼠须管，并且 Squirrel CLI 位于可执行路径

默认路径：

```text
/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel
```

## 安装

使用 [lazy.nvim](https://github.com/folke/lazy.nvim)：

```lua
{
  "pzehrel/squirrel-auto-switch.nvim",
  config = function()
    require("squirrel_auto_switch").setup()
  end,
}
```

## 配置

下面展示全部配置项。所有参数都可以省略，未提供时使用表格中的默认值。

```lua
require("squirrel_auto_switch").setup({
  executable = "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel",
  input_source = "im.rime.inputmethod.Squirrel.Hans",
  auto_activate = true,
  default_insert_state = "ascii",
  restore_on_insert_enter = true,
  sync_on_focus = true,
  timeout_ms = 3000,
  notify = true,
  debug = false,
  error_throttle_ms = 30000,
})
```

### 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `executable` | `string` | `"/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"` | Squirrel CLI 的完整路径。插件通过它执行状态查询、ASCII 切换和输入源选择；路径不存在或不可执行时，自动切换不会生效。 |
| `input_source` | `string` | `"im.rime.inputmethod.Squirrel.Hans"` | macOS 中的 Squirrel 输入源 ID。仅在 `auto_activate = true` 时使用；不同版本或安装方式的 ID 可能不同。 |
| `auto_activate` | `boolean` | `true` | 每次设置 `ascii`／`nascii` 前，先确保当前 macOS 输入源是 Squirrel。选择失败时会尝试启用输入源并重试。关闭后，插件只操作 Squirrel 的 ASCII 状态，不会主动从其他输入法切到 Squirrel。 |
| `default_insert_state` | `string` | `"ascii"` | 当前 Neovim 会话还没有记忆到 Insert 状态时，第一次进入 Insert／Replace 使用的状态。支持 `"ascii"`、`"nascii"`，也支持更直观的别名 `"english"`、`"chinese"`。 |
| `restore_on_insert_enter` | `boolean` | `true` | 进入 Insert／Replace 时是否恢复上一次编辑状态。设为 `false` 后，插件仍会在离开 Insert 时记忆状态并切到 ASCII，但进入 Insert 时不主动切换。 |
| `sync_on_focus` | `boolean` | `true` | 是否监听 Neovim 窗口焦点变化。Normal 模式重新获得焦点时会强制同步到 ASCII；Insert／Replace 重新获得焦点时只读取并记忆当前状态，不覆盖用户选择。关闭后不注册 `FocusGained` 和 `FocusLost` 自动命令。 |
| `timeout_ms` | `integer` | `3000` | 每次 Squirrel CLI 调用的超时时间，单位为毫秒。超时会被视为本次操作失败，但不会阻塞或中断 Neovim。必须是正整数。 |
| `notify` | `boolean` | `true` | 是否通过 `vim.notify()` 显示 CLI 不存在、查询失败、切换失败等运行时错误。关闭后插件静默降级；健康检查仍可用于排查问题。 |
| `debug` | `boolean` | `false` | 是否输出调试通知，包括实际执行的 Squirrel CLI 命令。通常只在排查路径、输入源或切换时序问题时开启。`notify = false` 时调试通知也不会显示。 |
| `error_throttle_ms` | `integer` | `30000` | 相同错误通知的最小间隔，单位为毫秒，用于防止模式快速切换时重复刷屏。设为 `0` 可关闭节流；必须是非负整数。 |

### 输入状态的含义

插件控制的是 Squirrel 内部状态，而不是两个独立的 macOS 输入法：

| 配置值 | Squirrel CLI | 含义 |
|---|---|---|
| `"ascii"`／`"english"` | `--ascii` | 开启 Squirrel ASCII 模式，直接输入英文字符 |
| `"nascii"`／`"chinese"` | `--nascii` | 关闭 Squirrel ASCII 模式，使用当前 Rime 方案输入 |

`"english"` 和 `"chinese"` 只用于配置可读性，插件内部会分别规范化为 `"ascii"` 和 `"nascii"`。

### `auto_activate` 的影响

默认启用 `auto_activate` 是为了处理这样的场景：用户在其他应用中切换到了 ABC、搜狗输入法或另一个 macOS 输入源，然后返回 Neovim。此时单独执行 Squirrel 的 `--ascii` 可能无法影响当前输入窗口，因此插件会先选择配置的 Squirrel 输入源。

如果你希望保留当前系统输入源，不允许插件主动切回 Squirrel，可以关闭它：

```lua
require("squirrel_auto_switch").setup({
  auto_activate = false,
})
```

关闭后需要确保 Squirrel 本身已经是当前输入源，否则 `--ascii`／`--nascii` 可能不会产生预期效果。

### Insert 状态如何记忆

`default_insert_state` 只负责“尚无历史记录”的首次进入：

1. 第一次进入 Insert 时使用 `default_insert_state`。
2. 用户可以在 Insert 中手动切换中文或英文。
3. 离开 Insert 时，插件查询真实状态并将其记录。
4. 后续进入 Insert 时恢复记录值，不再使用默认值。

状态按整个 Neovim 实例记忆，不区分 buffer、window 或 tab，并且不会跨 Neovim 重启持久化。

## 命令

| 命令 | 说明 |
|---|---|
| `:SquirrelAutoSwitchEnable` | 启用自动切换 |
| `:SquirrelAutoSwitchDisable` | 禁用自动切换 |
| `:SquirrelAutoSwitchToggle` | 切换启用状态 |
| `:SquirrelAutoSwitchSync` | 按当前 Neovim 模式立即同步 |
| `:SquirrelAutoSwitchStatus` | 查看内部状态 |

## 健康检查

```vim
:checkhealth squirrel_auto_switch
```

健康检查会验证：

- 当前操作系统；
- `vim.system` 是否可用；
- Squirrel CLI 是否可执行；
- 输入源 ID；
- 当前 `ascii`／`nascii` 状态。

## 设计说明

所有 Squirrel CLI 调用都通过 `vim.system()` 异步执行，不会使用 `vim.fn.system()` 阻塞 Neovim。

插件把以下状态分别管理：

- 最后确认的真实状态；
- 当前目标状态；
- 上一次 Insert 会话的状态。

切换任务按顺序执行，因此快速进出 Insert 时，较旧的异步回调不会越过较新的操作。

## 故障排查

### 插件没有切换输入法

先运行：

```vim
:checkhealth squirrel_auto_switch
```

如果 CLI 路径不正确，请覆盖 `executable`。

### 使用的 Squirrel 输入源 ID 不同

覆盖 `input_source`。如果不希望插件主动选择输入源：

```lua
require("squirrel_auto_switch").setup({
  auto_activate = false,
})
```

### 希望第一次进入 Insert 默认中文

```lua
require("squirrel_auto_switch").setup({
  default_insert_state = "chinese",
})
```

## 开发

完整检查需要安装：

- [StyLua](https://github.com/JohnnyMorganz/StyLua)
- [Luacheck](https://github.com/lunarmodules/luacheck)
- [actionlint](https://github.com/rhysd/actionlint)

运行测试：

```sh
make test
```

检查 Lua 格式、静态分析、GitHub Actions Workflow 和测试：

```sh
make check
```

自动格式化 Lua：

```sh
make format
```

测试使用隔离的最小 Neovim 配置，不会加载或修改本机配置。

## License

MIT
