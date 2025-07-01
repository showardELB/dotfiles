#------------------------------------------------------------------------------
# PowerShell Profile
#------------------------------------------------------------------------------

# --- GLOBAL CONFIGURATION & ALIASES ---

# Set environment variables.
$env:_PSFZF_FZF_DEFAULT_OPTS = '--preview-window=right,60%,border-left'
$env:YAZI_FILE_ONE = "C:\Program Files\Git\usr\bin\file.exe"
# $env:FZF_DEFAULT_OPTS = "--layout=reverse --height=50% --border --info=inline"

# Set aliases.
Set-Alias -Name desktop -Value "Desktop.ps1" -Option AllScope

# --- GLOBAL HELPER FUNCTIONS ---

# Function for managing dotfiles with a bare git repository.
function config {
    git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" $args
}

# Function for changing directory using the Yazi file manager.
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        # Execute yazi and capture the destination directory path.
        yazi $args --cwd-file="$tmp"
        $cwd = Get-Content -Path $tmp -Encoding UTF8
        # If a valid path was written, change to that directory.
        if (-not [string]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
            Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
        }
    }
    finally {
        # Ensure the temporary file is always removed.
        if (Test-Path -Path $tmp) {
            Remove-Item -Path $tmp -ErrorAction SilentlyContinue
        }
    }
}

# --- LAZY-LOADING & MODULES ---

# Lazy-load posh-git when the 'git' command is first used.
$ExecutionContext.InvokeCommand.PreCommandLookupAction = {
    param($commandName)
    # Check for 'git' or 'git.exe' to ensure it works reliably.
    if ($commandName -in @('git', 'git.exe')) {
        Import-Module posh-git -ErrorAction SilentlyContinue
    }
}

# Add Chocolatey tab completion if the profile script exists.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module $ChocolateyProfile -ErrorAction SilentlyContinue
}

# --- INTERACTIVE SESSION CONFIGURATION ---
# The following settings only apply when running PowerShell interactively.
if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Visual Studio Code Host') {

    # Import PSReadLine, which is essential for the interactive experience.
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    Import-Module PSFzf -ErrorAction SilentlyContinue

    # --- PSReadLine Options ---
    # Set-PSReadLineOption -EditMode Vi
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView

    # --- Standard Key Handlers ---
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key 'Ctrl+k' -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key 'Ctrl+j' -Function HistorySearchForward

# Override the base 'fzf' command to use a bat preview
    function fzf {
        fzf.exe --preview 'bat --color=always {}' --preview-window '~3' --bind "ctrl-y:execute(powershell.exe -c 'Set-Clipboard -Path ''{f}''')+abort"
    }
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    Set-PsFzfOption -TabExpansion

    Remove-Alias -Name ls 
    function ls {
        # Get all file and folder names, passing along any arguments (e.g., a path)
        $fileNames = (Get-ChildItem @args).Name

        # If there are no files, do nothing
        if ($null -eq $fileNames) { return }

        # Find the length of the longest name, adding 3 for spacing
        $longestName = ($fileNames | Measure-Object -Property Length -Maximum).Maximum + 3

        # Get the width of the terminal window
        $windowWidth = $Host.UI.RawUI.WindowSize.Width

        # Calculate how many columns can fit, defaulting to 1 if window is too small
        $columns = [System.Math]::Max(1, [System.Math]::Floor($windowWidth / $longestName))

        # Display the list with the calculated number of columns, passing arguments again
        Get-ChildItem @args | Format-Wide -Column $columns
    }

    # --- UI & THEME ---
    # Load Terminal-Icons when the session is idle to speed up prompt display.
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -Action {
        Unregister-Event -SourceIdentifier PowerShell.OnIdle # Ensure this runs only once.
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    } | Out-Null

    # Initialize the oh-my-posh theme engine.
    oh-my-posh init pwsh --config "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\iterm2.omp.json" | Invoke-Expression

    # Initialize Zoxide for intelligent directory navigation.
    Invoke-Expression (& { (zoxide init powershell | Out-String) })

    # --- NATIVE ARGUMENT COMPLETERS ---
    # These provide rich tab-completion for native executables.
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