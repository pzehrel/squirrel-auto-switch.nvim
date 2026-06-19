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

```lua
require("squirrel_auto_switch").setup({
  -- Squirrel CLI 路径
  executable = "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel",

  -- macOS 中的 Squirrel 输入源 ID
  input_source = "im.rime.inputmethod.Squirrel.Hans",

  -- 设置 ascii/nascii 前自动选择 Squirrel 输入源
  auto_activate = true,

  -- 第一次进入 Insert 时使用的状态
  -- 支持 "ascii"、"nascii"、"english"、"chinese"
  default_insert_state = "ascii",

  -- 进入 Insert／Replace 时恢复上一次状态
  restore_on_insert_enter = true,

  -- 处理 FocusGained／FocusLost
  sync_on_focus = true,

  -- 单次 CLI 调用超时
  timeout_ms = 3000,

  -- 显示错误通知
  notify = true,

  -- 显示调试日志
  debug = false,

  -- 相同错误通知的节流时间
  error_throttle_ms = 30000,
})
```

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

```sh
make test
```

测试使用隔离的最小 Neovim 配置，不会加载或修改本机配置。

## License

MIT
