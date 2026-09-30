# ScreenshotAsk - Background variant
# No main window. Runs immediately (no Start button) with a small system tray icon
# as the only visible sign it's active - see README for why there's a tray icon at all.
#
# Hotkeys:
#   Ctrl+Alt+Shift+Z  -> screenshot the screen, ask Claude, copy the answer to clipboard
#   Ctrl+Alt+Shift+C  -> close the app completely
#
# Same as the main ScreenshotAsk.ps1 otherwise: installs Claude Code if missing, asks
# for a login token if needed, never auto-pastes or auto-types anything.

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);' -Name K -Namespace W

$AskKeys = @(0x11, 0x12, 0x10, 0x5A)   # Ctrl+Alt+Shift+Z
$ExitKeys = @(0x11, 0x12, 0x10, 0x43)  # Ctrl+Alt+Shift+C

$Prompt = "Read the attached screenshot. Answer whatever question is shown as clearly and concisely as possible. If it's multiple choice, give the answer and a one-line reason. Do not add extra commentary."

$env:Path += ";$env:USERPROFILE\.local\bin"

$claudeExe = "$env:USERPROFILE\.local\bin\claude.exe"
if (-not (Get-Command claude -ErrorAction SilentlyContinue) -and -not (Test-Path $claudeExe)) {
    Write-Host "Claude Code not found - installing it now..."
    irm https://claude.ai/install.ps1 | iex
    $env:Path += ";$env:USERPROFILE\.local\bin"
}

$tok = $env:CLAUDE_CODE_OAUTH_TOKEN
$needTok = $true
if (-not $tok) {
    $st = (claude auth status 2>&1 | Out-String)
    if ($st -match '"loggedIn":\s*true') { $needTok = $false }
}
if ($needTok) {
    $good = $false
    for ($n = 0; $n -lt 3; $n++) {
        if ($tok) { $tok = [regex]::Replace($tok, '\s+', '') }
        if ($tok -match '^sk-ant-[A-Za-z0-9_-]+$') { $good = $true; break }
        $sec = Read-Host "Paste your Claude token (from 'claude setup-token')" -AsSecureString
        $tok = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
    if (-not $good) {
        Write-Host "Token still invalid. Run 'claude setup-token' for a fresh one and try again."
        return
    }
    $env:CLAUDE_CODE_OAUTH_TOKEN = $tok
}

# --- Invisible host form: just pumps Windows messages for the timer, never shown ---
$host_ = New-Object Windows.Forms.Form
$host_.ShowInTaskbar = $false
$host_.WindowState = 'Minimized'
$host_.FormBorderStyle = 'FixedToolWindow'
$host_.Opacity = 0
$host_.Add_Load({ $host_.Hide() })

# --- Tray icon: the only visible sign this is running ---
$tray = New-Object Windows.Forms.NotifyIcon
$tray.Icon = [Drawing.SystemIcons]::Application
$tray.Visible = $true
$tray.Text = "ScreenshotAsk (Z=ask, C=quit)"

$menu = New-Object Windows.Forms.ContextMenuStrip
$statusItem = $menu.Items.Add("Ready")
$statusItem.Enabled = $false
$menu.Items.Add("-") | Out-Null
$exitItem = $menu.Items.Add("Exit")
$tray.ContextMenuStrip = $menu

$global:state = 'idle'
$global:armedAsk = $false
$global:armedExit = $false
$global:p = $null

function Down($vk) { ([W.K]::GetAsyncKeyState($vk) -band 0x8000) -ne 0 }
function Combo($keys) { foreach ($k in $keys) { if (-not (Down $k)) { return $false } }; return $true }
function AnyOf($keys) { foreach ($k in $keys) { if (Down $k) { return $true } }; return $false }
function KillClaude { try { if ($global:p -and -not $global:p.HasExited) { $global:p.Kill() } } catch {} }

function Shutdown {
    KillClaude
    $tray.Visible = $false
    $tray.Dispose()
    foreach ($n in 'sab_shot.png', 'sab_ans.txt', 'sab_err.txt') {
        try { [IO.File]::Delete((Join-Path $env:TEMP $n)) } catch {}
    }
    [Environment]::Exit(0)
}
$exitItem.Add_Click({ Shutdown })

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 60
$timer.Add_Tick({
    # Exit hotkey always checked first
    if (-not (AnyOf $ExitKeys)) { $global:armedExit = $true }
    if ($global:armedExit -and (Combo $ExitKeys)) { Shutdown }

    switch ($global:state) {
        'idle' {
            if (-not (AnyOf $AskKeys)) { $global:armedAsk = $true }
            if ($global:armedAsk -and (Combo $AskKeys)) {
                $global:armedAsk = $false
                $statusItem.Text = "Reading screen..."
                $b = [Windows.Forms.SystemInformation]::VirtualScreen
                $bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
                [Drawing.Graphics]::FromImage($bmp).CopyFromScreen($b.Location, [Drawing.Point]::Empty, $b.Size)
                $png = "$env:TEMP\sab_shot.png"
                $bmp.Save($png)
                $bmp.Dispose()
                $out = "$env:TEMP\sab_ans.txt"; $err = "$env:TEMP\sab_err.txt"
                foreach ($x in $out, $err) { try { [IO.File]::Delete($x) } catch {} }
                $fullPrompt = "Read the image $png. $Prompt"
                $global:p = Start-Process claude -ArgumentList @('-p', "`"$fullPrompt`"", '--allowedTools', 'Read') `
                    -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru
                $global:state = 'ask'
            }
        }
        'ask' {
            if ($global:p.HasExited) {
                $out = "$env:TEMP\sab_ans.txt"; $err = "$env:TEMP\sab_err.txt"
                $ans = ((Get-Content $out -Raw -ea 0) -replace '(?m)^```.*$', '').Trim()
                if ($ans) {
                    Set-Clipboard $ans
                    $statusItem.Text = "Ready (last answer copied)"
                    $tray.ShowBalloonTip(2000, "ScreenshotAsk", "Answer copied to clipboard.", [Windows.Forms.ToolTipIcon]::Info)
                } else {
                    $statusItem.Text = "No answer - see $err"
                    $tray.ShowBalloonTip(3000, "ScreenshotAsk", "No answer came back. Check $err", [Windows.Forms.ToolTipIcon]::Warning)
                }
                $global:state = 'idle'
            }
        }
    }
})
$timer.Start()

$tray.ShowBalloonTip(2500, "ScreenshotAsk", "Running. Ctrl+Alt+Shift+Z to ask, Ctrl+Alt+Shift+C to quit.", [Windows.Forms.ToolTipIcon]::Info)

[Windows.Forms.Application]::Run($host_)
