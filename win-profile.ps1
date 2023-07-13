# Modules
Import-Module z

# PSReadLine
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ShowToolTips
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Aliases
Set-Alias touch New-Item
Set-Alias file Find-File
Set-Alias find Find-File
Set-Alias open Open-File
Set-Alias edit Open-File

# Prompt
# Replaces $Home part of the current path with '~'
# time | path | git | .net

New-Variable PSWindowTitle $Host.UI.RawUI.WindowTitle -Option Constant
New-Variable SkipTitleNames @('net8.0', 'net7.0', 'net6.0', 'Debug', 'Release', 'bin', 'obj', 'src', 'test', 'build', 'code', 'game') -Option Constant

function Prompt {
    # error
    $err = $?

    # time
    $time = (Get-Date).ToString('dd.MM H:mm')

    # path
    $dir = (Convert-Path .)
    $path = $dir
    if ($path.Contains($Home)) {
        $path = $path.Replace($Home, '~')
    }

    # title
    $titlePath = $dir
    $title = Split-Path $titlePath -Leaf
    while ($SkipTitleNames -contains $title) {
        # skip this folder name    
        $titlePath = Split-Path $titlePath -Parent
        if ($titlePath.Length -eq 0) {
            break
        }
        $title = Split-Path $titlePath -Leaf
    }
    if ($title.Length -gt 15) {
        $title = $title.Substring(0, 15) + [char]0x2026
    }
    if ($title.Length -gt 0) {
        # set window title
        $host.UI.RawUI.WindowTitle = $title + " - $PSWindowTitle"
    }

    # git status
    $git = New-Object -TypeName GitStatus

    # dotnet
    $csprojPath = $dir
    $csproj = $null
    do {
        $csproj = Get-ChildItem -Path $csprojPath -Filter '*.csproj' -File -ErrorAction SilentlyContinue
        if ($csproj -is [IO.FileInfo[]]) {
            $csproj = $csproj[0]
            break
        }

        $csprojPath = Split-Path $csprojPath -Parent
        if ($csprojPath -eq $Home -or $csprojPath -eq '') {
            break
        }
    } while ($null -eq $csproj)
    if ($null -ne $csproj) {
        $csprojPath = $csproj
        $csproj = (Select-Xml -Path $csprojPath -XPath '/Project/PropertyGroup/TargetFramework').Node.InnerText
        if ($null -ne $csproj) {
            $csproj = '.' + $csproj
        }
        else {
            # old projects
            $csproj = (Select-Xml -Path $csprojPath `
                    -XPath '/vs:Project/vs:PropertyGroup[1]/vs:TargetFrameworkVersion' `
                    -Namespace @{vs = 'http://schemas.microsoft.com/developer/msbuild/2003' }).Node.InnerText
            if ($null -ne $csproj) {
                $csproj = $csproj.Replace('v', '.net')
            }
        }
    }

    # prompt
    $promptLevel = if ($NestedPromptLevel -ge 1) { '>>' } else { '>' }
    $e = [char]27

    $(if (Test-Path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) +
    'PS ' +
    # date and time
    "$e[36m$time$e[0m" +
    # current path
    '|' + "$e[37m$path$e[0m" +
    # git status
    $(if ($git.HasStatus) { '|' + $git.ToText() } else { '' }) +
    # dotnet version
    $(if ($null -ne $csproj) { '|' + "$e[95m$csproj$e[0m" } else { '' }) +
    # prompt level and error state
    "`r`nPS $(if ($err -ne $true) {"$e[91m$promptLevel$e[0m"} else {$promptLevel}) "
}

# Git status parser
class GitStatus {
    [bool]$HasStatus
    [string]$Branch
    [bool]$HasChanges 
    [int]$Modified
    [int]$Added
    [int]$Deleted
    [int]$Untracked

    GitStatus() {
        $status = (git status --porcelain 2>&1)
        $this.HasStatus = $status -isnot [Management.Automation.ErrorRecord]
        if ($this.HasStatus) {
            $this.Branch = (git branch --show-current 2>&1)
            $this.HasChanges = $null -ne $status
            if ($this.HasChanges) {
                $status | ForEach-Object {
                    if (($_[1] -eq 'M') -or ($_[1] -eq 'R')) {
                        $this.Modified += 1
                    }
                    elseif (($_[0] -eq 'A') -or ($_[1] -eq 'A')) {
                        $this.Added += 1
                    }
                    elseif ($_[1] -eq 'D') {
                        $this.Deleted += 1
                    }
                    elseif ($_[1] -eq '?') {
                        $this.Untracked += 1
                    }
                }
            }
        }
    }

    [string]ToText() {
        if (-not $this.HasStatus) {
            return $null
        }
        $e = [char]27

        if ($this.HasChanges) {
            return `
                "$e[91m$($this.Branch)$e[0m" + 
                "$e[2m[$e[22m" + 
                "$e[2m~$e[22m$(if ($this.Modified -gt 0) {"$e[91m$($this.Modified)$e[0m"} else {"$e[2m0$e[22m"})" + 
                "$e[2m+$e[22m$(if ($this.Added -gt 0) {"$e[91m$($this.Added)$e[0m"} else {"$e[2m0$e[22m"})" +
                "$e[2m:$e[22m$(if ($this.Untracked -gt 0) {"$e[91m$($this.Untracked)$e[0m"} else {"$e[2m0$e[22m"})" +
                "$e[2m-$e[22m$(if ($this.Deleted -gt 0) {"$e[91m$($this.Deleted)$e[0m"} else {"$e[2m0$e[22m"})" +
                "$e[2m]$e[22m"
        }

        return "$e[92m$($this.Branch)$e[0m"
    }
}
