# Modules
Import-Module z
if ($PSVersionTable.PSVersion.Major -gt 5) {
    Import-Module Terminal-Icons
}

# PSReadLine
if ($PSVersionTable.PSVersion.Major -gt 5) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView -ShowToolTips
}
else {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ShowToolTips
}
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
New-Variable SkipTitleNames @(
    'net10.0', 'net9.0', 'net8.0', 'net7.0', 'net6.0', 
    'Debug', 'Release', 'bin', 'obj', 'src', 'test', 'build', 
    'code', 'game') -Option Constant

function Prompt {
    $err = $?

    # decoration symbols
    $e = [char]27
    $ps_up = "$e[2m$([char]0x250c)$e[22m"
    $ps_md = "$e[2m$([char]0x2502)$e[22m"
    $ps_dn = "$e[2m$([char]0x2514)$e[22m"
    $ps_cm = "$e[2m$([char]0x2500)$([char]0x25ba)$e[22m"

    # error check
    if ($err -ne $true) {
        $ps_up = "$e[91m$ps_up$e[0m"
        $ps_md = "$e[91m$ps_md$e[0m"
        $ps_dn = "$e[91m$ps_dn$e[0m"
        $ps_cm = "$e[91m$ps_cm$e[0m"
    }
    elseif (Test-Path Variable:/PSDebugContext) {
        $ps_up = "$e[93m$ps_up$e[0m"
        $ps_md = "$e[93m$ps_md$e[0m"
        $ps_dn = "$e[93m$ps_dn$e[0m"
        $ps_cm = "$e[93m$ps_cm$e[0m"
    }

    # date and time
    $time = (Get-Date).ToString('dd.MM H:mm')

    # current path
    $path = $PWD.ProviderPath # important, gets the file system path
    $pathLength = $path.Length
    if ($path.Contains($HOME)) {
        $path = $path.Replace($HOME, '~')
        $pathLength = $path.Length
        $path = $path.Replace('\', "$e[2m\$e[22m")
    }

    # window title
    $titlePath = $PWD.ProviderPath
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
    $git = [GitStatus]::new()

    # project toolset
    $tool = [ProjectToolset]::new()

    # prompt construction

    # prompt start
    $ps_up +
    # date and time
    " $e[36m$e[2m$([char]0x221e)$e[22m $time$e[0m" +
    # current path
    " $e[37m$e[2m$([char]0x2302)$e[22m $path$e[0m" +
    # new line if path is too long
    $(if ($pathLength -gt 80) { "`r`n$ps_md" } else { '' }) +
    # git status
    $(if ($git.HasStatus) { " $e[33m$e[2m$([char]0x20bc)$e[22m$e[0m $($git.ToText())" } else { '' }) +
    # project toolset
    $(if ($tool.HasProject) { " $e[95m$e[2m$([char]0x2261)$e[22m$e[0m $($tool.ToText())" } else { '' }) +
    # prompt end
    "`r`n$ps_dn$ps_cm "
}

# Git status parser
class GitStatus {
    static [bool] $HasGit = $null -ne (Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue)

    [bool] $HasStatus
    [string] $Branch
    [string] $Commit
    [int] $Number
    [bool] $HasChanges 
    [int] $Modified
    [int] $Added
    [int] $Deleted
    [int] $Untracked

    GitStatus() {
        if (-not [GitStatus]::HasGit) {
            return
        }

        $status = (git status --porcelain 2>&1)
        $this.HasStatus = $status -isnot [Management.Automation.ErrorRecord]

        if (-not $this.HasStatus) {
            return
        }

        $this.Branch = (git rev-parse --abbrev-ref HEAD 2>&1)
        $this.Commit = (git log -1 --format=%h 2>&1)
        $this.Number = (git rev-list --count HEAD 2>&1)

        $this.HasChanges = $null -ne $status
        if (-not $this.HasChanges) {
            return
        }

        $status | ForEach-Object {
            if (($_[0] -eq 'M') -or ($_[1] -eq 'M') -or ($_[0] -eq 'R') -or ($_[1] -eq 'R')) {
                $this.Modified += 1
            }
            elseif (($_[0] -eq 'A') -or ($_[1] -eq 'A')) {
                $this.Added += 1
            }
            elseif (($_[0] -eq 'D') -or ($_[1] -eq 'D')) {
                $this.Deleted += 1
            }
            elseif (($_[0] -eq '?') -or ($_[1] -eq '?')) {
                $this.Untracked += 1
            }
        }
    }

    [string] ToText() {
        if (-not $this.HasStatus) {
            return ''
        }
        $e = [char]27

        if ($this.HasChanges) {
            return `
                "$e[91m$($this.Branch)" + 
            "$e[2m[$e[22m" + 
            "$e[2m~$e[22m$(if ($this.Modified -gt 0) {$this.Modified} else {"$e[2m0$e[22m"})" + 
            "$e[2m+$e[22m$(if ($this.Added -gt 0) {$this.Added} else {"$e[2m0$e[22m"})" +
            "$e[2m:$e[22m$(if ($this.Untracked -gt 0) {$this.Untracked} else {"$e[2m0$e[22m"})" +
            "$e[2m-$e[22m$(if ($this.Deleted -gt 0) {$this.Deleted} else {"$e[2m0$e[22m"})" +
            "$e[2m]$e[22m$e[0m" +
            "$e[94m$e[2m#$e[22m$($this.Commit)$e[0m" +
            "$e[33m$e[2m;$e[22m$($this.Number)$e[0m"
        }

        return `
            "$e[92m$($this.Branch)$e[0m" +
        "$e[94m$e[2m#$e[22m$($this.Commit)$e[0m" +
        "$e[33m$e[2m;$e[22m$($this.Number)$e[0m"
    }
}

# Project toolset detector
class ProjectToolset {
    [bool] $HasProject
    hidden [Project] $Project

    ProjectToolset() {
        $this.Project = [ProjectToolset]::Detect()
        $this.HasProject = $null -ne $this.Project
    }

    static [Project] Detect() {
        return [DotnetProject]::TryCreate()
    }

    [string] ToText() {
        if (-not $this.HasProject) {
            return ''
        }

        $e = [char]27
        return "$e[95m$($this.Project.GetMoniker())$e[0m"
    }
}

class Project {
    Project() {
        $type = $this.GetType()
        if ($type -eq [Project]) {
            throw("Class $type must be inherited.")
        }
    }

    [string] GetMoniker() {
        throw('Must override GetMoniker() method.')
    }
}

class DotnetProject : Project {
    hidden static [string] $StubMoniker = '.net'

    [string] $Path

    DotnetProject([string] $csproj) : base() {
        $this.Path = $csproj
    }

    static [DotnetProject] TryCreate() {
        $csprojPath = $PWD.ProviderPath
        $csproj = $null
        do {
            $csproj = Get-ChildItem -Path $csprojPath -Filter '*.csproj' -File -ErrorAction SilentlyContinue
            if ($csproj -is [IO.FileInfo[]]) {
                $csproj = $csproj[0]
                break
            }
    
            $csprojPath = Split-Path $csprojPath -Parent
            if ($csprojPath -eq $global:HOME -or $csprojPath -eq '') {
                break
            }
        } while ($null -eq $csproj)
    
        if ($null -ne $csproj) {
            return [DotnetProject]::new($csproj.FullName)
        }

        return $null
    }

    [string] GetMoniker() {
        # single target framework
        $moniker = (Select-Xml -Path $this.Path -XPath '/Project/PropertyGroup/TargetFramework').Node.InnerText

        # multiple target frameworks
        if ($null -eq $moniker) {
            $moniker = (Select-Xml -Path $this.Path -XPath '/Project/PropertyGroup/TargetFrameworks').Node.InnerText
        }

        # old projects
        if ($null -eq $moniker) {
            $moniker = (Select-Xml -Path $this.Path `
                    -XPath '/vs:Project/vs:PropertyGroup[1]/vs:TargetFrameworkVersion' `
                    -Namespace @{vs = 'http://schemas.microsoft.com/developer/msbuild/2003' }).Node.InnerText
            if ($null -ne $moniker) {
                $moniker = $moniker.Replace('v', 'net')
            }
        }
        
        if ($null -ne $moniker) {
            if ($moniker.Contains('$')) {
                $moniker = [DotnetProject]::StubMoniker
            }
            else {
                $e = [char]27
                $moniker = '.' + $moniker.Replace(';', "$e[2m;$e[22m.")
            }
        }

        return $moniker
    }
}
