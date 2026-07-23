
# Removes metadata, ID3 tags, chapters, and embedded artwork from every MP3
# in the same directory as this script.
#
# The MP3 audio stream is copied directly without re-encoding.

# ------------------------------------------------------------
# SETTINGS
# ------------------------------------------------------------

# $false = place cleaned copies in a "cleaned" subfolder.
# $true  = replace the original MP3 files after successful processing.
$ReplaceOriginals = $false

# $true  = remove literal spaces from filenames.
# $false = preserve the original filenames.
#
# Example:
# "My Song.mp3" becomes "MySong.mp3"
$RemoveSpaces = $true

# Path to your FFmpeg executable.
$ffmpegPath = "C:\FFMPEG\ffmpeg.exe"

# ------------------------------------------------------------
# VALIDATION
# ------------------------------------------------------------

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ffmpegPath -PathType Leaf)) {
    throw "FFmpeg was not found at: $ffmpegPath"
}

$sourceDirectory = $PSScriptRoot
$outputDirectory = Join-Path $sourceDirectory "cleaned"

if (-not $ReplaceOriginals) {
    New-Item `
        -ItemType Directory `
        -Path $outputDirectory `
        -Force | Out-Null
}

$files = @(
    Get-ChildItem `
        -LiteralPath $sourceDirectory `
        -Filter "*.mp3" `
        -File
)

if ($files.Count -eq 0) {
    Write-Host "No MP3 files were found in:"
    Write-Host $sourceDirectory
    exit
}

# Track output names so two source files cannot accidentally produce
# the same destination name after spaces are removed.
$outputNames = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

# ------------------------------------------------------------
# PROCESS FILES
# ------------------------------------------------------------

foreach ($file in $files) {
    $finalName = $file.Name

    if ($RemoveSpaces) {
        $finalName = $finalName.Replace(" ", "")
    }

    if ([string]::IsNullOrWhiteSpace($finalName)) {
        Write-Warning "Skipped invalid filename: $($file.Name)"
        continue
    }

    if (-not $outputNames.Add($finalName)) {
        Write-Warning "Skipped because multiple files would produce the same name:"
        Write-Warning "  $finalName"
        continue
    }

    if ($ReplaceOriginals) {
        $finalPath = Join-Path $file.DirectoryName $finalName

        # Use a unique temporary filename in the original directory.
        $temporaryName = "{0}.__cleaning__.{1}.mp3" -f `
            $file.BaseName,
            ([Guid]::NewGuid().ToString("N"))

        $outputFile = Join-Path $file.DirectoryName $temporaryName
    }
    else {
        $finalPath = Join-Path $outputDirectory $finalName
        $outputFile = $finalPath
    }

    Write-Host ""
    Write-Host "Processing: $($file.Name)"

    try {
        # Avoid accidentally overwriting another file when spaces are removed.
        if (
            (Test-Path -LiteralPath $finalPath) -and
            ($finalPath -ne $file.FullName)
        ) {
            throw "Destination already exists: $finalPath"
        }

        & $ffmpegPath `
            -hide_banner `
            -loglevel error `
            -y `
            -i $file.FullName `
            -map "0:a:0" `
            -c:a copy `
            -map_metadata -1 `
            -map_chapters -1 `
            -id3v2_version 0 `
            -write_id3v1 0 `
            $outputFile

        if ($LASTEXITCODE -ne 0) {
            throw "FFmpeg returned exit code $LASTEXITCODE."
        }

        if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
            throw "FFmpeg did not create the expected output file."
        }

        if ((Get-Item -LiteralPath $outputFile).Length -eq 0) {
            throw "FFmpeg created an empty output file."
        }

        if ($ReplaceOriginals) {
            if ($finalPath -eq $file.FullName) {
                # Same filename: replace the original only after FFmpeg succeeds.
                [System.IO.File]::Replace(
                    $outputFile,
                    $file.FullName,
                    $null,
                    $true
                )
            }
            else {
                # Renamed filename: preserve the original until the cleaned
                # file has been successfully moved into its final location.
                Move-Item `
                    -LiteralPath $outputFile `
                    -Destination $finalPath

                Remove-Item `
                    -LiteralPath $file.FullName `
                    -Force
            }

            Write-Host "Replaced: $finalName"
        }
        else {
            Write-Host "Created: $finalPath"
        }
    }
    catch {
        Write-Warning "Failed: $($file.Name)"
        Write-Warning $_.Exception.Message

        if (
            $outputFile -and
            (Test-Path -LiteralPath $outputFile) -and
            ($outputFile -ne $finalPath)
        ) {
            Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
Write-Host "Finished."
