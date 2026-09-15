# Dev Server 监视器

macOS 原生置顶浮窗，实时列出本机所有 dev server（Vite、Next、python http.server 等），鼠标点一下「关闭」即可结束对应进程。

解决"启动项目时端口一路从 5173 排到 5178，却不知道哪些旧 server 还挂着"的问题。

## 功能

- 列出本机所有 dev server：端口号 + 项目名（按端口排序）
- 每行一个「关闭」按钮，单击结束对应进程
- 「全部关闭」一键清空所有 dev server
- 窗口始终置顶，不被其他窗口遮挡
- 手动刷新（点「刷新」按钮），不自动轮询

可识别的进程：`node` / `bun` / `deno` / `python` / `ruby` / `php` / `serve` / `http-server` 等。

## 环境要求

- macOS
- Xcode Command Line Tools（自带 `swiftc`，编译用）

```bash
xcode-select --install   # 没装过的话先执行这个
```

无需安装任何第三方依赖。

## 编译

```bash
./build.sh
```

生成 `DevServerMonitor.app`（同时生成同名的裸二进制 `DevServerMonitor`，两者都已加入 .gitignore）。

## 启动

双击 `DevServerMonitor.app` 即可；也可以：

- 拖到「程序坞」固定，随时点开
- 拖到 `~/Applications` 或 `/Applications`，用启动台/Spotlight 搜索 `DevServerMonitor` 打开
- 命令行启动：`open DevServerMonitor.app`

## 使用

| 操作 | 说明 |
|------|------|
| 「刷新」 | 重新扫描本机 dev server |
| 每行「关闭」 | 结束该进程（发送 SIGTERM），列表随即刷新 |
| 「全部关闭」 | 结束列表中所有 dev server |
| 拖拽窗口边缘 | 调整窗口大小，内容从顶部排列 |

原理：通过 `lsof -iTCP -sTCP:LISTEN` 找到监听端口的开发进程，再取其工作目录的最后一段作为项目名展示。

## 目录结构

```
main.swift   # 全部源码（数据采集 + AppKit 界面）
build.sh     # 编译脚本，生成 DevServerMonitor.app
```
