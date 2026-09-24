# Mr. Kitty on Windows

This folder contains two ways to use the same Kitty artwork. For **one Kitty
that reacts to both Codex and Claude Code**, use the shared CoPet setup below.
The Mac app is in the repository root.

## Codex custom pet

`codex-custom-pet` contains `pet.json` and `spritesheet.webp`. Download this
repository as a ZIP, then copy the `codex-custom-pet` folder to
`%USERPROFILE%\.codex\pets\mr-kitty`. In Codex Desktop, open **Settings >
Pets**, refresh custom pets, and choose Mr. Kitty. Codex owns this pet's
movement, task activity, and its built-in text and voice controls.

## Shared CoPet pet for Codex and Claude Code

The `shared` folder holds the Windows controller that puts a small glass
pencil, microphone, and separate colored Codex/Claude buttons next to one CoPet Kitty. CoPet's
Claude Code integration handles Claude Code activity. Kitty's watcher sends
new Codex Desktop task activity to the same CoPet cat. CoPet can also handle
Codex CLI activity through its own integration.

The controller's text and microphone buttons use **separate Kitty chats** in
Codex CLI and Claude Code CLI. They do not add messages to conversations open
in Codex or Claude Desktop. The Claude chat button requires Claude Code CLI;
Claude activity reactions can still work through CoPet's hooks without it.

1. Install and start [CoPet 0.1.11](https://github.com/ChanceYu/CoPet/releases),
   then import the `codex-custom-pet` folder as Mr. Kitty. In CoPet Settings
   > Agent integrations, enable **Claude Code**. Enable **Codex** there too
   if you use Codex CLI. Hide the native Codex pet if it is showing, so this
   CoPet Kitty is the only visible copy.
2. Install Python 3.10 or later for the attached controls. Python must be on
   `PATH`, or set `MR_KITTY_PYTHON` to `python.exe` and `MR_KITTY_PYTHONW` to
   `pythonw.exe`. For in-pet chat, install and sign in to both the Codex CLI
   and [Claude Code CLI](https://code.claude.com/docs/en/setup) as needed.
   If Claude CLI is outside `PATH`, set `MR_KITTY_CLAUDE_CLI` to its full path.
3. With CoPet showing Kitty, run `shared/Start-Mr-Kitty-Shared.cmd`. CoPet can
   also be launched by this script if `CoPet.exe` is on `PATH` or the
   `MR_KITTY_COPET_EXE` environment variable points to it.
4. Click the blue **Codex** or orange **Claude** button to choose who answers.
   Click the pencil to type, or the microphone to speak into Kitty's separate
   chat. Alt-click Kitty for a roll, rest, and treat.
5. For Kitty's gentle male voice, run `shared/Setup-Mr-Kitty-Voice.cmd` once. It installs
   the free local Kokoro model in an isolated folder. Kitty stays silent until
   you press **Hear** on his chat card. To hear a recent Codex Desktop or
   Claude Code reply, click **Desktop**, choose the source, then press Hear.
   **Stop** or closing the card silences playback.
6. When a new Codex Desktop or Claude Code reply arrives, click the small
   colored "replied - read" notice next to Kitty. The full reply opens in a
   larger scrolling card. **Open app** brings the running app forward to reply
   in that task. Kitty's **Send** continues a separate CLI chat. CoPet's own
   small status bubble can be hidden from Kitty's right-click menu.

The watcher reads only new local Codex Desktop session entries. Short activity
summaries may appear on the desktop where others can see them. Its local
CoPet event token stays in your Windows profile and is not included here.
The controller writes its temporary chat files under `shared/runtime`, which
Git ignores. If startup cannot find CoPet, read `shared/runtime/start-error.txt`.

The Claude Code integration uses CoPet's hooks, so it responds to Claude Code
activity. Claude Desktop's ordinary Chat tab does not expose these agent hooks;
the Mac-style Quick Entry button is not available on Windows. The in-pet
Claude chat above uses its own Claude Code CLI session.

The voice model is downloaded during setup rather than stored in this repo.
The package and UI have offline checks; mic accuracy, desktop playback and a
live Claude chat still require a normal desktop check after installation.
