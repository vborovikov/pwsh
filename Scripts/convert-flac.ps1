using namespace System.IO
using namespace System.Management.Automation

param(
    [Parameter(Mandatory = $true)]
    [DirectoryInfo]$Flac, 
    [DirectoryInfo]$Mp3)

# check if flac directory exists
#
if ($null -eq $Flac) {
    [DirectoryInfo]$Flac = $Pwd.Path
}
elseif (-not (Test-Path -Path $Flac)) {
    Write-Error -Message "Directory '$Flac' does not exist" -Category ObjectNotFound
    exit -1
}
else {
    [DirectoryInfo]$Flac = (Resolve-Path -Path $Flac).Path
}

$recursiveMode = $false

# check if mp3 directory exists
#
if ($null -eq $Mp3) {
    [DirectoryInfo]$Mp3 = $Flac
    $recursiveMode = $true
}
elseif (-not (Test-Path -Path $Mp3)) {
    Write-Error -Message "Directory '$Mp3' does not exist" -Category ObjectNotFound
    exit -2
}
else {
    [DirectoryInfo]$Mp3 = (Resolve-Path -Path $Mp3).Path
}

# check if can run ffmpeg
#
if (-not (Get-Command -Name ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error -Message "ffmpeg not found" -Category ObjectNotFound
    exit -3
}


# get all flac files
#
$flacFiles = if ($recursiveMode) {
    Get-ChildItem -LiteralPath $Flac -Filter '*.flac' -Recurse
}
else {
    Get-ChildItem -LiteralPath $Flac -Filter '*.flac'
}

if ($flacFiles.Count -eq 0) {
    Write-Error -Message "No flac files found in '$Flac'" -Category ObjectNotFound
    exit -4
}

# convert flac files to mp3
#
foreach ($flacFile in $flacFiles) {
    [FileInfo]$mp3File = [Path]::ChangeExtension($flacFile.FullName, '.mp3')
    if (-not $recursiveMode) { 
        [FileInfo]$mp3File = Join-Path -Path $Mp3 -ChildPath ([Path]::ChangeExtension($flacFile.Name, '.mp3'))
    }

    Write-Host "Converting '$flacFile' to '$mp3File'"
    $convertArgs = @(
        '-y',
        # input FLAC
        '-i', $flacFile.FullName
        # MP3 quality
        '-ab', '320k',
        # metadata mapping
        '-map_metadata', '0',
        '-c:v', 'copy', '-disposition:v:0', 'attached_pic',
        '-id3v2_version', '3', '-write_id3v1', '1',
        # output MP3
        $mp3File.FullName
    )
    $result = & ffmpeg $convertArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Error converting '$flacFile':`n$result"
    }
}