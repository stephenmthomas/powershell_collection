param(
    # DWM color format: 0xAABBGGRR
    [int]$BorderColor = 0x0032302A,

    # DWM color format: 0xAABBGGRR
    [int]$CaptionColor = 0x0025221F,

    # DWM color format: 0xAABBGGRR
    [int]$TextColor = 0x00FFFFFF,

    [ValidateSet("Enable", "Disable")]
    [string]$DarkMode = "Enable",

    [ValidateSet("Default", "None", "Round", "SmallRound")]
    [string]$Corners = "Round",

    [ValidateSet("Auto", "None", "Mica", "Acrylic", "MicaAlt")]
    [string]$Backdrop = "None",

    [switch]$IncludeUntitled,
    [switch]$DryRun
)

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class NativeWindowTools
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(
        IntPtr hwnd,
        int dwAttribute,
        ref int pvAttribute,
        int cbAttribute
    );
}
"@

# DWM attributes
$DWMWA_USE_IMMERSIVE_DARK_MODE  = 20
$DWMWA_WINDOW_CORNER_PREFERENCE = 33
$DWMWA_BORDER_COLOR             = 34
$DWMWA_CAPTION_COLOR            = 35
$DWMWA_TEXT_COLOR               = 36
$DWMWA_SYSTEMBACKDROP_TYPE      = 38

# DWM_WINDOW_CORNER_PREFERENCE
# 0 = default
# 1 = no rounding
# 2 = round
# 3 = small round
$cornerValue = switch ($Corners) {
    "Default"    { 0 }
    "None"       { 1 }
    "Round"      { 2 }
    "SmallRound" { 3 }
}

# DWM_SYSTEMBACKDROP_TYPE
# 0 = auto
# 1 = none
# 2 = mica
# 3 = acrylic
# 4 = mica alt
$backdropValue = switch ($Backdrop) {
    "Auto"    { 0 }
    "None"    { 1 }
    "Mica"    { 2 }
    "Acrylic" { 3 }
    "MicaAlt" { 4 }
}

$darkModeValue = switch ($DarkMode) {
    "Enable"  { 1 }
    "Disable" { 0 }
}

function Get-WindowTitle {
    param([IntPtr]$Hwnd)

    $length = [NativeWindowTools]::GetWindowTextLength($Hwnd)

    if ($length -le 0) {
        return ""
    }

    $builder = New-Object System.Text.StringBuilder ($length + 1)
    [void][NativeWindowTools]::GetWindowText($Hwnd, $builder, $builder.Capacity)

    return $builder.ToString()
}

function Set-DwmIntAttribute {
    param(
        [IntPtr]$Hwnd,
        [int]$Attribute,
        [int]$Value
    )

    $v = $Value

    return [NativeWindowTools]::DwmSetWindowAttribute(
        $Hwnd,
        $Attribute,
        [ref]$v,
        [System.Runtime.InteropServices.Marshal]::SizeOf([type][int])
    )
}

function Set-DwmSettings {
    param(
        [IntPtr]$Hwnd,
        [string]$Title
    )

    if ($DryRun) {
        Write-Host "[DRY RUN] Would update HWND=$Hwnd Title=`"$Title`""
        return
    }

    $results = @{}

    $results.DarkMode = Set-DwmIntAttribute `
        -Hwnd $Hwnd `
        -Attribute $DWMWA_USE_IMMERSIVE_DARK_MODE `
        -Value $darkModeValue

    $results.BorderColor = Set-DwmIntAttribute `
        -Hwnd $Hwnd `
        -Attribute $DWMWA_BORDER_COLOR `
        -Value $BorderColor

    $results.CaptionColor = Set-DwmIntAttribute `
        -Hwnd $Hwnd `
        -Attribute $DWMWA_CAPTION_COLOR `
        -Value $CaptionColor

    $results.TextColor = Set-DwmIntAttribute `
        -Hwnd $Hwnd `
        -Attribute $DWMWA_TEXT_COLOR `
        -Value $TextColor

    $results.Corners = Set-DwmIntAttribute `
        -Hwnd $Hwnd `
        -Attribute $DWMWA_WINDOW_CORNER_PREFERENCE `
        -Value $cornerValue

    $results.Backdrop = Set-DwmIntAttribute `
        -Hwnd $Hwnd `
        -Attribute $DWMWA_SYSTEMBACKDROP_TYPE `
        -Value $backdropValue

    Write-Host "Updated HWND=$Hwnd Title=`"$Title`""
    Write-Host "  DarkMode:      $($results.DarkMode)"
    Write-Host "  BorderColor:   $($results.BorderColor)"
    Write-Host "  CaptionColor:  $($results.CaptionColor)"
    Write-Host "  TextColor:     $($results.TextColor)"
    Write-Host "  Corners:       $($results.Corners)"
    Write-Host "  Backdrop:      $($results.Backdrop)"
}

$windows = New-Object System.Collections.Generic.List[object]

# Keep callback in a variable so it does not get garbage collected.
$callback = [NativeWindowTools+EnumWindowsProc]{
    param([IntPtr]$hWnd, [IntPtr]$lParam)

    if (-not [NativeWindowTools]::IsWindowVisible($hWnd)) {
        return $true
    }

    $title = Get-WindowTitle -Hwnd $hWnd

    if (-not $IncludeUntitled -and [string]::IsNullOrWhiteSpace($title)) {
        return $true
    }

    [uint32]$pid = 0
    [void][NativeWindowTools]::GetWindowThreadProcessId($hWnd, [ref]$pid)

    $windows.Add([pscustomobject]@{
        Hwnd  = $hWnd
        PID   = $pid
        Title = $title
    })

    return $true
}

[void][NativeWindowTools]::EnumWindows($callback, [IntPtr]::Zero)

Write-Host ""
Write-Host "Found $($windows.Count) visible top-level windows."
Write-Host ""

foreach ($window in $windows) {
    Set-DwmSettings -Hwnd $window.Hwnd -Title $window.Title
}

Write-Host ""
Write-Host "Done."