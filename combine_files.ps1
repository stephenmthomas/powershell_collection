# Combine any type of plain text files into larger chunks with size constraints
# This script recursively collects all .cs files in the current directory and its subdirectories,
# skipping bin and obj folders, and combines them into larger files with a target size range.

# useful for circumventing some LLM file number limits by combining many small files into fewer larger ones, 
# while still keeping each chunk manageable for processing.

$RootPath = (Get-Location).Path
$OutputPrefix = "CombinedCS"
$OutputExtension = ".cs"

# Target chunk size range
$TargetMaxBytes = 250KB

# Collect all .cs files recursively, skipping bin and obj folders
$allCsFiles = Get-ChildItem -Path $RootPath -Recurse -File -Filter "*.cs" |
    Where-Object {
        $_.FullName -notmatch '([\\/])bin([\\/])' -and
        $_.FullName -notmatch '([\\/])obj([\\/])'
    } |
    Sort-Object FullName

if (-not $allCsFiles -or $allCsFiles.Count -eq 0)
{
    Write-Host "No .cs files found."
    exit
}

$fileIndex = 1
$currentBuilder = New-Object System.Text.StringBuilder
$currentBytes = 0

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $baseUri = [System.Uri]((Resolve-Path $BasePath).Path + [System.IO.Path]::DirectorySeparatorChar)
    $fullUri = [System.Uri](Resolve-Path $FullPath).Path
    $relativeUri = $baseUri.MakeRelativeUri($fullUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Get-Utf8ByteCount {
    param(
        [string]$Text
    )

    return [System.Text.Encoding]::UTF8.GetByteCount($Text)
}

function Save-Chunk {
    param(
        [System.Text.StringBuilder]$Builder,
        [int]$Index,
        [string]$Root
    )

    if ($Builder.Length -eq 0) { return }

    $outputPath = Join-Path $Root ("{0}_{1}{2}" -f $OutputPrefix, $Index, $OutputExtension)
    [System.IO.File]::WriteAllText($outputPath, $Builder.ToString(), [System.Text.UTF8Encoding]::new($false))
    $sizeKB = [math]::Round((Get-Item $outputPath).Length / 1KB, 2)
    Write-Host "Saved: $outputPath ($sizeKB KB)"
}

foreach ($csFile in $allCsFiles)
{
    $relativePath = Get-RelativePath -BasePath $RootPath -FullPath $csFile.FullName
    $fileText = [System.IO.File]::ReadAllText($csFile.FullName)

    $block = @"
// ==================================================
// FILE: $relativePath
// ==================================================

$fileText

"@

    $blockBytes = Get-Utf8ByteCount -Text $block

    # If current chunk already has content and adding this block would exceed max size,
    # save current chunk and start a new one.
    if ($currentBytes -gt 0 -and ($currentBytes + $blockBytes) -gt $TargetMaxBytes)
    {
        Save-Chunk -Builder $currentBuilder -Index $fileIndex -Root $RootPath
        $fileIndex++
        $currentBuilder = New-Object System.Text.StringBuilder
        $currentBytes = 0
    }

    [void]$currentBuilder.Append($block)
    $currentBytes += $blockBytes
}

if ($currentBuilder.Length -gt 0)
{
    Save-Chunk -Builder $currentBuilder -Index $fileIndex -Root $RootPath
}

Write-Host "Done."