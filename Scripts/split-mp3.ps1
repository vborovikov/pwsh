using namespace System.IO
using namespace System.Management.Automation

param(
    [Parameter(Mandatory = $true)]
    [FileInfo]$Mp3File,
    [FileInfo]$CueFile,
    [int]$DiscNumber = 1,
    [DirectoryInfo]$OutputDir
)

# check if mp3 file exists
#
if (-not (Test-Path -Path $Mp3File)) {
    Write-Error -Message "MP3 file '$Mp3File' does not exist" -Category ObjectNotFound
    exit -1
}
else {
    [FileInfo]$Mp3File = (Resolve-Path -Path $Mp3File).Path
}

# if cue file is not specified, look for corresponding cue file
#
if ($null -eq $CueFile) {
    [FileInfo]$CueFile = [Path]::ChangeExtension($Mp3File.FullName, '.cue')
    if (-not (Test-Path -LiteralPath $CueFile)) {
        Write-Error -Message "CUE file '$CueFile' does not exist and no CUE file was specified" -Category ObjectNotFound
        exit -2
    }
}
elseif (-not (Test-Path -Path $CueFile)) {
    Write-Error -Message "CUE file '$CueFile' does not exist" -Category ObjectNotFound
    exit -3
}
else {
    [FileInfo]$CueFile = (Resolve-Path -Path $CueFile).Path
}

# check if output directory exists, or create it
#
if ($null -eq $OutputDir) {
    [DirectoryInfo]$OutputDir = Split-Path -Path $Mp3File -Parent
}
elseif (-not (Test-Path -Path $OutputDir)) {
    try {
        New-Item -ItemType Directory -Path $OutputDir -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error -Message "Could not create output directory '$OutputDir': $($_.Exception.Message)" -Category InvalidOperation
        exit -4
    }
}
else {
    [DirectoryInfo]$OutputDir = (Resolve-Path -Path $OutputDir).Path
}

# check if can run ffmpeg
#
if (-not (Get-Command -Name ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error -Message "ffmpeg not found" -Category ObjectNotFound
    exit -5
}

Write-Host "Splitting '$Mp3File' using '$CueFile' into '$OutputDir'"

# this uses the concat demuxer approach with a generated file list from the cue
try {
    # read the cue file to get track information
    $cueLines = Get-Content -LiteralPath $CueFile.FullName
    $trackCount = 0

    foreach ($line in $cueLines) {
        if ($line -match 'TRACK\s+\d{2}') {
            $trackCount++
        }
    }

    Write-Host "Found $trackCount tracks in cue file"

    # since ffmpeg can't directly use cue files for splitting, we need to parse it manually
    # and generate the appropriate commands for each track based on the cue sheet

    $tracks = @()
    $currentTrack = @{}
    $trackNumber = 1
    $albumTitle = [Path]::ChangeExtension($Mp3File.Name, '')
    # in case the CUE sheet is for the FLAC file
    [FileInfo]$FlacFile = [Path]::ChangeExtension($Mp3File.FullName, '.flac')

    for ($i = 0; $i -lt $cueLines.Length; $i++) {
        $line = $cueLines[$i].Trim()
        if ($line -notmatch 'FILE\s+"(.+)"\s+([\w\d]+)') {
            if ($line -match '^TITLE\s+"(.+)"') {
                $albumTitle = $matches[1]
            }

            continue
        }

        $fileName = $matches[1]
        $fileFormat = $matches[2]
        if (($fileName -eq $Mp3File.Name -and $fileFormat -eq 'MP3') -or
            ($fileName -eq $FlacFile.Name -and $fileFormat -eq 'WAVE')) {
            $i++;

            for ($j = $i; $j -lt $cueLines.Length; $j++) {
                $line = $cueLines[$j].Trim()
                if ($line -match '^TRACK\s+(\d+)\s+') {
                    if ($currentTrack.Count -gt 0) {
                        $tracks += $currentTrack
                    }
                    $currentTrack = @{}
                    $currentTrack["TrackNumber"] = [int]$matches[1]
                    $currentTrack["TrackTitle"] = "Track $($matches[1])"
                }
                elseif ($line -match '^TITLE\s+"(.+)"') {
                    $currentTrack["TrackTitle"] = $matches[1]
                }
                elseif ($line -match 'PERFORMER "(.+)"') {
                    $currentTrack["TrackPerformer"] = $matches[1]
                }
                elseif ($line -match '^INDEX\s+\d{2}\s+(\d{2}):(\d{2}):(\d{2})') {
                    $minutes = [int]$matches[1]
                    $seconds = [int]$matches[2]
                    $frames = [int]$matches[3]
                    # Convert to time in format HH:MM:SS
                    $timeInSec = $minutes * 60 + $seconds + ($frames / 75)
                    $currentTrack["StartTime"] = "{0:D2}:{1:D2}:{2:D2}" -f [int][math]::Floor($timeInSec / 3600), [int][math]::Floor(($timeInSec % 3600) / 60), [int][math]::Floor($timeInSec % 60)
                }
            }

            break
        }
    }

    # add the last track
    if ($currentTrack.Count -gt 0) {
        $tracks += $currentTrack
    }

    # process each track to split the mp3 file
    for ($i = 0; $i -lt $tracks.Count; $i++) {
        $track = $tracks[$i]
        $trackNumber = $track.TrackNumber
        $trackTitle = $track.TrackTitle
        $trackPerformer = $track.TrackPerformer

        if ($i -lt ($tracks.Count - 1)) {
            $nextTrack = $tracks[$i + 1]
            $endTime = $nextTrack.StartTime
        }
        else {
            # For the last track, we need to get the duration of the full file
            # We'll use ffprobe to get the total duration and use that as end time
            $totalDuration = & ffprobe -v quiet -show_entries format=duration -of csv=p=0 $Mp3File.FullName
            $endTime = [TimeSpan]::FromSeconds([double]$totalDuration).ToString('hh\:mm\:ss\.ff')
        }

        # Format start time properly
        $startTime = $track.StartTime

        # Create output filename with track number and title
        $outputFileName = "{0:D2} {1} - {2}.mp3" -f $trackNumber, [Regex]::Replace($trackPerformer, '[<>:"/\\|?*]', '_'), [Regex]::Replace($trackTitle, '[<>:"/\\|?*]', '_')
        $outputFilePath = Join-Path $OutputDir $outputFileName

        Write-Host "Extracting track #$trackNumber $trackTitle by $trackPerformer to '$outputFileName'"

        # Use ffmpeg to extract the specific track from the full mp3
        $extractArgs = @(
            '-y',
            # input MP3
            '-ss', $startTime, '-to', $endTime,
            '-i', $Mp3File.FullName,
            # copying
            '-acodec', 'copy', '-avoid_negative_ts', 'make_zero',
            # metadata mapping
            '-map_metadata', '0', 
            '-c:v', 'copy', '-disposition:v:0', 'attached_pic',
            '-metadata', "album=$albumTitle",
            '-metadata', "disc=$DiscNumber",
            '-metadata', "track=$trackNumber",
            '-metadata', "title=$trackTitle",
            '-metadata', "artist=$trackPerformer",
            '-id3v2_version', '3', '-write_id3v1', '1',
            # output
            $outputFilePath
        )

        $result = & ffmpeg $extractArgs 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Error extracting track ${trackNumber}:`n$result"
        }
    }

    Write-Host "Splitting completed. Files saved to '$OutputDir'"
}
catch {
    Write-Error -Message "Error during splitting: $($_.Exception.Message)" -Category InvalidOperation
    exit -6
}