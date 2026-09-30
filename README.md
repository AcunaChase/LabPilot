# ScreenshotAsk

A small Windows PowerShell tool that lets you press a hotkey, capture a screenshot
of your screen, and get an answer from Claude — copied to your clipboard. Nothing
is ever auto-typed or auto-pasted into any application; you decide what to do with
the answer.

It is app-agnostic: it just screenshots whatever is on your screen and asks a
question about it. 

## What it does

1. You press **Ctrl+Alt+Shift+Z**.
2. It takes a screenshot of your whole screen.
3. It sends the screenshot to Claude (via [Claude Code](https://claude.ai/install.ps1))
   with a prompt asking it to answer whatever question is shown.
4. The answer is copied to your clipboard and shown in the tool's small window.
5. You paste it wherever you want, or don't.

## Requirements

- Windows with PowerShell.
- A Claude account with a paid plan or API access, since answering screenshots uses
  your account's usage.

Claude Code itself does **not** need to be installed beforehand — the script checks
for it and installs it automatically the first time it runs. Logging in is the one
step you always do yourself (see below).

## Running it

```powershell
powershell -ExecutionPolicy Bypass -File .\ScreenshotAsk.ps1
```

On first run:
1. If Claude Code isn't installed yet, the script installs it automatically
   (via `https://claude.ai/install.ps1`).
2. If you aren't logged in yet, it asks you to paste a Claude token.
   Get one by running `claude setup-token` in a terminal — this opens a browser
   sign-in and prints a long-lived token. Keep it private; anyone with it can use
   your Claude account. The script never stores or transmits it anywhere besides
   your own Claude Code login.

Then, every time you run it:
- Click **Start**.
- Press **Ctrl+Alt+Shift+Z** whenever you want the current screen read and answered.
- The answer appears in the tool window and on your clipboard (Ctrl+V to paste it
  anywhere).
- **Stop** pauses listening for the hotkey. **Exit** closes the tool completely and
  clears its temp files.

## Customizing

- **Hotkey:** edit the `$HKKeys` array near the top of `ScreenshotAsk.ps1`. It's a
  list of Windows virtual-key codes that must all be held together. Common ones:
  Ctrl `0x11`, Alt `0x12`, Shift `0x10`, letters A–Z `0x41`–`0x5A`.
- **Prompt:** edit the `$Prompt` variable to change what Claude is asked to do with
  the screenshot (e.g. summarize instead of answer, or focus on code).

## Responsible use

This tool sends a full screenshot of your screen to Claude every time you press the
hotkey — close anything private first. It is meant for legitimate uses: getting a
quick explanation of something on your screen, checking your own work, accessibility
help, and similar. Do not use it to answer graded exams, quizzes, or other assessments
where outside assistance isn't allowed — that's an academic integrity issue between
you and your institution, not something this tool changes.

## License

MIT — see [LICENSE](LICENSE).
