# Prefix every file in the same directory as this script.

$prefix = "prefix_"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path


#change filter if you want!

Get-ChildItem -Path $scriptDir -File -Filter "*.*" | ForEach-Object {
    # Avoid adding the prefix more than once.
    if (-not $_.Name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $newName = $prefix + $_.Name
        Rename-Item -LiteralPath $_.FullName -NewName $newName
        Write-Host "$($_.Name) -> $newName"
    }
}
