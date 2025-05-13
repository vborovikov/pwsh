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

# Moves a SQL LocalDB database to a new location
function Move-LocalDB {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Database,
        [Parameter(Mandatory)]
        [string]$Destination,
        [Parameter()]
        [string]$Instance = 'MSSQLLocalDB',
        [Parameter()]
        [string]$Path = $HOME
    )

    if ($null -eq (Get-Command -Name 'sqlcmd' -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error "SqlCmd program not found."
        return
    }

    $OldMdfFilePath = Join-Path -Path $Path -ChildPath "$Database.mdf"
    $OldLdfFilePath = Join-Path -Path $Path -ChildPath "${Database}_log.ldf"
    if (!(Test-Path -Path $OldMdfFilePath) -or !(Test-Path -Path $OldLdfFilePath)) {
        Write-Error "File '$OldMdfFilePath' or '$OldLdfFilePath' not found."
        return
    }

    $MdfFilePath = Join-Path -Path $Destination -ChildPath "$Database.mdf"
    $LdfFilePath = Join-Path -Path $Destination -ChildPath "${Database}_log.ldf"
    if ((Test-Path -Path $MdfFilePath) -or (Test-Path -Path $LdfFilePath)) {
        Write-Error "File '$MdfFilePath' or '$LdfFilePath' already exists."
        return
    }

    # alter database record
    sqlcmd -S "(LocalDB)\$Instance" -d master -Q "ALTER DATABASE $Database MODIFY FILE (NAME = '$Database', FILENAME = '$MdfFilePath');" -I
    sqlcmd -S "(LocalDB)\$Instance" -d master -Q "ALTER DATABASE $Database MODIFY FILE (NAME = '${Database}_log', FILENAME = '$LdfFilePath');" -I
    sqlcmd -S "(LocalDB)\$Instance" -d master -Q "ALTER DATABASE $Database SET OFFLINE WITH ROLLBACK IMMEDIATE;" -I

    # move files
    Move-Item -Path $OldMdfFilePath -Destination $MdfFilePath -Force
    Move-Item -Path $OldLdfFilePath -Destination $LdfFilePath -Force

    # bring database online
    sqlcmd -S "(LocalDB)\$Instance" -d master -Q "ALTER DATABASE $Database SET ONLINE;" -I
}    