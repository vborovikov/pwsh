# Utility functions

function Find-File {
    [OutputType([IO.FileInfo[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )
    Get-ChildItem -Recurse -Filter "${FileName}" -File -ErrorAction SilentlyContinue
}

function Open-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Pipeline')]
        [IO.FileInfo]$InputObject,
        [Parameter(Position = 0, ParameterSetName = 'Pipeline')]
        [Int32[]]$Index = @(),
        [Parameter(Position = 0, ParameterSetName = 'FileName')]
        [string]$FileName
    )

    begin {
        $editor = 'C:\Program Files\EditPlus\editplus.exe'
        $skipProcess = $PSBoundParameters.ContainsKey('FileName')
        if ($skipProcess) {
            Start-Process -FilePath $editor -ArgumentList @("`"$FileName`"")
            return
        }
        $idx = 0
    }

    process {
        if ($skipProcess) {
            return
        }

        if ($Index.Contains($idx++) -or $Index.Length -eq 0) {
            Start-Process -FilePath $editor -ArgumentList @("`"$InputObject`"")
        }
    }
}
