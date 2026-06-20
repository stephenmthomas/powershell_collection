param(
    [bool]$ConcatPaths = $true,
    [bool]$CondensedOutput = $true,
    [string]$ViewBox = "0 0 24 24"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "SVG Symbol Extractor"
    Write-Host "--------------------"

    # Use the folder where this script lives.
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

    if ([string]::IsNullOrWhiteSpace($ScriptRoot)) {
        $ScriptRoot = (Get-Location).Path
    }

    Write-Host "Scanning folder:"
    Write-Host $ScriptRoot
    Write-Host ""

    $svgFiles = Get-ChildItem -Path $ScriptRoot -Filter "*.svg" -File

    Write-Host "SVG files found: $($svgFiles.Count)"
    Write-Host ""

    $TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $HexCode = "{0:X4}" -f (Get-Random -Minimum 0 -Maximum 65536)

    $SvgOutput = Join-Path $ScriptRoot "svgSymbols_$TimeStamp`_$HexCode.svg"

    $symbols = New-Object System.Collections.Generic.List[string]

    foreach ($file in $svgFiles) {
        Write-Host "Reading: $($file.Name)"

        $text = Get-Content -Path $file.FullName -Raw

        # Matches double-quoted d attributes:
        # <path d="..." />
        $matches = [regex]::Matches($text, 'd="([^"]+)"')

        Write-Host "  Paths found: $($matches.Count)"

        $paths = New-Object System.Collections.Generic.List[string]

        foreach ($m in $matches) {
            $pathData = $m.Groups[1].Value

            if (![string]::IsNullOrWhiteSpace($pathData)) {
                $paths.Add($pathData)
            }
        }

        $name = $file.BaseName

        # XML-escape symbol id and path data.
        $safeName = [System.Security.SecurityElement]::Escape($name)

        if ($ConcatPaths) {
            $combinedPath = ($paths -join " ").Trim()
            $safePath = [System.Security.SecurityElement]::Escape($combinedPath)

            $symbols.Add("<symbol id=`"$safeName`" viewBox=`"$ViewBox`"><path d=`"$safePath`"/></symbol>")
        }
        else {
            # Multiple separate <path> elements inside one <symbol>.
            $pathTags = New-Object System.Collections.Generic.List[string]

            foreach ($p in $paths) {
                $safePath = [System.Security.SecurityElement]::Escape($p)
                $pathTags.Add("<path d=`"$safePath`"/>")
            }

            $symbols.Add("<symbol id=`"$safeName`" viewBox=`"$ViewBox`">$($pathTags -join '')</symbol>")
        }
    }

    $output = $symbols -join "`r`n"

    Set-Content -Path $SvgOutput -Value $output -Encoding UTF8

    Write-Host ""
    Write-Host "Done."
    Write-Host "SVG symbols written to:"
    Write-Host $SvgOutput
}
catch {
    Write-Host ""
    Write-Host "ERROR:"
    Write-Host $_.Exception.Message
    Write-Host ""
    Write-Host "Full error:"
    Write-Host $_
}
finally {
    Write-Host ""
    Read-Host "Press Enter to exit"
}