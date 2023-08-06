using namespace System.IO
using namespace System.Management.Automation

param([DirectoryInfo]$Flac, [DirectoryInfo]$Mp3)

# check if flac directory exists
#
if ($null -eq $Flac)
{
    [DirectoryInfo]$Flac = $Pwd.Path
}
elseif (-not (Test-Path -Path $Flac)) {
    Write-Error -Message "Directory '$Flac' does not exist" -Category ObjectNotFound
    exit -1
}
else {
    [DirectoryInfo]$Flac = (Resolve-Path -Path $Flac).Path
}

# check if mp3 directory exists
#
if ($null -eq $Mp3)
{
    [DirectoryInfo]$Mp3 = $Pwd.Path
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
$flacFiles = Get-ChildItem -Path $Flac -Filter *.flac
if ($flacFiles.Count -eq 0) {
    Write-Error -Message "No flac files found in '$Flac'" -Category ObjectNotFound
    exit -4
}

# convert flac files to mp3
#
foreach ($flacFile in $flacFiles) {
    [FileInfo]$mp3File = Join-Path -Path $Mp3 -ChildPath ([Path]::ChangeExtension($FlacFile.Name, '.mp3'))
    Write-Host "Converting '$flacFile' to '$mp3File'"

    ffmpeg -i $flacFile.FullName -ab 320k -map_metadata 0 -id3v2_version 3 $mp3File.FullName
}