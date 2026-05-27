$prefix = "DL_"
$suffix = ""
$fileList = Join-Path $PSScriptRoot "rename_from_list.txt"

Get-Content $fileList | ForEach-Object {
    $oldPath = $_.Trim().Trim('"')

    if ([string]::IsNullOrWhiteSpace($oldPath)) {
        return
    }

    if (-not (Test-Path -LiteralPath $oldPath)) {
        Write-Warning "File not found: $oldPath"
        return
    }

    $dir  = Split-Path $oldPath -Parent
    $name = [System.IO.Path]::GetFileNameWithoutExtension($oldPath)
    $ext  = [System.IO.Path]::GetExtension($oldPath)

    $newName = "$prefix$name$suffix$ext"
    $newPath = Join-Path $dir $newName

    if (Test-Path -LiteralPath $newPath) {
        Write-Warning "Target already exists, skipping: $newPath"
        return
    }

    Rename-Item -LiteralPath $oldPath -NewName $newName

    Write-Host "Renamed: $oldPath -> $newPath"
}