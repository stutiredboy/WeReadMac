# Implementation Plan: WeRead WebView Wrapper

**Branch**: `001-weread-webview-wrapper` | **Date**: 2026-03-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-weread-webview-wrapper/spec.md`

## Summary

将 weread.qq.com 封装为独立 macOS 应用，使用 SwiftUI App lifecycle + WKWebView 实现。核心是一个单窗口应用，内嵌 WKWebView 加载微信读书网页，通过持久化 WKWebsiteDataStore 保持登录会话，通过 WKNavigationDelegate 控制链接导航策略。

## Technical Context

**Language/Version**: Swift 5.9+, Xcode 15+
**Primary Dependencies**: WebKit (WKWebView), SwiftUI, AppKit (NSWindow integration)
**Storage**: WKWebsiteDataStore (default persistent store — cookies, localStorage, IndexedDB)
**Testing**: XCTest (unit tests), XCUITest (UI tests)
**Target Platform**: macOS 13 (Ventura)+
**Project Type**: desktop-app (single-window WebView wrapper)
**Performance Goals**: Cold start < 3s, app overhead < 50 MB RAM
**Constraints**: No third-party dependencies; Apple frameworks only
**Scale/Scope**: Single window, single WebView, ~5 source files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Code Quality First | PASS | Pure Swift, Apple frameworks only, minimal code surface |
| II. TDD (NON-NEGOTIABLE) | PASS | Unit tests for navigation delegate logic, UI tests for launch/navigation flows |
| III. UX Consistency | PASS | Native NSWindow + WKWebView, follows HIG, supports dark mode, localized strings |
| IV. Performance | PASS | Minimal app shell, WebView performance delegated to WebKit engine |
| V. Simplicity | PASS | ~5 source files, no abstractions beyond what's needed |
| Security | PASS | WKWebsiteDataStore handles credential storage; TLS enforced by WebKit; no custom data handling |

**Complexity Justification**: None required. This is a minimal single-window app with no architectural complexity.

## Architecture

### Design Approach

The app follows a thin-shell architecture: the application is a minimal native container around WKWebView. Almost all functionality is provided by WebKit and the weread.qq.com web application itself.

```
┌─────────────────────────────────────────┐
│ WeReadMacApp (SwiftUI App lifecycle)    │
│  └─ ContentView                         │
│      └─ WebView (NSViewRepresentable)   │
│          ├─ WKWebView                   │
│          │   ├─ WKWebViewConfiguration  │
│          │   │   └─ WKWebsiteDataStore  │ ← persistent (cookies/localStorage)
│          │   ├─ WKNavigationDelegate    │ ← URL filtering (internal vs external)
│          │   └─ WKUIDelegate            │ ← new window / alert handling
│          └─ Coordinator                 │
│              └─ navigation + UI logic   │
└─────────────────────────────────────────┘
```

### Key Design Decisions

1. **NSViewRepresentable over pure SwiftUI**: WKWebView has no SwiftUI equivalent. Wrap it via `NSViewRepresentable` for full control over configuration and delegates.

2. **Default WKWebsiteDataStore (not custom)**: The default persistent data store automatically saves cookies and web data to disk, surviving app restarts. No need for manual cookie management.

3. **Navigation policy in WKNavigationDelegate**: `decidePolicyFor navigationAction` inspects the target URL. If the host is `weread.qq.com` (or subdomains like `res.weread.qq.com`), allow in-app navigation. Otherwise, open in the system browser via `NSWorkspace.shared.open()` and cancel the WebView navigation.

4. **New window handling in WKUIDelegate**: `createWebViewWith configuration` handles `window.open()` calls (e.g., WeChat login popup). Load the request in the existing WebView or open a sheet/popover rather than ignoring it.

5. **Window state via NSWindow.setFrameAutosaveName**: One line of code provides persistent window position/size across launches. Accessed through SwiftUI's WindowGroup or via NSViewRepresentable's `makeNSView` accessing the window.

6. **User-Agent strategy**: Append custom identifier to the default WKWebView User-Agent rather than replacing it entirely. This preserves WebKit's default UA (which weread.qq.com expects for desktop rendering) while identifying the app.

## Project Structure

### Documentation (this feature)

```text
specs/001-weread-webview-wrapper/
├── spec.md              # Feature specification
├── plan.md              # This file
└── tasks.md             # Task list (created by /speckit.tasks)
```

### Source Code (repository root)

```text
WeReadMac/
├── WeReadMacApp.swift          # App entry point, WindowGroup configuration
├── ContentView.swift           # Main view hosting the WebView
├── WebView.swift               # NSViewRepresentable wrapping WKWebView + Coordinator
├── NavigationPolicy.swift      # URL filtering logic (internal vs external domains)
├── Info.plist                   # App metadata (or via Xcode project settings)
└── Assets.xcassets/
    └── AppIcon.appiconset/     # App icon

WeReadMacTests/
├── NavigationPolicyTests.swift # Unit tests for URL filtering logic
└── WebViewTests.swift          # Unit tests for WebView configuration

WeReadMacUITests/
├── LaunchTests.swift           # UI test: app launches and loads weread.qq.com
└── NavigationTests.swift       # UI test: navigation, refresh, external links
```

**Structure Decision**: Single Xcode project with one app target + two test targets (unit + UI). No packages, no frameworks — minimal structure matching the minimal scope.

### Xcode Project Setup

- **Project**: `WeReadMac.xcodeproj`
- **Target**: `WeReadMac` (macOS App, SwiftUI lifecycle)
- **Bundle Identifier**: `com.wereadmac.app` (adjustable)
- **Deployment Target**: macOS 13.0
- **Signing**: Sign to Run Locally (development), or Developer ID for distribution
- **Entitlements**:
  - `com.apple.security.network.client` = YES (outgoing network connections)
  - App Sandbox enabled

## Component Design

### 1. WeReadMacApp.swift

```swift
// SwiftUI App entry point
@main
struct WeReadMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
    }
}
```

- Single `WindowGroup` scene
- Default window size 1200x800
- Window frame autosave handled by NSWindow integration

### 2. WebView.swift (NSViewRepresentable)

**Responsibilities**:
- Create and configure `WKWebView` with persistent `WKWebsiteDataStore`
- Set custom User-Agent
- Assign `WKNavigationDelegate` and `WKUIDelegate` (via Coordinator)
- Load `https://weread.qq.com` on initial display
- Expose actions: `reload()`, `goBack()`, `goForward()`

**Coordinator**:
- Implements `WKNavigationDelegate.decidePolicyFor:` → delegates to `NavigationPolicy`
- Implements `WKUIDelegate.createWebViewWith:` → handles new window requests in-app
- Implements `WKUIDelegate` alert/confirm/prompt methods → forwards to native dialogs

### 3. NavigationPolicy.swift

Pure function, independently testable:

```swift
enum NavigationAction {
    case allow    // Navigate within WebView
    case external // Open in system browser
}

func navigationAction(for url: URL) -> NavigationAction {
    guard let host = url.host?.lowercased() else { return .allow }
    if host == "weread.qq.com" || host.hasSuffix(".weread.qq.com") {
        return .allow
    }
    // Also allow WeChat OAuth domains for login flow
    if host == "open.weixin.qq.com" || host.hasSuffix(".qq.com") {
        return .allow
    }
    return .external
}
```

**Note**: The domain allowlist may need adjustment after testing the actual login flow. WeChat OAuth may redirect through multiple qq.com subdomains. Initial approach: allow all `*.qq.com` domains internally, restrict only truly external domains.

### 4. ContentView.swift

```swift
struct ContentView: View {
    var body: some View {
        WebView(url: URL(string: "https://weread.qq.com")!)
            .frame(minWidth: 800, minHeight: 600)
    }
}
```

Minimal wrapper. Menu bar actions (Back/Forward/Reload) can be wired via `.commands` modifier on the WindowGroup or via `@FocusedValue`.

### 5. Menu Bar / Keyboard Shortcuts

Standard Edit menu (Copy/Paste/SelectAll) is provided by SwiftUI by default. Additional commands:

| Shortcut | Action | Implementation |
|----------|--------|----------------|
| Cmd+R | Reload page | Custom command → `webView.reload()` |
| Cmd+[ | Go back | Custom command → `webView.goBack()` |
| Cmd+] | Go forward | Custom command → `webView.goForward()` |
| Cmd+Q | Quit | Built-in |
| Cmd+W | Close window | Built-in |
| Cmd+C/V/A | Copy/Paste/SelectAll | Built-in (WKWebView handles internally) |

## Testing Strategy

### Unit Tests (NavigationPolicyTests)

- `weread.qq.com` → `.allow`
- `res.weread.qq.com` → `.allow`
- `open.weixin.qq.com` → `.allow`
- `google.com` → `.external`
- `example.com` → `.external`
- URL with no host → `.allow`
- Empty/nil edge cases

### Unit Tests (WebViewTests)

- WebView configuration uses persistent (non-ephemeral) data store
- Custom User-Agent is set and contains expected identifier
- Initial URL is `https://weread.qq.com`

### UI Tests

- App launches successfully and window appears
- WebView loads content (check for existence of web content element)
- Window title or content updates after navigation

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| weread.qq.com blocks WKWebView UA | Low | High | Adjust User-Agent to match Safari exactly |
| WeChat login flow uses unsupported redirect | Medium | High | Allow broad `*.qq.com` domain; test login flow manually |
| WKWebView doesn't persist all cookies | Low | Medium | Default data store is persistent; verify with manual test |
| App Sandbox blocks WebView networking | Low | High | Add `com.apple.security.network.client` entitlement |

## Complexity Tracking

No constitution violations. Single-window app with ~5 source files, zero third-party dependencies.
