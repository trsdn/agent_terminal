# Changelog

All notable changes to HiveTerm are documented here.

## [0.2.0] - 2026-02-22

### Added
- **Theme system** with 5 built-in themes: HiveTerm Dark, Dracula, Nord, Solarized Dark, Catppuccin Mocha
- Live theme switching — all terminals update instantly, no restart needed
- iTerm2 `.itermcolors` import (Menu → View → Theme → Import)
- Theme persistence across app restarts (UserDefaults)
- Layout and Theme submenus in the View menu
- Terminal pane padding (6px)

### Changed
- App icon updated: `>` chevron replaced with sideways **A** (with vertical crossbar)
- Removed toolbar in favor of clean menu-bar commands
- Layout picker now correctly affects ungrouped sessions
- Layout auto-caps to actual session count (no empty placeholders)

### Fixed
- First shell now shows username and prompt correctly on startup
- Suppressed zsh `%` (PROMPT_EOL_MARK) at top of new terminals
- Terminals no longer briefly shift when grouping (deferred process start)
- Third ungrouped terminal no longer shown in split with empty placeholder

## [0.1.0] - 2026-02-22

### Added
- Initial release
- Multi-session terminal with sidebar
- Grid layouts: single, side-by-side, 2x2
- Session grouping via drag & drop
- Input detection (password prompts, confirmations)
- Keyboard shortcuts (Cmd+T, Cmd+W, Cmd+1-9, Cmd+R)
- Debug overlay (Cmd+Shift+D)
