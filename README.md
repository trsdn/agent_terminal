# AgentHive

A native macOS terminal built for running multiple AI agent sessions in parallel.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Why

Existing terminals aren't designed for AI agent workflows. When running Claude Code, Copilot CLI, or other agents in parallel, you need instant session switching, visual status indicators, and flexible grid layouts — without electron overhead.

## Features

- **SwiftTerm terminal emulation** — full PTY support, native performance
- **Vertical sidebar** — session tabs with live status indicators (running/waiting/idle)
- **Session grouping** — drag sessions together for side-by-side or 2x2 grid layouts
- **Input detection** — highlights sessions waiting for user input (passwords, prompts)
- **Instant switching** — all terminals stay alive in memory, no teardown on switch
- **Keyboard shortcuts** — `Cmd+T` new tab, `Cmd+W` close, `Cmd+1-9` switch, `Cmd+R` rename

## Architecture

```
AgentHive.app
├── SwiftUI           — Sidebar, toolbar, preferences
├── AppKit            — TerminalHostView (single container for all terminals)
├── SwiftTerm (SPM)   — Terminal emulation engine
└── PTY Manager       — Process spawning + input detection
```

Session switching uses a single `NSView` container that shows/hides terminal subviews via `isHidden` — no SwiftUI view lifecycle overhead.

## Build

Requires Xcode 15+ and macOS 14 (Sonoma).

```bash
# Open in Xcode
open AgentHive.xcodeproj

# Or build from CLI
xcodebuild -scheme AgentHive -configuration Debug build
```

## Usage

| Action | Shortcut |
|---|---|
| New session | `Cmd+T` |
| Close session | `Cmd+W` |
| Switch to session N | `Cmd+1` — `Cmd+9` |
| Rename session | `Cmd+R` or right-click → Rename |
| Group sessions | Drag one session onto another in the sidebar |
| Reorder in group | Right-click → Move Up/Down |
| Debug overlay | `Cmd+Shift+D` |

## License

MIT
