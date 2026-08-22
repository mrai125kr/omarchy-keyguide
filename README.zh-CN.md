# Omarchy Keyguide

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

> 公开仓库：<https://github.com/mrai125kr/omarchy-keyguide>

Omarchy Keyguide 是面向 Omarchy 的快捷键提示 HUD，并提供范围受限的安全快捷键
编辑功能。按住 `Super` 与 `Ctrl`、`Shift`、`Alt` 组成的八种组合时，它只显示
当前有效的快捷键。HUD 不会抓取、消耗或模拟输入，也不会直接修改 Omarchy 的
用户 `bindings.lua` 文件。

## 主要功能

- 设置 HUD 的位置、缩放、透明度、主题跟随、可见组合和单独条目
- 空闲按键在居中弹窗中注册，已有按键可在对应行附近的弹窗中修改或移除
- 在同一搜索框中查找并注册常规操作、已安装应用和命令
- 设置界面与 HUD 支持英语（默认）、韩语、日语、简体中文和西班牙语
- 使用完整的 Hyprland 运行时列表检查冲突，包括菜单中隐藏的绑定
- 根据当前 XKB 键盘布局解析物理 `code:` 按键冲突
- 一键恢复 Keyguide 初始设置、原快捷键，并删除由 Keyguide 新增的快捷键
- 在冲突、并发修改或重载结果不一致时精确回滚

完整设置界面会按修饰键组显示当前绑定。从按键选择器选择空闲按键时，注册弹窗
会在中央打开；点击已有条目的 `Change` 时，同一编辑弹窗会在该条目附近打开。
每个按键均标有 `Free` 或 `Assigned — <标题>`。已分配按键会显示可编辑标题、
操作类型与参数、`Current key`，以及 `Omarchy default` 或
`Managed by Keyguide` 状态。每行的 `Shown`/`Hidden`、`Change` 和
`Remove`（移除）可独立操作。移除后该组合会变为空闲按键；可恢复的原始绑定可
通过 `Reset all` 还原。

空闲按键可在一个搜索框中选择能够安全重建的 Omarchy 操作、已安装的图形应用
或可执行命令。常规操作既可用当前界面语言搜索，也可用英文搜索。应用行会显示
桌面图标，命令行则以 `(CMD)` 标识。选择器打开期间，新增或删除的应用和命令会
自动刷新；可选参数仅在命令类型下显示。注册现有操作时会将其从原按键**移动**
到新按键，而不会创建副本。更改已分配按键时，界面会显示将被移除的操作名称，
并要求再次明确确认。

无法更改的绑定仍可独立设置是否在 HUD 中显示，并会给出具体原因，而不是笼统
标记为只读。原因包括：

- `Mouse binding`、`Duplicate chord`、`Unsupported key`
- `Action cannot be reconstructed`
- `Ambiguous action metadata`、`Malformed action record`
- `Unsupported action kind`

如果目标按键已经被使用，Keyguide 会显示错误并拒绝保存。它会在发布前以及
Hyprland 重载后再次验证实际运行时状态，因此不会把重复绑定误报为成功。无法
安全解析的物理按键会使编辑操作安全失败。

`Reset all`（全部重置）只重置 Keyguide 管理的内容：恢复被 Keyguide 移动或
替换的原快捷键及标题，删除 Keyguide 新增的快捷键，并恢复 HUD 的初始显示
设置。它不会重置其他 Omarchy、Hyprland 或插件设置。

## 兼容性与安装准备

目标环境为 Omarchy `4.0.0-1` 和 Hyprland `0.56.2` 或更高版本。运行时需要
Python 3、`xkbcli` 和可读取的键盘事件设备；从源码或 Git 插件安装还需要 C
编译器（Arch Linux 上的 `base-devel`）。

可使用以下命令直接从 GitHub 安装：

```sh
omarchy plugin add https://github.com/mrai125kr/omarchy-keyguide.git --enable
```

Git 插件可用 `omarchy plugin update mrai.keyguide --yes` 更新，并用
`omarchy plugin remove mrai.keyguide` 删除。在源码目录中可使用 `make test`
验证、`make install` 安装、`make uninstall` 删除。

## 安全原则

- 不修改 `/usr/share/omarchy/` 或 `~/.config/hypr/bindings.lua`。
- 快捷键变更只原子写入用户状态目录中的一个 Keyguide 专用 Lua 模块。
- 普通卸载会保留用户的显示偏好和独立管理的快捷键状态。
- 卸载程序只处理经过验证的自有文件列表，不会递归删除用户配置。

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。
