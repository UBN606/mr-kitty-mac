MR. KITTY SHARED WINDOWS PET - CODEX + CLAUDE CODE

This pack gives you ONE visible Kitty in CoPet. The Codex-only custom pet
in Codex Desktop must be hidden while this shared Kitty is running.

1. Install CoPet 0.1.11 from https://github.com/ChanceYu/CoPet/releases
2. Open CoPet and import the included mr-kitty folder as a custom pet.
3. In CoPet Settings > Agent integrations, enable Claude Code. Enable Codex
   too if you use Codex CLI. CoPet manages those activity hooks.
4. Install Python 3.10+ for the small attached controls. To use the controls
   for chat, install and sign in to Codex CLI and Claude Code CLI. The chats
   are separate from the tasks open in their desktop apps.
5. With Kitty visible in CoPet, double-click
   controller\Start-Mr-Kitty-Shared.cmd. No portal is needed after setup.
6. In Kitty's little dock, click Codex/Claude to switch who answers. Click
   the pencil to type. Click the microphone for Windows voice typing (Win+H),
   review the words, and send. Alt-click Kitty for a trick and treat.
7. If Kitty looks tiny, open CoPet Settings and move the pet Size slider to
   about 20-25. Right-click Kitty and choose Hide Messages if status bubbles
   crowd the cat. This keeps the attached text and voice dock available.
8. The dock sits just outside CoPet's draggable pet window. If Kitty follows
   the pointer after you release the mouse, switch to another app and back to
   reset CoPet's drag state. If that does not help, exit CoPet normally from
   its tray icon and reopen it.
9. When Kitty is next to a screen edge or taskbar, the dock becomes a slim
   vertical strip. Cx means Codex and Cl means Claude. The pencil opens or
   closes chat; the X or Esc closes chat too. The chat panel stays clear of
   Kitty's controls so you can choose another button.

If the starter cannot find CoPet, read controller\runtime\start-error.txt.
If the Claude chat says the CLI is missing, point MR_KITTY_CLAUDE_CLI to your
existing Claude Code executable, or use the installation instructions at
https://code.claude.com/docs/en/setup.
Claude activity through CoPet can still work even when the CLI chat is absent.

This pack has passed offline code and control-loading checks. The package
checks did not send a live Claude message.
