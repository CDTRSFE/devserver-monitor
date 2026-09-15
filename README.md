# Dev Server 监视器

置顶浮窗，实时列出本机所有 dev server（Vite、Next、python http.server 等），鼠标点一下「关闭」即可结束对应进程。支持 macOS 和 Windows。

解决"启动项目时端口一路从 5173 排到 5178，却不知道哪些旧 server 还挂着"的问题。

## 功能

- 列出本机所有 dev server：端口号 + 项目名（按端口排序）
- 每行一个「关闭」按钮，单击结束对应进程
- 「全部关闭」一键清空所有 dev server
- 窗口始终置顶，不被其他窗口遮挡
- 手动刷新（点「刷新」按钮），不自动轮询

可识别的进程：`node` / `bun` / `deno` / `python` / `ruby` / `php` / `serve` / `http-server` 等。

## macOS 使用

### 环境要求

- Xcode Command Line Tools（自带 `swiftc`，编译用），无第三方依赖

```bash
xcode-select --install   # 没装过的话先执行这个
```

### 编译

```bash
./build.sh
```

生成 `DevServerMonitor.app`（同时生成同名的裸二进制 `DevServerMonitor`，两者都已加入 .gitignore）。

### 启动

双击 `DevServerMonitor.app` 即可；也可以：

- 拖到「程序坞」固定，随时点开
- 拖到 `~/Applications` 或 `/Applications`，用启动台/Spotlight 搜索 `DevServerMonitor` 打开
- 命令行启动：`open DevServerMonitor.app`

## Windows 使用

无需安装任何东西（PowerShell 和 WinForms 系统自带，支持 Win10/Win11）：

- 双击 `启动监视器.bat`；或
- 命令行运行：

```powershell
powershell -ExecutionPolicy Bypass -File devserver-monitor.ps1
```

如果系统提示脚本执行策略限制，`.bat` 启动方式已自动绕过；仍被公司安全软件拦截的话，右键 `devserver-monitor.ps1` →「使用 PowerShell 运行」。

## 操作说明

| 操作 | 说明 |
|------|------|
| 「刷新」 | 重新扫描本机 dev server |
| 每行「关闭」 | 结束该进程，列表随即刷新 |
| 「全部关闭」 | 结束列表中所有 dev server |
| 拖拽窗口边缘 | 调整窗口大小，内容从顶部排列 |

原理：

- macOS：通过 `lsof -iTCP -sTCP:LISTEN` 找到监听端口的开发进程，取其工作目录的最后一段作为项目名
- Windows：通过 `Get-NetTCPConnection` 找到监听进程，从进程命令行中 `node_modules` 的上一级目录推测项目名

## 目录结构

```
main.swift              # macOS 版源码（Swift + AppKit）
build.sh                # macOS 编译脚本，生成 DevServerMonitor.app
devserver-monitor.ps1   # Windows 版（PowerShell + WinForms，免安装）
启动监视器.bat           # Windows 双击启动入口
```
