param(
    # How many directory levels below the script folder to scan.
    # 0 = only files directly beside the script
    # 1 = files in script folder + immediate child folders
    # 2 = one level deeper, etc.
    [int]$Depth = 999,

    # Comma-separated directory names to ignore.
    # Example: "bin,obj,.git,node_modules"
    [string]$IgnoredDirectories = "",

    # Comma-separated file extensions to ignore.
    # Example: ".dll,.exe,.pdb"
    # Also accepts "dll,exe,pdb"
    [string]$IgnoredTypes = "",

    # false = ignored types are excluded
    # true  = ignored types become the ONLY accepted types
    # does not impact IgnoredDirectories
    [bool]$InvertIgnore = $false,

    # If true, output paths relative to the script directory.
    # If false, output full paths.
    [bool]$TrimUpward = $true
)

# ------------------------------------------------------------
# Resolve script root
# ------------------------------------------------------------

$ScriptRoot = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($ScriptRoot)) {
    $ScriptRoot = Get-Location
}

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$HexCode = "{0:X4}" -f (Get-Random -Minimum 0 -Maximum 65536)

$OutputFileName = "dir_scan_output_$TimeStamp`_$HexCode.txt"
$OutputFile = Join-Path $ScriptRoot $OutputFileName

# ------------------------------------------------------------
# Normalize ignore lists
# ------------------------------------------------------------

$IgnoredDirSet = @{}

if (-not [string]::IsNullOrWhiteSpace($IgnoredDirectories)) {
    $IgnoredDirectories.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        ForEach-Object {
            $IgnoredDirSet[$_.ToLowerInvariant()] = $true
        }
}

$IgnoredTypeSet = @{}

if (-not [string]::IsNullOrWhiteSpace($IgnoredTypes)) {
    $IgnoredTypes.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        ForEach-Object {
            $ext = $_

            if (-not $ext.StartsWith(".")) {
                $ext = ".$ext"
            }

            $IgnoredTypeSet[$ext.ToLowerInvariant()] = $true
        }
}

# ------------------------------------------------------------
# Scan function
# ------------------------------------------------------------

function Scan-Directory {
    param(
        [string]$Directory,
        [int]$CurrentDepth
    )

    # Record files in current directory
    Get-ChildItem -LiteralPath $Directory -File -Force -ErrorAction SilentlyContinue |
    ForEach-Object {
        $extension = $_.Extension.ToLowerInvariant()
        $typeMatched = $IgnoredTypeSet.ContainsKey($extension)

        if (-not $InvertIgnore) {
            # Normal mode:
            # skip files whose extensions are in IgnoredTypes
            if ($typeMatched) {
                return
            }
        }
        else {
            # Inverted mode:
            # keep ONLY files whose extensions are in IgnoredTypes
            if (-not $typeMatched) {
                return
            }
        }

        if ($TrimUpward) {
            $relativePath = $_.FullName.Substring($ScriptRoot.Length).TrimStart('\', '/')
            $relativePath
        }
        else {
            $_.FullName
        }
    }

    # Stop if depth limit reached
    if ($CurrentDepth -ge $Depth) {
        return
    }

    # Recurse into child directories
    Get-ChildItem -LiteralPath $Directory -Directory -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            $dirName = $_.Name.ToLowerInvariant()

            if ($IgnoredDirSet.ContainsKey($dirName)) {
                return
            }

            Scan-Directory -Directory $_.FullName -CurrentDepth ($CurrentDepth + 1)
        }
}

# ------------------------------------------------------------
# Run scan
# ------------------------------------------------------------

$Results = Scan-Directory -Directory $ScriptRoot -CurrentDepth 0

$Header = @(
    "Directory Scan Output"
    "Root: $ScriptRoot"
    "Depth: $Depth"
    "Ignored Directories: $IgnoredDirectories"
    "Ignored Types: $IgnoredTypes"
    "Trim Upward: $TrimUpward"
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    ""
    "Files:"
    "------"
)

$Header + $Results | Set-Content -LiteralPath $OutputFile -Encoding UTF8

Write-Host "Directory scan complete."
Write-Host "------------------------"
Write-Host $Header + $Results
Write-Host "---------------------------------------------------"
Write-Host "Output written to: $OutputFile"