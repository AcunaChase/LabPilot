# ScreenshotAsk
# Press a hotkey, take a screenshot, ask Claude about it, get the answer on your clipboard.
# Nothing is auto-pasted or auto-typed anywhere - you decide what to do with the answer.
#
# Requires: Claude Code (https://claude.ai/install.ps1) and a Claude account/plan.

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);' -Name K -Namespace W

# --- Hotkey: Ctrl+Alt+Shift+Z (unlikely to clash with app shortcuts) ---
$HKKeys = @(0x11, 0x12, 0x10, 0x5A)
$HKName = 'Ctrl+Alt+Shift+Z'

# --- The question sent to Claude alongside the screenshot. Edit this for your use case. ---
$Prompt = "Read the attached screenshot. Answer whatever question is shown as clearly and concisely as possible. If it's multiple choice, give the answer and a one-line reason. Do not add extra commentary."

$env:Path += ";$env:USERPROFILE\.local\bin"

# --- Make sure Claude Code is logged in, or ask for a token ---
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

$global:run = $false
$global:p = $null
$global:state = 'idle'
$global:armed = $false
$global:sw = New-Object Diagnostics.Stopwatch

$f = New-Object Windows.Forms.Form
$f.Text = 'ScreenshotAsk'
$f.TopMost = $true
$f.FormBorderStyle = 'FixedSingle'
$f.MaximizeBox = $false
$f.MinimizeBox = $true
$f.ShowInTaskbar = $true
$f.ClientSize = '260,160'
$f.StartPosition = 'Manual'
$f.Location = '10,10'

$go = New-Object Windows.Forms.Button; $go.Text = 'Start'; $go.Location = '8,8'; $go.Size = '75,26'
$stop = New-Object Windows.Forms.Button; $stop.Text = 'Stop'; $stop.Location = '90,8'; $stop.Size = '75,26'
$exit = New-Object Windows.Forms.Button; $exit.Text = 'Exit'; $exit.Location = '172,8'; $exit.Size = '80,26'
$exit.BackColor = 'IndianRed'; $exit.ForeColor = 'White'
$lbl = New-Object Windows.Forms.Label; $lbl.Text = 'Stopped'; $lbl.Location = '8,42'; $lbl.Size = '244,30'
$box = New-Object Windows.Forms.TextBox
$box.Multiline = $true; $box.ReadOnly = $true; $box.ScrollBars = 'Both'
$box.Location = '8,76'; $box.Size = '244,76'
$f.Controls.AddRange(@($go, $stop, $exit, $lbl, $box))

function Down($vk) { ([W.K]::GetAsyncKeyState($vk) -band 0x8000) -ne 0 }
function Hotkey { foreach ($k in $HKKeys) { if (-not (Down $k)) { return $false } }; return $true }
function AnyHeld { foreach ($k in $HKKeys) { if (Down $k) { return $true } }; return $false }
function KillClaude { try { if ($global:p -and -not $global:p.HasExited) { $global:p.Kill() } } catch {} }

function Shutdown {
    $global:run = $false
    KillClaude
    foreach ($n in 'sa_shot.png', 'sa_ans.txt', 'sa_err.txt') {
        try { [IO.File]::Delete((Join-Path $env:TEMP $n)) } catch {}
    }
    [Environment]::Exit(0)
}

$go.Add_Click({
    $global:run = $true
    $global:state = 'idle'
    $global:armed = $false
    $lbl.Text = "Ready: press $HKName over what you want asked about"
})
$stop.Add_Click({
    $global:run = $false
    KillClaude
    $global:state = 'idle'
    $lbl.Text = 'Stopped'
})
$exit.Add_Click({ Shutdown })
$f.Add_FormClosing({ Shutdown })

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 60
$timer.Add_Tick({
    if (-not $global:run) { return }
    switch ($global:state) {
        'idle' {
            if (-not (AnyHeld)) { $global:armed = $true }
            if ($global:armed -and (Hotkey)) {
                $global:armed = $false
                $b = [Windows.Forms.SystemInformation]::VirtualScreen
                $bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
                [Drawing.Graphics]::FromImage($bmp).CopyFromScreen($b.Location, [Drawing.Point]::Empty, $b.Size)
                $png = "$env:TEMP\sa_shot.png"
                $bmp.Save($png)
                $bmp.Dispose()
                $out = "$env:TEMP\sa_ans.txt"; $err = "$env:TEMP\sa_err.txt"
                foreach ($x in $out, $err) { try { [IO.File]::Delete($x) } catch {} }
                $fullPrompt = "Read the image $png. $Prompt"
                $global:p = Start-Process claude -ArgumentList @('-p', "`"$fullPrompt`"", '--allowedTools', 'Read') `
                    -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru
                $global:state = 'ask'
                $lbl.Text = 'Screenshot taken, asking Claude...'
            }
        }
        'ask' {
            if ($global:p.HasExited) {
                $out = "$env:TEMP\sa_ans.txt"; $err = "$env:TEMP\sa_err.txt"
                $ans = ((Get-Content $out -Raw -ea 0) -replace '(?m)^```.*$', '').Trim()
                if ($ans) {
                    $box.Text = ($ans -replace "`r?`n", "`r`n")
                    Set-Clipboard $ans
                    $lbl.Text = "Answer copied to clipboard. Ready for next $HKName."
                } else {
                    $e = (Get-Content $out -Raw -ea 0) + (Get-Content $err -Raw -ea 0)
                    $box.Text = "No answer. $e"
                    $lbl.Text = 'No answer. Ready.'
                }
                $global:state = 'idle'
            }
        }
    }
})
$timer.Start()
[Windows.Forms.Application]::Run($f)
