# Feature Specification: WeRead WebView Wrapper

**Feature Branch**: `001-weread-webview-wrapper`
**Created**: 2026-03-29
**Status**: Draft
**Input**: User description: "创建一个 macOS 上的应用代替浏览器访问 weread.qq.com。weread.qq.com 是一个网站，没有独立 app，日常通过浏览器使用容易被误关闭，希望快速实现一个 app，可以对 weread.qq.com 做一个套壳，封装成一个独立的 macOS app"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 独立窗口阅读微信读书 (Priority: P1)

用户打开 WeReadMac 应用后，应用在独立窗口中加载 weread.qq.com，用户可以像在浏览器中一样正常浏览、搜索、阅读书籍。应用作为独立进程出现在 Dock 栏和 Cmd+Tab 切换器中，不会与浏览器标签页混淆，也不会被误关闭。

**Why this priority**: 这是应用的核心价值——将网页封装为独立应用，解决"浏览器标签页容易被误关闭"的核心痛点。

**Independent Test**: 启动应用，weread.qq.com 正常加载并可交互，Dock 栏显示应用图标，Cmd+Tab 可切换到此应用。

**Acceptance Scenarios**:

1. **Given** 用户首次启动应用, **When** 应用窗口出现, **Then** 自动加载 `https://weread.qq.com` 并显示网页内容
2. **Given** 应用已启动, **When** 用户在 Dock 栏查看, **Then** 能看到 WeReadMac 的独立图标
3. **Given** 应用已启动且有其他应用在前台, **When** 用户按 Cmd+Tab, **Then** 能在应用切换列表中找到 WeReadMac 并切换到前台
4. **Given** 用户在应用中浏览 weread.qq.com, **When** 用户点击书架中的书籍, **Then** 正常打开书籍详情/阅读页面，所有页面导航在应用内完成

---

### User Story 2 - 登录并保持会话 (Priority: P1)

用户需要登录微信读书才能使用完整功能（书架、阅读进度、笔记等）。应用必须能完成登录流程（微信扫码或其他方式），并在下次启动时保持登录状态，无需重复登录。

**Why this priority**: 不能登录的阅读应用没有实用价值，会话持久化直接决定日常使用体验。

**Independent Test**: 在应用中完成微信扫码登录，关闭应用后重新打开，仍处于登录状态。

**Acceptance Scenarios**:

1. **Given** 用户未登录, **When** 用户在应用内发起登录（如扫码）, **Then** 登录流程正常完成，页面刷新为已登录状态
2. **Given** 用户已登录并关闭应用, **When** 用户重新启动应用, **Then** 仍然处于登录状态，无需再次登录
3. **Given** 用户已登录, **When** 用户访问书架、阅读记录等需要登录的功能, **Then** 功能正常可用

---

### User Story 3 - 窗口状态恢复 (Priority: P2)

用户关闭并重新打开应用时，窗口位置和大小应恢复到上次关闭时的状态，减少每次启动后的手动调整。

**Why this priority**: 提升日常使用的便利性，但不影响核心功能。

**Independent Test**: 调整窗口大小和位置，关闭应用，重新打开后窗口恢复原来的大小和位置。

**Acceptance Scenarios**:

1. **Given** 用户将窗口拖到屏幕右侧并调大, **When** 关闭应用并重新打开, **Then** 窗口在上次的位置和大小处出现
2. **Given** 用户首次启动应用（无历史记录）, **When** 窗口出现, **Then** 以合理的默认大小居中显示（如 1200x800）

---

### User Story 4 - 基础导航支持 (Priority: P2)

用户可以使用常见的浏览器快捷键和操作在应用内导航，包括后退、前进、刷新页面，以及基础的文本操作（复制、粘贴）。

**Why this priority**: 用户已习惯浏览器操作方式，保持一致性降低学习成本。

**Independent Test**: 在应用中使用 Cmd+[ / Cmd+] 或工具栏按钮进行前进后退，使用 Cmd+R 刷新页面。

**Acceptance Scenarios**:

1. **Given** 用户从首页导航到书籍详情页, **When** 用户按后退操作, **Then** 返回首页
2. **Given** 页面加载异常或需要刷新, **When** 用户按 Cmd+R, **Then** 页面重新加载
3. **Given** 用户选中页面上的文字, **When** 用户按 Cmd+C, **Then** 文字被复制到剪贴板

---

### User Story 5 - 外部链接处理 (Priority: P3)

weread.qq.com 页面中可能包含指向外部网站的链接（如分享链接、客服链接等）。这些链接应在系统默认浏览器中打开，而不是在应用内导航离开微信读书。

**Why this priority**: 边界情况处理，防止应用导航到非微信读书页面后无法返回。

**Independent Test**: 点击一个外部链接，确认在系统浏览器中打开而非在应用内跳转。

**Acceptance Scenarios**:

1. **Given** 页面中有一个外部链接（非 weread.qq.com 域名）, **When** 用户点击该链接, **Then** 链接在系统默认浏览器中打开，应用保持在当前页面
2. **Given** 页面中有一个 weread.qq.com 域内链接, **When** 用户点击该链接, **Then** 在应用内正常导航

---

### Edge Cases

- 网络断开时应用如何表现？应显示友好的离线提示，并在网络恢复后支持手动刷新重新加载
- weread.qq.com 弹出新窗口（如登录扫码弹窗）时如何处理？应在应用内以新窗口或弹出层方式处理，不跳转到外部浏览器
- 页面中的文件下载请求（如导出笔记）如何处理？应使用系统默认下载行为，弹出保存对话框
- 用户 macOS 系统为深色模式时，应用窗口外框（标题栏）应跟随系统外观
- weread.qq.com 请求摄像头/麦克风权限时（如语音朗读功能），应弹出系统权限请求对话框

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 应用 MUST 使用 WKWebView 加载 `https://weread.qq.com` 作为主页面
- **FR-002**: 应用 MUST 持久化 WebView 的 cookies 和本地存储（使用非临时 WKWebsiteDataStore），确保会话跨启动保持
- **FR-003**: 应用 MUST 作为独立 macOS 应用出现在 Dock 和应用切换器中，拥有自定义应用图标
- **FR-004**: 应用 MUST 记住并恢复窗口的位置和大小（使用 NSWindow `setFrameAutosaveName`）
- **FR-005**: 应用 MUST 支持标准键盘快捷键：Cmd+C（复制）、Cmd+V（粘贴）、Cmd+A（全选）、Cmd+R（刷新）、Cmd+Q（退出）
- **FR-006**: 应用 MUST 将非 `weread.qq.com` 域名的导航请求在系统默认浏览器中打开
- **FR-007**: 应用 MUST 正确处理 WKWebView 的新窗口请求（`createWebViewWith configuration`），在应用内处理而非忽略
- **FR-008**: 应用 MUST 跟随 macOS 系统的浅色/深色模式外观
- **FR-009**: 应用 MUST 设置合适的 User-Agent，确保 weread.qq.com 返回桌面版网页

### Key Entities

- **MainWindow**: 应用主窗口，承载 WKWebView，可调整大小，窗口位置自动保存
- **WebView (WKWebView)**: 核心组件，负责加载和渲染 weread.qq.com 网页内容
- **WKWebViewConfiguration + WKWebsiteDataStore**: WebView 配置，管理持久化数据存储（cookies、localStorage、sessionStorage）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 应用冷启动到页面可交互时间 < 3 秒（首次加载受网络影响，后续启动缓存生效后应 < 2 秒）
- **SC-002**: 应用自身内存开销 < 50 MB（WebView 渲染进程独立计算），总内存占用常规使用下 < 300 MB
- **SC-003**: 用户完成登录后，连续 30 天内重新打开应用无需重复登录（取决于 weread.qq.com 服务端 session 策略，应用侧不主动清除数据）
- **SC-004**: weread.qq.com 的核心功能（书架浏览、阅读、划线笔记、搜索）在应用内表现与 Safari 浏览器中一致，无功能缺失

## Assumptions

- 用户使用 macOS 13 (Ventura) 或更高版本
- 用户有稳定的网络连接来访问 weread.qq.com
- weread.qq.com 不会主动阻止 WKWebView 的访问（如通过 User-Agent 检测封锁）；若有此行为，可通过调整 User-Agent 解决
- 应用仅作为 Web 内容的容器，不修改或注入任何页面内容
- 第一个版本不需要支持：通知推送、Touch Bar 集成、菜单栏快捷入口、多窗口等高级功能
- 应用使用 Swift + SwiftUI (App lifecycle) + WKWebView 开发，最低部署目标为 macOS 13
- 不需要上架 Mac App Store，通过直接分发即可
