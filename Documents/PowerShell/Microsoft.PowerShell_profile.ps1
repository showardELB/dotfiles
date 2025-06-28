# Helper: Time a block
function Time-Section ($label, [ScriptBlock]$code) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $code
    $sw.Stop()
    Write-Host "$label loaded in $($sw.ElapsedMilliseconds)ms"
}

# Set env vars early
$env:YAZI_FILE_ONE = "C:\Program Files\Git\usr\bin\file.exe"
[System.Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $env:YAZI_FILE_ONE, "User")
$env:FZF_DEFAULT_OPTS = "--layout=reverse --height=50% --border --info=inline"

# Aliases
Set-Alias desktop "Desktop.ps1"
function config { git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $args }

# Lazy-load certain modules
$ExecutionContext.InvokeCommand.PreCommandLookupAction = {
    param($commandName)
    switch ($commandName) {
        'git'     { Import-Module posh-git -ErrorAction SilentlyContinue }
        'fzf'     { Import-Module PSFzf -ErrorAction SilentlyContinue }
        'yazi'    { Import-Module PSFzf -ErrorAction SilentlyContinue }  # fallback
    }
}

# Add Chocolatey tab completion if present
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module $ChocolateyProfile
}

# Define 'y' command for Yazi navigation
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [string]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
    }
    Remove-Item -Path $tmp
}

# Only do the rest if session is interactive
if ($Host.Name -eq 'ConsoleHost') {
    Time-Section "Interactive Profile Setup" {

        # Load interactive modules
        Time-Section "PSReadLine"    { Import-Module PSReadLine -ErrorAction SilentlyContinue }
        # Time-Section "TerminalIcons" { Import-Module Terminal-Icons -ErrorAction SilentlyContinue }
        Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -Action {
            Unregister-Event -SourceIdentifier PowerShell.OnIdle
            Import-Module Terminal-Icons -ErrorAction SilentlyContinue
        } | Out-Null

        # Theme
        Time-Section "oh-my-posh" {
            oh-my-posh init pwsh --config "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\iterm2.omp.json" | Invoke-Expression
        }

        # Zoxide
        Invoke-Expression (& { (zoxide init powershell | Out-String) })

        # Fzf keybindings
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+p' -PSReadlineChordReverseHistory 'Ctrl+r'
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

        # Set Vi mode and history search
        Set-PSReadLineOption -EditMode Vi
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        Set-PSReadLineKeyHandler -Key 'Ctrl+k' -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key 'Ctrl+j' -Function HistorySearchForward

        # Set prediction and list view
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView

        # Setup your custom PSReadLine key handlers (grouped for brevity)
        # 🧠 You can extract these into a separate .ps1 and dot-source it here if desired
        # . "$HOME\Documents\PowerShell\PSReadLine-KeyHandlers.ps1"  # Optional split

        # Argument completers
        Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
            $Local:word = $wordToComplete.Replace('"', '""')
            $Local:ast = $commandAst.ToString().Replace('"', '""')
            winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        }

        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
            param($commandName, $wordToComplete, $cursorPosition)
            dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        }
    }
}
