function New-GitCommit {
    <#
    .SYNOPSIS
        Creates a Git commit with a specified commit date.

    .DESCRIPTION
        Sets the author and committer dates for the duration of the Git commit,
        optionally stages the specified paths, and restores the original
        environment variables afterward.

    .PARAMETER Message
        Commit message.

    .PARAMETER When
        Date and time to use for the author and committer dates. Must be in the past.

    .PARAMETER Path
        Paths to stage when Stage is specified. Defaults to the current directory.

    .PARAMETER Stage
        Stages the specified paths before creating the commit.

    .PARAMETER Amend
        Amends the previous commit instead of creating a new commit.

    .EXAMPLE
        New-GitCommit -Message 'Fix login issue' -When (Get-Date).AddDays(-1)

    .EXAMPLE
        New-GitCommit -Message 'Update documentation' -When (Get-Date).AddHours(-2) -Path README.md -Stage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory, Position = 1)]
        [ValidateScript({
            if ($_ -lt [DateTimeOffset]::Now) {
                $true
            }
            else {
                throw "When must be in the past."
            }
        })]
        [DateTimeOffset]$When,

        [Parameter(Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path = @('.'),

        [switch]$Stage,
        [switch]$Amend
    )

    $date = $When.ToString("yyyy-MM-ddTHH:mm:sszzz")

    $oldAuthorDate = $env:GIT_AUTHOR_DATE
    $oldCommitterDate = $env:GIT_COMMITTER_DATE

    try {
        $env:GIT_AUTHOR_DATE = $date
        $env:GIT_COMMITTER_DATE = $date

        if ($Stage -and -not $Amend) {
            git add -- @Path
            if ($LASTEXITCODE -ne 0) {
                throw "git add failed with exit code $LASTEXITCODE."
            }
        }

        $gitArgs = @('commit')

        if ($Amend) {
            $gitArgs += '--amend'
        }

        $gitArgs += @('-m', $Message)

        & git @gitArgs

        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        if ($null -ne $oldAuthorDate) {
            $env:GIT_AUTHOR_DATE = $oldAuthorDate
        }
        else {
            Remove-Item Env:GIT_AUTHOR_DATE -ErrorAction Ignore
        }

        if ($null -ne $oldCommitterDate) {
            $env:GIT_COMMITTER_DATE = $oldCommitterDate
        }
        else {
            Remove-Item Env:GIT_COMMITTER_DATE -ErrorAction Ignore
        }
    }
}

function Add-GitWorktree {
    <#
    .SYNOPSIS
        Adds a Git worktree next to the main working tree.

    .DESCRIPTION
        The worktree directory name is deduced from the last segment of the branch name.

        Example:
            Branch: feature/login
            Main repository directory: C:\source\myapp
            Worktree directory: C:\source\login

    .PARAMETER Branch
        Branch to check out in the new worktree.

    .EXAMPLE
        Add-GitWorktree -Branch feature/login

    .EXAMPLE
        Add-GitWorktree -Branch bugfix/123-crash
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Branch
    )

    begin {
        function ConvertTo-NativePath {
            param(
                [Parameter(Mandatory)]
                [string]$Path
            )

            # Convert Git/MSYS style paths like /c/Users/Vlad to C:\Users\Vlad
            if ($Path -match '^/(?<drive>[a-zA-Z])/(?<rest>.*)$') {
                $drive = $Matches.drive
                $rest = $Matches.rest -replace '/', '\'
                return "${drive}:\$rest"
            }

            return [System.IO.Path]::GetFullPath($Path)
        }

        function Get-GitMainWorktreePath {
            # Prefer the real main worktree, even if currently inside another worktree.
            $porcelain = & git worktree list --porcelain 2>$null

            if ($LASTEXITCODE -eq 0 -and $porcelain) {
                $first = $porcelain | Select-Object -First 1

                if ($first -like 'worktree *') {
                    $path = ($first -replace '^worktree\s+', '').Trim().Trim('"')
                    return ConvertTo-NativePath -Path $path
                }
            }

            # Fallback: current repository root.
            $top = & git rev-parse --show-toplevel 2>$null

            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($top)) {
                throw 'Unable to determine the main Git working directory.'
            }

            return ConvertTo-NativePath -Path $top.Trim()
        }

        function Get-SafeDirectoryName {
            param(
                [Parameter(Mandatory)]
                [string]$Name
            )

            $safe = $Name

            foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
                $safe = $safe.Replace($char.ToString(), '-')
            }

            $safe = $safe.Trim().Trim('.')

            if ([string]::IsNullOrWhiteSpace($safe) -or $safe -in '.', '..') {
                throw "Cannot deduce a valid directory name from '$Name'."
            }

            return $safe
        }
    }

    process {
        $inside = & git rev-parse --is-inside-work-tree 2>$null

        if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') {
            throw 'Not inside a Git working tree.'
        }

        $mainRoot = Get-GitMainWorktreePath
        $parent = Split-Path -Path $mainRoot -Parent

        if ([string]::IsNullOrWhiteSpace($parent)) {
            throw "Unable to determine the parent directory of '$mainRoot'."
        }

        $leaf = $Branch -split '[\\/]' |
            Where-Object { $_ -ne '' } |
            Select-Object -Last 1

        if ([string]::IsNullOrWhiteSpace($leaf)) {
            throw "Cannot deduce a worktree directory name from branch '$Branch'."
        }

        $directoryName = Get-SafeDirectoryName -Name $leaf
        $worktreePath = Join-Path -Path $parent -ChildPath $directoryName

        if (Test-Path -Path $worktreePath) {
            throw "Target directory already exists: $worktreePath"
        }

        Write-Verbose "Main working directory: $mainRoot"
        Write-Verbose "Worktree path: $worktreePath"

        $null = & git show-ref --verify --quiet "refs/heads/$Branch" 2>$null
        $branchExists = $LASTEXITCODE -eq 0

        if ($branchExists) {
            $output = & git worktree add -- "$worktreePath" "$Branch" 2>&1
        }
        else {
            $output = & git worktree add -b "$Branch" -- "$worktreePath" 2>&1
        }

        if ($LASTEXITCODE -ne 0) {
            throw "git worktree add failed:`n$($output -join [Environment]::NewLine)"
        }

        $output | Write-Verbose

        [pscustomobject]@{
            Branch = $Branch
            Path   = $worktreePath
        }
    }
}

Set-Alias -Name 'gcommit' -Value 'New-GitCommit'
Set-Alias -Name 'gwork' -Value 'Add-GitWorktree'

Export-ModuleMember -Function New-GitCommit, Add-GitWorktree -Alias gcommit, gwork