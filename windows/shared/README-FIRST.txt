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
   For Kitty's gentle male local voice, run controller\Setup-Mr-Kitty-Voice.cmd
   once. It installs an isolated voice runtime and downloads about 142 MB of
   free model files. It does not start Kitty speaking.
6. In Kitty's little dock, choose the blue Codex or orange Claude button for
   a separate Kitty chat. Click the pencil to type. Click the microphone and
   speak into Kitty. He transcribes and sends a completed phrase. Tap the mic
   again to stop listening. Kitty stays silent unless you press Hear in the
   chat card; press it again to stop the visible reply.
   Alt-click Kitty for a trick and treat.
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
10. Kitty never reads replies automatically. To hear a reply from an open
    Codex Desktop task or Claude Code session, click the pencil, click
    Desktop, choose the available source, then press Hear. Hear also reads
    Kitty's own visible chat reply. Press Stop or close the card to silence it.
    Ordinary Claude browser and Claude Desktop Chat replies are not captured.
11. A small blue or orange "replied - read" notice appears beside Kitty when
    Codex Desktop or Claude Code finishes a new reply. Click it to read the
    complete reply in a larger scrolling card. Open app brings the running
    Codex or Claude app forward so you can respond in the original task.
    Kitty's Send box starts or continues a separate Kitty CLI chat; it does
    not respond in the original desktop task. The notice disappears after
    25 seconds; Desktop in the card still offers the latest reply from each.
    CoPet's own tiny status bubble is only an activity summary. You can hide
    it with right-click Kitty > Hide Messages if it crowds the new notice.

If the starter cannot find CoPet, read controller\runtime\start-error.txt.
If the Claude chat says the CLI is missing, point MR_KITTY_CLAUDE_CLI to your
existing Claude Code executable, or use the installation instructions at
https://code.claude.com/docs/en/setup.
Claude activity through CoPet can still work even when the CLI chat is absent.

Kitty's microphone uses your installed Windows speech recognizer, which may
mishear words; you can still type. Hear uses the local Kokoro voice after the
one-time setup. It makes no paid speech-service calls. The packaged controls
have passed offline checks; live microphone and Claude chat behavior still
need to be checked on the desktop.
