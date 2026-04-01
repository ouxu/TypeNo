# TypeNo

[English](README.md) | [日本語](README_JP.md)

**免费、开源的 macOS 手机输入工具。**

![TypeNo 宣传图](assets/hero.webp)

一个极简的 macOS 菜单栏应用。你可以在手机上打开本地页面输入文字，然后把内容发送到 Mac。

官方网站：[https://typeno.com](https://typeno.com)

## 使用方式

1. 从菜单栏启动 TypeNo
2. 保持 **手机输入** 为开启状态
3. 在手机上打开本地链接
4. 在手机页面输入并发送
5. 如果已开启辅助功能权限，TypeNo 会直接粘贴到当前 Mac 应用；否则会复制到剪贴板

## 安装

### 方式一：直接下载

- [下载 TypeNo for macOS](https://github.com/marswaveai/TypeNo/releases/latest)
- 下载最新的 `TypeNo.app.zip`
- 解压后将 `TypeNo.app` 拖到 `/Applications`
- 打开 TypeNo

TypeNo 已通过 Apple 签名和公证，可以直接打开使用。

### 首次启动

TypeNo 只有一个可选权限：
- **辅助功能** — 如果你希望应用把手机传来的内容直接粘贴到当前应用，则需要开启

如果未开启辅助功能权限，文本仍会复制到剪贴板。

### 常见问题：辅助功能权限无效

部分用户在**系统设置 → 隐私与安全性 → 辅助功能**中开启 TypeNo 后仍无法使用——这是 macOS 的一个已知 bug。解决方法：

1. 在列表中选中 **TypeNo**
2. 点击 **−** 删除它
3. 点击 **+**，从 `/Applications` 重新添加 TypeNo

![辅助功能权限修复](assets/accessibility-fix.gif)

### 方式二：从源码构建

```bash
git clone https://github.com/marswaveai/TypeNo.git
cd TypeNo
scripts/generate_icon.sh
scripts/build_app.sh
```

应用位于 `dist/TypeNo.app`。移动到 `/Applications/` 以获得持久权限。

## 操作方式

| 操作 | 入口 |
|---|---|
| 开启/关闭手机输入 | 菜单栏 → 开启/关闭手机输入 |
| 在本机打开手机页面 | 菜单栏 → 打开手机页面 |
| 复制本地链接 | 菜单栏 → 复制链接 |
| 开启直接粘贴权限 | 菜单栏 → 开启粘贴权限 |
| 检查更新 | 菜单栏 → Check for Updates... |
| 退出 | 菜单栏 → Quit（`⌘Q`） |

## 设计理念

TypeNo 只做一件事：手机输入 → Mac 插入。没有录音，没有语音引擎，没有多余的设置流程。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=marswaveai/TypeNo&type=Date)](https://star-history.com/#marswaveai/TypeNo&Date)

## 许可证

GNU General Public License v3.0
