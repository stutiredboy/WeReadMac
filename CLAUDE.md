# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WeReadMac is a macOS desktop wrapper application for weread.qq.com (微信读书), built with Swift/SwiftUI and WKWebView. It intercepts WeRead's highlight and thought API calls via JavaScript injection, persists captured notes to an encrypted CoreData store, and provides search and export (Markdown/JSON) capabilities. The repository uses **Specify (speckit) v0.4.3**, a spec-driven development framework that structures feature work through specifications, plans, and tasks before implementation begins.

## Specify Workflow

Features follow a strict pipeline. Each feature lives on a numbered branch (e.g., `001-feature-name`) with artifacts stored in `specs/<branch-name>/`:

1. **Specify** — Write a feature specification (`spec.md`) with user scenarios, acceptance criteria (P1–P3), and success criteria
2. **Clarify** — Resolve ambiguities in the spec
3. **Plan** — Create a technical implementation plan (`plan.md`) covering data model, contracts, and project structure
4. **Tasks** — Generate phased task list (`tasks.md`): Phase 1 (setup), Phase 2 (foundations), Phase 3+ (user stories by priority)
5. **Implement** — Execute tasks against the spec and plan

The project constitution (`.specify/memory/constitution.md`) defines core principles — it must be filled in before implementation begins.

## Key Directories

- `.specify/` — Speckit configuration, templates, scripts, and memory
- `.specify/templates/` — Document templates (spec, plan, tasks, checklist, constitution)
- `.specify/scripts/bash/` — Helper scripts (common.sh, check-prerequisites.sh, setup-plan.sh, create-new-feature.sh)
- `.github/prompts/` — AI prompt templates for each workflow step (speckit.specify, speckit.plan, etc.)
- `specs/<feature>/` — Per-feature artifacts: spec.md, plan.md, tasks.md, research.md, data-model.md, contracts/

## Branch Naming

Feature branches use sequential numbering: `001-feature-name`, `002-feature-name`, etc. The speckit scripts validate this convention and use the numeric prefix to locate the corresponding spec directory.

## Template Resolution

Templates resolve in priority order: project overrides → presets → extensions → core templates. Override a core template by placing a file with the same name in `.specify/templates/overrides/`.

## Active Technologies
- Swift 5.9+, macOS 13.0+ (Ventura)
- WebKit (WKWebView, WKUserContentController, WKScriptMessageHandler) — WebView hosting and JS↔Native bridge
- CoreData (NSPersistentContainer) with encrypted persistent store — local notes persistence
- SwiftUI — UI framework for notes search, browsing, and export views
- JavaScript (intercept.js) — fetch/XHR monkey-patching for API interception
- JavaScript response interception (fetch clone + XHR load event) for bookmarklist sync (003-bookmark-list-sync)

## WeRead API Endpoints
- `/web/book/addBookmark` (POST) — create highlight (markText is base64-encoded)
- `/web/book/removeBookmark` (POST) — delete highlight (bookmarkId = `{bookId}_{chapterUid}_{range}`)
- `/web/review/add` (POST) — create thought (content/abstract are plaintext)
- `/web/book/info?bookId=` (GET) — book metadata
- `/web/book/chapterInfos` (POST) — chapter list
- `/web/book/bookmarklist?bookId=` (GET) — fetch all bookmarks for a book (markText is plaintext, createTime in seconds)

## Recent Changes
- 003-bookmark-list-sync: Bookmark list sync on book open — intercept bookmarklist GET response, batch-dedup by bookmarkId, insert missing highlights to CoreData, per-bookId sync lock to skip concurrent requests, build-dmg.sh packaging script
- 002-local-notes-capture: JS interception of WeRead highlights/thoughts, CoreData persistence with base64 decoding, book/chapter info enrichment, keyword search, Markdown/JSON export, delete sync via composite bookmarkId
