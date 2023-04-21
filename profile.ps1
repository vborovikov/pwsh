# Modules
Import-Module z
Import-Module Terminal-Icons

# PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView -ShowToolTips
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

    # git branch
    $git = (git branch --show-current 2>&1)
    if ($git -is [Management.Automation.ErrorRecord]) {
        $git = $null
    }

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
             -Namespace @{vs='http://schemas.microsoft.com/developer/msbuild/2003'}).Node.InnerText
            if ($null -ne $csproj) {
                $csproj = $csproj.Replace('v', '.net')
            }
        }
    }

    # prompt
    $promptLevel = if ($NestedPromptLevel -ge 1) { '>>' } else { '>' }

    $(if (Test-Path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) +
    'PS ' +
    "`e[36m$time`e[0m" +
    '|' + "`e[37m$path`e[0m" +
    $(if ($null -ne $git) { '|' + "`e[92m$git`e[0m" } else { '' }) +
    $(if ($null -ne $csproj) { '|' + "`e[95m$csproj`e[0m" } else { '' }) +
    "`r`nPS $(if ($err -ne $true) {"`e[91m$promptLevel`e[0m"} else {$promptLevel}) "
}
