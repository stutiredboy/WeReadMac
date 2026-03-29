# WeReadMac

将[微信读书](https://weread.qq.com)网页版封装为独立的 macOS 应用，解决日常在浏览器中使用时标签页容易被误关闭的问题。

## 功能特性

- 独立的 macOS 应用，拥有独立的 Dock 图标和 Cmd+Tab 切换支持
- 基于 WKWebView，完整支持微信读书网页版所有功能（书架、阅读、笔记、搜索等）
- 登录状态持久化，关闭重开无需重复登录
- 窗口位置和大小自动记忆
- 浏览器快捷键支持：Cmd+R（刷新）、Cmd+[（后退）、Cmd+]（前进）
- 外部链接自动在系统浏览器中打开
- 支持自定义 User-Agent（设置 → Cmd+,）
- 自动跟随系统深色/浅色模式
- 网络异常时显示友好提示页面

## 系统要求

- macOS 13 (Ventura) 或更高版本

## 安装

### 方式一：下载 DMG（推荐）

1. 在 [Releases](../../releases) 页面下载最新的 `WeReadMac.dmg`
2. 双击打开 DMG 文件
3. 将 `WeReadMac.app` 拖入 `Applications` 文件夹
4. 首次打开时，如果系统提示"无法验证开发者"，请前往 **系统设置 → 隐私与安全性** 点击"仍要打开"

### 方式二：从源码编译

```bash
git clone git@github.com:stutiredboy/WeReadMac.git
cd WeReadMac
xcodebuild -project WeReadMac.xcodeproj -scheme WeReadMac -configuration Release build
```

或者使用 Xcode 打开 `WeReadMac.xcodeproj`，选择 Release 配置后 Cmd+R 运行。

## 技术实现

- Swift + SwiftUI (App lifecycle) + WKWebView
- 使用系统默认 `WKWebsiteDataStore` 持久化 cookies 和 localStorage
- 零第三方依赖，仅使用 Apple 原生框架

## 免责声明

本项目仅供个人学习和方便使用，不产生任何收益，不作为商业软件使用。本项目与腾讯、微信读书官方无任何关联。

**使用本软件即表示您同意以下条款：**

- 本软件按"原样"提供，不作任何明示或暗示的保证
- 作者不对因使用该软件造成的任何直接或间接损失承担责任
- 用户应自行承担使用本软件的所有风险
- 本软件不得用于任何违反微信读书服务条款的行为
- 如微信读书官方认为本项目侵犯其权益，请联系作者，将及时处理

## 许可证

[MIT License](LICENSE)
