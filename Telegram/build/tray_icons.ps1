# Writes the monochrome tray icons in Resources\icons: the bubble from
# Resources\art\icon.svg drawn as a plain ring. Run it again whenever the
# bubble changes:
#
#   powershell -ExecutionPolicy Bypass -File Telegram\build\tray_icons.ps1
#
# The ring is saved as a filled outline, not a stroke, because Linux
# recolors symbolic icons by their fill.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$icons = (Resolve-Path (Join-Path $PSScriptRoot '..\Resources\icons')).Path

# The bubble from icon.svg, enlarged to fill the tray icon.
$strokeWidth = 96
$scale = 1.26

function P([double] $x, [double] $y) { New-Object Drawing.PointF $x, $y }
$path = New-Object Drawing.Drawing2D.GraphicsPath
$path.StartFigure()
$path.AddBezier((P 512 196), (P 700 196), (P 836 322), (P 836 488))
$path.AddBezier((P 836 488), (P 836 654), (P 700 780), (P 512 780))
$path.AddBezier((P 512 780), (P 470 780), (P 431 774), (P 395 762))
$path.AddLine((P 395 762), (P 262 826))
$path.AddBezier((P 262 826), (P 246 834), (P 228 819), (P 234 802))
$path.AddLine((P 234 802), (P 266 702))
$path.AddBezier((P 266 702), (P 219 652), (P 188 574), (P 188 488))
$path.AddBezier((P 188 488), (P 188 322), (P 324 196), (P 512 196))
$path.CloseFigure()

$matrix = New-Object Drawing.Drawing2D.Matrix
$matrix.Translate(512, 512)
$matrix.Scale($scale, $scale)
$matrix.Translate(-512, -512)
$path.Transform($matrix)

$pen = New-Object Drawing.Pen ([Drawing.Color]::White), ($strokeWidth * $scale)
$pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
$path.Widen($pen, $null, 0.6)

$culture = [Globalization.CultureInfo]::InvariantCulture
$points = $path.PathPoints
$types = $path.PathTypes
$data = New-Object Text.StringBuilder
for ($i = 0; $i -lt $points.Length; $i++) {
    $x = [Math]::Round($points[$i].X, 1).ToString($culture)
    $y = [Math]::Round($points[$i].Y, 1).ToString($culture)
    [void]$data.Append($(if (($types[$i] -band 7) -eq 0) { 'M' } else { 'L' }) + "$x $y")
    if ($types[$i] -band 0x80) { [void]$data.Append('Z') }
}
$pen.Dispose()
$path.Dispose()

# The dot matches the one tray_win.cpp draws: cx 3.9, cy 12.7, r 2.2 of 16.
$dot = 'cx="249.6" cy="812.8" r="140.8"'
$variants = [ordered]@{
    'tray_monochrome.svg' = ''
    'tray_monochrome_attention.svg' = "<circle class=`"error`" fill=`"#f23c34`" $dot/>"
    'tray_monochrome_mute.svg' = "<circle fill=`"#888888`" $dot/>"
}
foreach ($name in $variants.Keys) {
    $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 1024 1024">' + "`n" +
        '  <!-- Written by Telegram/build/tray_icons.ps1. -->' + "`n" +
        "  <path fill=`"#FFFFFF`" d=`"$data`"/>`n"
    if ($variants[$name]) { $svg += "  $($variants[$name])`n" }
    $svg += "</svg>`n"
    [IO.File]::WriteAllText((Join-Path $icons $name), $svg)
}

Write-Host "Tray icons written in $icons"
