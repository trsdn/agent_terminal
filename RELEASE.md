# Release Notes

## v0.2.0 — Theme System

HiveTerm now supports themes. Switch between 5 built-in color schemes or import your own `.itermcolors` files.

### Built-in Themes
- **HiveTerm Dark** (default) — the original dark theme
- **Dracula** — popular dark theme with purple accents
- **Nord** — arctic, north-bluish color palette
- **Solarized Dark** — Ethan Schoonover's precision color scheme
- **Catppuccin Mocha** — soothing pastel theme

### How to switch
Menu → View → Theme → pick a theme. Changes apply instantly to all open terminals.

### iTerm2 import
Menu → View → Theme → Import .itermcolors... — select any `.itermcolors` file and it appears in the theme list.

### Other improvements
- App icon redesigned with sideways **A** motif
- Cleaner UI: toolbar removed, all controls via menu bar
- Layout picker works correctly for ungrouped sessions
- Terminal startup fixes (prompt visibility, no more `%` marker)

---

## v0.1.0 — Initial Release

Native macOS terminal for AI agent workflows. Run multiple CLI agents side-by-side with input detection and instant switching.

### Highlights
- Multi-session grid layouts (single, side-by-side, 2x2)
- Session grouping via drag & drop
- Automatic input detection for waiting prompts
- Pure Swift + AppKit — no Electron
