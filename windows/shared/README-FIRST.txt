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

If the starter cannot find CoPet, read controller\runtime\start-error.txt.
If the Claude chat says the CLI is missing, install Claude Code CLI from
https://code.claude.com/docs/en/setup or set MR_KITTY_CLAUDE_CLI to its path.
Claude activity through CoPet can still work even when the CLI chat is absent.

This pack has passed offline code and control-loading checks. It has not
sent a live Claude message on this Windows PC because Claude CLI is absent.
