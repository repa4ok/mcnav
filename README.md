# MCNav

Keyboard navigation for macOS Mission Control.

Mission Control lets you see all open windows at a glance, but selecting one requires reaching for the mouse. MCNav fixes that. When you activate Mission Control, MCNav automatically highlights your current window and lets you navigate around.

## Usage

1. Press **Ctrl+Up** to open Mission Control
2. Use **arrow keys** to navigate between windows
3. Press **Enter** to select a window
4. Press **Escape** or click anywhere to cancel

## Install

```bash
make install
```

This builds the app and copies it to `/Applications`.

## Permissions

Grant Accessibility permissions:
**System Preferences → Privacy & Security → Accessibility**

## Build

```bash
make build  # Build executable
make app    # Build .app bundle
make clean  # Clean build artifacts
```

## Requirements

- macOS 13+
- Xcode Command Line Tools

---

Built with [Claude Code](https://github.com/anthropics/claude-code)
