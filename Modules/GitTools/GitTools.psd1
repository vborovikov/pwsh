@{
    RootModule        = 'GitTools.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '9e427ba5-f456-4ee5-b9e2-d1e3e673c589'
    Author            = 'Vladislav Borovikov'
    CompanyName       = 'Vladislav Borovikov'
    Copyright         = '(c) 2026 Vladislav Borovikov. All rights reserved.'
    Description       = 'PowerShell Git helper functions.'

    PowerShellVersion = '5.1'

    FunctionsToExport = @('New-GitCommit', 'Add-GitWorktree')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('gcommit', 'gwork')

    PrivateData       = @{
        PSData = @{
            Tags         = @('Git', 'Commit', 'Worktree', 'Developer')
            ReleaseNotes = 'Initial release.'
        }
    }
}