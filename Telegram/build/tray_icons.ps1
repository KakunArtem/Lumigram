# Writes the monochrome tray icons in Resources\icons: the app icon in
# miniature, a squircle outline with a solid L inside. Run it again
# whenever the tray glyph changes:
#
#   powershell -ExecutionPolicy Bypass -File Telegram\build\tray_icons.ps1
#
# The glyph is drawn on the 16 px grid (64 units = 1 px at 16 px), so the
# L's straight edges land on pixel lines. It's saved as a filled outline,
# not a stroke, because Linux recolors symbolic icons by their fill.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$icons = (Resolve-Path (Join-Path $PSScriptRoot '..\Resources\icons')).Path

function P([double] $x, [double] $y) { New-Object Drawing.PointF $x, $y }

# The tile: a squircle (superellipse, exponent 3) with a 1.5 px outline,
# 6.95 px from the centre to the middle of the line.
$squircle = for ($i = 0; $i -lt 360; $i++) {
    $t = $i * [Math]::PI / 180
    $c = [Math]::Cos($t); $s = [Math]::Sin($t)
    P (512 + 444.8 * [Math]::Sign($c) * [Math]::Pow([Math]::Abs($c), 2 / 3)) `
      (512 + 444.8 * [Math]::Sign($s) * [Math]::Pow([Math]::Abs($s), 2 / 3))
}
$strokeWidth = 96

# The unread dot, top right, where the L leaves the tile empty. It matches
# the one tray_win.cpp draws: cx 12.1, cy 3.9, r 2.2 of 16. The glyph keeps
# 3.125 px clear of its centre so the dot doesn't merge with the outline.
$dotX = 774.4; $dotY = 249.6; $gap = 200

# The L, with the app icon's proportions: a 2.5 px column and foot, round
# ends, a soft outer corner and a tight inner one.
function New-L {
    $l = New-Object Drawing.Drawing2D.GraphicsPath
    $l.StartFigure()
    $l.AddArc(336, 256, 160, 160, 180, 180)           # top of the column
    $l.AddLine(496, 336, 496, 588.8)
    $l.AddArc(496, 569.6, 38.4, 38.4, 180, -90)       # inner corner
    $l.AddLine(515.2, 608, 688, 608)
    $l.AddArc(608, 608, 160, 160, 270, 180)           # end of the foot
    $l.AddLine(688, 768, 406.4, 768)
    $l.AddArc(336, 627.2, 140.8, 140.8, 90, 90)       # outer corner
    $l.CloseFigure()
    $l.Flatten($null, 0.25)
    $l
}

# Builds the glyph. With $cut, the tile outline stops short of the dot.
function New-Glyph([bool] $cut) {
    $tile = New-Object Drawing.Drawing2D.GraphicsPath
    $pen = New-Object Drawing.Pen ([Drawing.Color]::White), $strokeWidth
    $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
    if ($cut) {
        # Keep the points far enough from the dot that the round line caps
        # still leave the gap, starting just after it.
        $keep = $squircle | ForEach-Object {
            [Math]::Sqrt(($_.X - $dotX) * ($_.X - $dotX) + ($_.Y - $dotY) * ($_.Y - $dotY)) -gt ($gap + $strokeWidth / 2)
        }
        $start = 0
        for ($i = 0; $i -lt 360; $i++) {
            if ($keep[$i] -and -not $keep[($i + 359) % 360]) { $start = $i; break }
        }
        $open = for ($k = 0; $k -lt 360; $k++) {
            $i = ($start + $k) % 360
            if ($keep[$i]) { $squircle[$i] } else { break }
        }
        $tile.AddLines([Drawing.PointF[]]$open)
        $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
    } else {
        $tile.StartFigure()
        $tile.AddLines([Drawing.PointF[]]$squircle)
        $tile.CloseFigure()
    }
    $tile.Widen($pen, $null, 0.6)
    $pen.Dispose()

    $glyph = New-Object Drawing.Drawing2D.GraphicsPath
    $glyph.AddPath($tile, $false)
    $l = New-L
    $glyph.AddPath($l, $false)
    $tile.Dispose(); $l.Dispose()

    $culture = [Globalization.CultureInfo]::InvariantCulture
    $points = $glyph.PathPoints
    $types = $glyph.PathTypes
    $data = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $points.Length; $i++) {
        $x = [Math]::Round($points[$i].X, 1).ToString($culture)
        $y = [Math]::Round($points[$i].Y, 1).ToString($culture)
        [void]$data.Append($(if (($types[$i] -band 7) -eq 0) { 'M' } else { 'L' }) + "$x $y")
        if ($types[$i] -band 0x80) { [void]$data.Append('Z') }
    }
    $glyph.Dispose()
    $data.ToString()
}

$whole = New-Glyph $false
$cut = New-Glyph $true
$dot = "cx=`"$dotX`" cy=`"$dotY`" r=`"140.8`""
$variants = [ordered]@{
    'tray_monochrome.svg' = @($whole, '')
    'tray_monochrome_attention.svg' = @($cut, "<circle class=`"error`" fill=`"#f23c34`" $dot/>")
    'tray_monochrome_mute.svg' = @($cut, "<circle fill=`"#888888`" $dot/>")
}
foreach ($name in $variants.Keys) {
    $data, $circle = $variants[$name]
    $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 1024 1024">' + "`n" +
        '  <!-- Written by Telegram/build/tray_icons.ps1. -->' + "`n" +
        "  <path fill=`"#FFFFFF`" d=`"$data`"/>`n"
    if ($circle) { $svg += "  $circle`n" }
    $svg += "</svg>`n"
    [IO.File]::WriteAllText((Join-Path $icons $name), $svg)
}

Write-Host "Tray icons written in $icons"
