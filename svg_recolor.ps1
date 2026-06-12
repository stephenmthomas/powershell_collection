param(
    # If true, scans subfolders too.
    [bool]$Recurse = $false,

    # If true, writes *.bak files before modifying SVGs.
    [bool]$Backup = $true
)

$Root = Get-Location

if ($Recurse) {
    $SvgFiles = Get-ChildItem -LiteralPath $Root -Filter "*.svg" -File -Recurse
}
else {
    $SvgFiles = Get-ChildItem -LiteralPath $Root -Filter "*.svg" -File
}

$SvgFiles = $SvgFiles | Where-Object {
    -not $_.Name.StartsWith("vscode-", [System.StringComparison]::OrdinalIgnoreCase)
}

foreach ($File in $SvgFiles) {
    $Path = $File.FullName

    $Text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    if ($Backup) {
        Copy-Item -LiteralPath $Path -Destination "$Path.bak" -Force
    }

    # Replace common SVG color attributes.
    # Handles:
    # fill="red"
    # fill="#123456"
    # stroke="currentColor"
    # stop-color="rgb(...)"
    # color="var(--x)"
    $Text = $Text -replace '(?i)(\b(?:fill|stroke|color|stop-color|flood-color|lighting-color)\s*=\s*["''])([^"'']+)(["''])', '${1}#FFFFFF${3}'

    # Replace inline style color declarations.
    # Handles:
    # style="fill:red; stroke:#000; color:currentColor;"
    $Text = $Text -replace '(?i)(\b(?:fill|stroke|color|stop-color|flood-color|lighting-color)\s*:\s*)([^;"'']+)', '${1}#FFFFFF'

    Set-Content -LiteralPath $Path -Value $Text -Encoding UTF8

    Write-Host "Updated: $($File.Name)"
}

Write-Host ""
Write-Host "SVG color replacement complete."
Write-Host "Files updated: $($SvgFiles.Count)"
