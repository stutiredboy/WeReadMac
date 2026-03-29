# WeReadMac Constitution

## Core Principles

### I. Code Quality First
- All code must be clear, self-documenting, and follow Swift/macOS conventions
- Prefer composition over inheritance; use protocols to define contracts
- No force-unwraps (`!`) outside of IBOutlets — use `guard let` / `if let` consistently
- Functions should do one thing; keep cyclomatic complexity low (max 10 per function)
- Dependencies must be explicitly declared and minimized — prefer Apple frameworks over third-party when capability is equivalent

### II. Test-Driven Development (NON-NEGOTIABLE)
- TDD cycle enforced: write failing test -> implement -> refactor
- Unit test coverage target: 80%+ for business logic and data layers
- UI tests required for every user-facing flow before merging
- Integration tests required for: network layer, persistence layer, and cross-module contracts
- Tests must be deterministic — no flaky tests allowed in CI; quarantine or fix immediately
- Mock external dependencies (network, filesystem) at boundaries only; prefer real objects internally

### III. User Experience Consistency
- Follow Apple Human Interface Guidelines as the baseline for all UI decisions
- Use native macOS controls and patterns (NSToolbar, NSSplitView, keyboard shortcuts) — avoid custom controls unless HIG has no equivalent
- All user-facing strings must be localized via `NSLocalizedString` from day one
- Accessibility is mandatory: every interactive element must have VoiceOver labels and support keyboard navigation
- Visual consistency enforced through a shared design token system (colors, typography, spacing) — no hardcoded values in views
- Animations must respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`

### IV. Performance Requirements
- App launch to interactive: < 1 second (cold start on supported hardware)
- Scrolling and list rendering: 60 fps with no dropped frames
- Memory footprint: < 150 MB for typical use (library of 500 books)
- Network requests must be cancellable, timeout after 15 seconds, and never block the main thread
- Large data operations (import, sync, search indexing) must run on background queues with progress reporting
- Profile with Instruments before and after optimization — no speculative performance work

### V. Simplicity and Incremental Delivery
- Start with the simplest implementation that satisfies acceptance criteria
- YAGNI: do not build for hypothetical future requirements
- Each feature branch must be shippable independently — no long-lived feature flags
- Prefer deleting code over adding compatibility shims

## Security and Data Integrity

- User data (reading progress, annotations, credentials) must be stored in encrypted containers or Keychain
- Network communication must use TLS 1.2+ exclusively
- No sensitive data in logs — sanitize before logging
- Handle Keychain and file-system errors gracefully; never silently drop user data

## Development Workflow

- Every change goes through the Specify pipeline: spec -> plan -> tasks -> implement
- Code review required before merge; reviewer must verify spec compliance
- CI must pass (build + all tests + linter) before merge is allowed
- Commit messages follow Conventional Commits format (`feat:`, `fix:`, `refactor:`, etc.)
- No warnings allowed in release builds — treat warnings as errors in CI

## Governance

- This constitution supersedes all other development practices in the project
- Amendments require: documented rationale, team review, and a migration plan for existing code
- All PRs and reviews must verify compliance with these principles
- When principles conflict, priority order is: Security > Correctness > UX Consistency > Performance > Simplicity

**Version**: 1.0.0 | **Ratified**: 2026-03-29 | **Last Amended**: 2026-03-29
