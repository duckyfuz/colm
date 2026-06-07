# colm

A lightweight macOS window switcher. Hold ⌥ Option and press ⇥ Tab to show a vertical list of open windows — one row per window: app icon, app name, window title. Release Option to switch.

## Why

- macOS Cmd-Tab switches **apps**, not windows.
- [AltTab](https://alt-tab-macos.netlify.app) switches windows, but needs Screen Recording permission for thumbnails.

colm shows text-only rows, so it only needs **Accessibility** permission.

## Status

Early development. macOS 13+, Apple Silicon and Intel.

## Install

> Homebrew formula coming in a later phase.

For now, build from source:

```
swift build -c release
.build/release/colm setup   # grant Accessibility, then…
.build/release/colm
```

## License

[GPL-3.0](LICENSE).
