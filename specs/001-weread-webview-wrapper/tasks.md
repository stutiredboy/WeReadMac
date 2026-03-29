# Tasks: WeRead WebView Wrapper

**Input**: Design documents from `/specs/001-weread-webview-wrapper/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create Xcode project and basic structure

- [x] T001 Create Xcode project `WeReadMac` with SwiftUI lifecycle, deployment target macOS 13.0, bundle ID `com.wereadmac.app`
- [x] T002 [P] Configure App Sandbox entitlements: enable `com.apple.security.network.client` in `WeReadMac/WeReadMac.entitlements`
- [x] T003 [P] Add app icon placeholder to `WeReadMac/Assets.xcassets/AppIcon.appiconset/`

---

## Phase 2: Foundational (Core WebView Infrastructure)

**Purpose**: WKWebView wrapper and navigation policy — MUST be complete before any user story work

**⚠️ CRITICAL**: All user stories depend on this phase

### Tests for Foundation

- [x] T004 [P] Unit tests for navigation policy in `WeReadMacTests/NavigationPolicyTests.swift`: test `weread.qq.com` → allow, `res.weread.qq.com` → allow, `open.weixin.qq.com` → allow, `*.qq.com` → allow, `google.com` → external, URL with no host → allow
- [x] T005 [P] Unit tests for WebView configuration in `WeReadMacTests/WebViewConfigurationTests.swift`: verify persistent data store (not ephemeral), custom User-Agent contains identifier, initial URL is `https://weread.qq.com`

### Implementation

- [x] T006 Implement `NavigationPolicy.swift` in `WeReadMac/NavigationPolicy.swift`: pure function `navigationAction(for: URL) -> NavigationAction` with `.allow` / `.external` enum
- [x] T007 Implement `WebView.swift` in `WeReadMac/WebView.swift`: `NSViewRepresentable` wrapping `WKWebView` with persistent `WKWebsiteDataStore`, custom User-Agent, `WKNavigationDelegate` and `WKUIDelegate` via Coordinator
- [x] T008 Run T004 and T005 tests — verify they pass

**Checkpoint**: WebView component and navigation policy are tested and ready for integration

---

## Phase 3: User Story 1 — 独立窗口阅读微信读书 (Priority: P1) 🎯 MVP

**Goal**: App launches as independent macOS application, loads weread.qq.com in a native window with Dock icon and Cmd+Tab support

**Independent Test**: Launch app → weread.qq.com loads → visible in Dock and Cmd+Tab switcher

### UI Tests for User Story 1

- [x] T009 UI test in `WeReadMacUITests/LaunchTests.swift`: app launches successfully, window appears, WebView exists and loads content

### Implementation for User Story 1

- [x] T010 Implement `ContentView.swift` in `WeReadMac/ContentView.swift`: hosts `WebView` with `minWidth: 800, minHeight: 600`
- [x] T011 Implement `WeReadMacApp.swift` in `WeReadMac/WeReadMacApp.swift`: `@main` App struct with `WindowGroup`, `.defaultSize(width: 1200, height: 800)`
- [x] T012 Run T009 UI test — verify app launches and loads weread.qq.com

**Checkpoint**: App is a functional standalone macOS application that loads weread.qq.com — MVP deliverable

---

## Phase 4: User Story 2 — 登录并保持会话 (Priority: P1)

**Goal**: User can log in via WeChat QR scan, session persists across app restarts

**Independent Test**: Log in → quit app → relaunch → still logged in

### Implementation for User Story 2

- [x] T013 [US2] Handle `createWebViewWith configuration` in Coordinator (`WebView.swift`): load `window.open()` requests (login popup) in the existing WebView instead of ignoring them
- [x] T014 [US2] Handle JavaScript `alert()`, `confirm()`, `prompt()` dialogs in Coordinator via `WKUIDelegate` methods → forward to native `NSAlert`
- [x] T015 [US2] Manual verification: launch app, complete WeChat QR login, quit and relaunch, confirm session persists (document result in PR)

**Checkpoint**: Login flow works end-to-end, session survives app restart

---

## Phase 5: User Story 3 — 窗口状态恢复 (Priority: P2)

**Goal**: Window position and size restored on next launch

**Independent Test**: Resize/move window → quit → relaunch → window appears at same position and size

### Implementation for User Story 3

- [x] T016 [US3] Set `NSWindow.setFrameAutosaveName("WeReadMainWindow")` on the window backing the WebView — access via `NSViewRepresentable` lifecycle in `WebView.swift` or via `NSApplication.shared.windows`
- [x] T017 [US3] Manual verification: move and resize window, quit, relaunch, confirm position/size restored

**Checkpoint**: Window state persists across launches

---

## Phase 6: User Story 4 — 基础导航支持 (Priority: P2)

**Goal**: Browser-like keyboard shortcuts for navigation (back, forward, reload)

**Independent Test**: Navigate to a book → Cmd+[ to go back → Cmd+] to go forward → Cmd+R to reload

### Implementation for User Story 4

- [x] T018 [US4] Add menu commands in `WeReadMacApp.swift` via `.commands { CommandGroup }`: Cmd+R (reload), Cmd+[ (back), Cmd+] (forward)
- [x] T019 [US4] Wire menu commands to WebView actions using `@FocusedValue` or `NotificationCenter` to communicate between menu commands and `WebView.swift`
- [x] T020 [US4] Manual verification: navigate through pages, test Cmd+R / Cmd+[ / Cmd+] / Cmd+C / Cmd+V

**Checkpoint**: Standard browser navigation shortcuts work in-app

---

## Phase 7: User Story 5 — 外部链接处理 (Priority: P3)

**Goal**: Non-weread.qq.com links open in system browser, internal links stay in-app

**Independent Test**: Click external link → opens in Safari; click internal link → navigates in-app

### Implementation for User Story 5

- [x] T021 [US5] Implement `decidePolicyFor navigationAction` in Coordinator (`WebView.swift`): call `navigationAction(for:)` from `NavigationPolicy.swift`, if `.external` → `NSWorkspace.shared.open(url)` and cancel navigation
- [x] T022 [US5] UI test in `WeReadMacUITests/NavigationTests.swift`: verify external URL navigation is cancelled (mock or intercept)
- [x] T023 [US5] Manual verification: find an external link on weread.qq.com, click it, confirm it opens in system browser

**Checkpoint**: All user stories complete — external links handled correctly

---

## Phase 8: Polish & Cross-Cutting

**Purpose**: Dark mode, edge cases, final quality pass

- [x] T024 [P] Ensure app window follows system appearance (dark/light mode) — verify `NSWindow.appearance` is nil (inherits system) in `WebView.swift`
- [x] T025 [P] Handle network error: implement `didFailProvisionalNavigation` in Coordinator — show native error view or alert with retry option
- [x] T026 [P] Handle download requests: implement `navigationResponse` policy for non-HTML content types — trigger system save dialog via `NSSavePanel`
- [x] T027 Run full test suite (unit + UI tests), fix any failures
- [x] T028 Build release configuration, verify app launches standalone outside Xcode

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundation) → Phase 3 (US1/MVP) → Phase 4 (US2) → Phase 5-7 (US3-5) → Phase 8 (Polish)
                                                                    ↑
                                                              Can run in parallel:
                                                              Phase 5, 6, 7 are independent
```

- **Phase 1**: No dependencies — start immediately
- **Phase 2**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 2 — MVP milestone
- **Phase 4 (US2)**: Depends on Phase 3 (needs working WebView + app shell)
- **Phase 5, 6, 7**: Each depends on Phase 3, but are independent of each other — can run in parallel
- **Phase 8**: Depends on all desired user stories

### Within Each Phase

- Tests MUST be written and FAIL before implementation (TDD per constitution)
- Commit after each task or logical group
- Manual verification tasks document results in PR description

---

## Implementation Strategy

### MVP First (Phases 1-3)

1. Setup Xcode project
2. Implement + test NavigationPolicy and WebView wrapper
3. Wire up ContentView + App entry point
4. **STOP**: App launches, loads weread.qq.com — usable MVP

### Full Delivery (Phases 1-8)

Sequential: Setup → Foundation → MVP → Login → Window restore → Navigation → External links → Polish

**Estimated task count**: 28 tasks across 8 phases
