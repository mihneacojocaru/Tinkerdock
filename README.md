# Tinkerdock

macOS app to collect, launch and manage self-built tools (HTML pages, Vite projects, artifacts, scripts) and the Claude Code agents that build them.

## Download

**[Download Tinkerdock for macOS](https://github.com/mihneacojocaru/Tinkerdock/releases/latest/download/Tinkerdock.zip)** (ZIP, about 1.5 MB) · [all releases](https://github.com/mihneacojocaru/Tinkerdock/releases)

Requires macOS 14 or later.

1. Unzip and move `Tinkerdock.app` to `/Applications`.
2. The app is not notarized yet, so macOS blocks the first launch. Right-click the app › **Open**, or choose **Open Anyway** in System Settings › Privacy & Security.
3. Optional: Settings › Integrations installs the `tinkerdock` command line tool and the Claude Code skill.

## Build from source

Open `Tinkerdock.xcodeproj` in Xcode 16 or later and run the `Tinkerdock` scheme. Xcode asks once to trust SwiftTerm's build plugin, which only writes SwiftTerm's version info into the build.

## Phases

1. **Shelf** – grid/list with screenshots, inspector, search, favorites, notes, open in app window or browser, Quick Look, drag & drop registration, `tinkerdock.json` manifest, embedded terminal (SwiftTerm), open in iTerm / Finder / Claude Code.
2. **Automation** – watched folders, dev server management, CLI + Claude Code skill for self-registration, git status, menu bar icon, share/export.
3. **Workbench** – herdr integration via CLI/socket API, agent status per project, notifications, start agents with a prompt.
4. **Files & voice** – two-pane file window (create folders, move/copy), dictation, voice command that starts an agent. Later: collections/tags, iCloud sync.

## Stack

SwiftUI, distributed outside the Mac App Store (Developer ID, notarized).
