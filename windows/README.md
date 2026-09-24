# Mr. Kitty on Windows

This folder contains two ways to use the same Kitty artwork. Pick one visible
pet. The Mac app is in the repository root.

## Codex custom pet

`codex-custom-pet` contains `pet.json` and `spritesheet.webp`. Download this
repository as a ZIP, then copy the `codex-custom-pet` folder to
`%USERPROFILE%\.codex\pets\mr-kitty`. In Codex Desktop, open **Settings >
Pets**, refresh custom pets, and choose Mr. Kitty. Codex owns this pet's
movement, task activity, and its built-in text and voice controls.

## Shared CoPet pet

The optional `shared` folder holds the Windows controller that puts a small
glass pencil, microphone, and trick control next to one CoPet Kitty. It also
watches new Codex Desktop task activity and sends it to CoPet's local event
endpoint. The controller does not need your open Codex task to run its own
chat; its text and microphone buttons use a **separate Codex CLI chat**.
Claude chat is not included in this Windows controller.

1. Install and start CoPet 0.1.11, then import the `codex-custom-pet` folder
   as Mr. Kitty. Hide the Codex custom pet if you enabled that copy.
2. Install Python 3.10 or later and the Codex CLI if you want the controller's chat.
   Python must be on `PATH`, or set `MR_KITTY_PYTHON` to `python.exe` and
   `MR_KITTY_PYTHONW` to `pythonw.exe`. Sign in to the Codex CLI separately.
3. With CoPet showing Kitty, run `shared/Start-Mr-Kitty-Shared.cmd`. CoPet can
   also be launched by this script if `CoPet.exe` is on `PATH` or the
   `MR_KITTY_COPET_EXE` environment variable points to it.
4. Click the pencil for a small message card. Click the microphone to start
   Windows voice typing, review the words, then send. Click the star or
   Alt-click Kitty for a roll, rest, and treat.

The watcher reads only new local Codex Desktop session entries. Short activity
summaries may appear on the desktop where others can see them. Its local
CoPet event token stays in your Windows profile and is not included here.
The controller writes its temporary chat files under `shared/runtime`, which
Git ignores. If startup cannot find CoPet, read `shared/runtime/start-error.txt`.

The shared controller has been adapted to use paths on the current Windows
machine. Its portable copy has only had static checks; the original controller
was used locally, but this copy has not been relaunched on another PC.
