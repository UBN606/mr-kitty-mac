# Mr. Kitty for Mac

A small, single desktop cat for macOS. This repository contains the native
AppKit source, Kitty's image frames, and a GitHub Actions build for a universal
Mac app. The build checks both Apple Silicon and Intel slices, the app bundle,
and an animation-state smoke test.

The Windows custom pet pack and shared CoPet controls are in
[windows/README.md](windows/README.md). Use the shared CoPet package for one
Kitty that reacts to both Codex and Claude Code. Run only one visible Kitty at
a time.

## Install a built release

1. Download `Mr-Kitty-for-Mac.app.zip` from the build artifact and unzip it.
2. Drag `Mr Kitty.app` into Applications, then open it. If macOS blocks the
   unsigned app, use Apple's **Open Anyway** steps in System Settings > Privacy
   & Security: <https://support.apple.com/en-us/102445>.
3. If CoPet is already showing Mr. Kitty, hide that copy so only this app's
   Kitty appears.

## Use Kitty

- **✎** opens the selected provider's small text chat.
- **🎙** opens voice input. With ChatGPT, tap **Voice** in its Chat Bar after
  the bar appears. With Claude Desktop, enable its Caps Lock voice dictation
  shortcut first in Settings > General > Desktop App; macOS 14 or later is
  required for Claude voice dictation.
- **✦** makes Kitty roll over and get a treat. Option-clicking Kitty does the
  same thing.
- **G/C** switches the chat buttons between ChatGPT and Claude. Both apps
  must be installed for their respective buttons to work. The buttons use
  each app's own small chat window; messages do not appear in Kitty's body.
- Drag Kitty to move him. Right-click Kitty to quit.

On the first chat-button click, macOS may ask you to allow Mr. Kitty under
System Settings > Privacy & Security > Accessibility. This permits the app to
send the keyboard shortcut that opens the selected chat app's quick entry.

ChatGPT Chat Bar instructions: <https://help.openai.com/en/articles/9295241-how-to-launch-the-chat-bar>

Claude Quick Entry instructions: <https://support.claude.com/en/articles/12626668-use-quick-entry-with-claude-desktop-on-mac>

## Build from source

On a Mac with Xcode Command Line Tools, run `bash build-mac.sh`. The app is
written to `dist/Mr Kitty.app`. The GitHub Actions workflow produces a ZIP
artifact without needing a Mac on the developer's desk.
