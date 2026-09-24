MR. KITTY MAC TEST BUILD — NOT FOR EMAIL YET

This is source for a single native Mac desktop pet. It uses Kitty's image
frames, a small glass button dock, Option-click or star-button trick/treat,
and text/microphone buttons. G on the dock means ChatGPT; C means Claude.
Tap G/C to switch. The text and mic buttons invoke that provider's own small
chat window. ChatGPT's Voice button still needs a second tap in its Chat Bar.
Claude's voice shortcut needs to be enabled in Claude Desktop Settings.

On a Mac with Apple Command Line Tools, open Terminal in this folder and run:

  bash Build-Mr-Kitty.command

The script compiles a local unsigned app into ~/Applications/Mr Kitty.app.
An Accessibility permission may be needed for its simulated keyboard
shortcuts. Do not send this test build to Mom until it has been
compiled, opened, and checked on a Mac. It has not been verified on macOS.

The app is standalone. Quit CoPet if it is showing a second copy of Kitty.
Right-click Kitty to quit the native app.
