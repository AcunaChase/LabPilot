# ScreenshotAsk

A small Windows PowerShell tool that lets you press a hotkey, capture a screenshot
of your screen, and get an answer from Claude — copied to your clipboard. Nothing
is ever auto-typed or auto-pasted into any application; you decide what to do with
the answer.

It is app-agnostic: it just screenshots whatever is on your screen and asks a
question about it. It is not tied to RStudio or any other specific program.

## What it does

1. You press **Ctrl+Alt+Shift+Z**.
2. It takes a screenshot of your whole screen.
3. It sends the screenshot to Claude (via [Claude Code](https://claude.ai/install.ps1))
   with a prompt asking it to answer whatever question is shown.
4. The answer is copied to your clipboard and shown in the tool's small window.
5. You paste it wherever you want, or don't.

## Requirements

- Windows with PowerShell.
- [Claude Code](https://claude.ai/install.ps1) installed (the script offers to check, but
  does not auto-install it — see below).
- A Claude account with a paid plan or API access, since answering screenshots uses
  your account's usage.

## Setup

Install Claude Code if you don't already have it:

```powershell
irm https://claude.ai/install.ps1 | iex
```

Log in once:

```powershell
$env:Path += ";$env:USERPROFILE\.local\bin"
claude setup-token
```

This opens a browser sign-in and prints a long-lived token. Keep it private — anyone
with it can use your Claude account.

## Running it

```powershell
powershell -ExecutionPolicy Bypass -File .\ScreenshotAsk.ps1
```

- Click **Start**.
- Press **Ctrl+Alt+Shift+Z** whenever you want the current screen read and answered.
- The answer appears in the tool window and on your clipboard (Ctrl+V to paste it
  anywhere).
- **Stop** pauses listening for the hotkey. **Exit** closes the tool completely and
  clears its temp files.

If Claude Code isn't logged in yet on this machine, the script asks you to paste a
token (from `claude setup-token`) the first time you run it.

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
