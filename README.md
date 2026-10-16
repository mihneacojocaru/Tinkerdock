# Tinkerdock

macOS app to collect, launch and manage self-built tools (HTML pages, Vite projects, artifacts, scripts) and the Claude Code agents that build them.

## Phases

1. **Shelf** – grid/list with screenshots, inspector, search, favorites, notes, open in app window or browser, Quick Look, drag & drop registration, `tinkerdock.json` manifest, embedded terminal (SwiftTerm), open in iTerm / Finder / Claude Code.
2. **Automation** – watched folders, dev server management, CLI + Claude Code skill for self-registration, git status, menu bar icon, share/export.
3. **Workbench** – herdr integration via CLI/socket API, agent status per project, notifications, start agents with a prompt.
4. **Files & voice** – two-pane file window (create folders, move/copy), dictation, voice command that starts an agent. Later: collections/tags, iCloud sync.

## Stack

SwiftUI, distributed outside the Mac App Store (Developer ID, notarized).
