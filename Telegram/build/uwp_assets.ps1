# Rebuilds the Microsoft Store package icons in Resources\uwp\AppX\Assets
# from the app icon in Resources\art. Run it again whenever the app icon
# changes:
#
#   powershell -ExecutionPolicy Bypass -File Telegram\build\uwp_assets.ps1
#
# Each icon is scaled down from the smallest art icon at least as large as
# it, so the small sizes keep their hand-tuned versions.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$resources = Join-Path $PSScriptRoot '..\Resources'
$art = Join-Path $resources 'art'
$assets = Join-Path $resources 'uwp\AppX\Assets'

$sources = @(16, 32, 48, 64, 128, 256, 512) | ForEach-Object {
    @{ Size = $_; Path = Join-Path $art "icon$_.png" }
}
$sources += @{ Size = 1024; Path = Join-Path $art 'icon512@2x.png' }

# Draws the app icon at $iconSize pixels in the middle of a transparent
# $canvasSize square and saves it as a PNG.
function Save-Icon([int] $canvasSize, [int] $iconSize, [string] $path) {
    $source = ($sources | Where-Object { $_.Size -ge $iconSize } | Select-Object -First 1)
    if (-not $source) { $source = $sources[-1] }
    $image = [Drawing.Image]::FromFile((Resolve-Path $source.Path))
    $bitmap = New-Object Drawing.Bitmap $canvasSize, $canvasSize, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.CompositingQuality = 'HighQuality'
        $graphics.InterpolationMode = 'HighQualityBicubic'
        $graphics.PixelOffsetMode = 'HighQuality'
        $graphics.SmoothingMode = 'HighQuality'
        $offset = [int][Math]::Floor(($canvasSize - $iconSize) / 2)
        $attributes = New-Object Drawing.Imaging.ImageAttributes
        $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $graphics.DrawImage(
            $image,
            (New-Object Drawing.Rectangle $offset, $offset, $iconSize, $iconSize),
            0, 0, $image.Width, $image.Height,
            [Drawing.GraphicsUnit]::Pixel,
            $attributes)
        New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
        $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        $image.Dispose()
    }
}

$scales = 100, 125, 150, 200, 400

foreach ($scale in $scales) {
    # Store logo, 50 x 50 at 100%.
    $size = [int][Math]::Round(50 * $scale / 100)
    Save-Icon $size $size (Join-Path $assets "logo\logo.scale-$scale.png")

    # Start menu tile, 150 x 150 at 100%, with the icon at two thirds of it.
    $size = [int][Math]::Round(150 * $scale / 100)
    Save-Icon $size ([int][Math]::Round($size * 2 / 3)) (Join-Path $assets "logo150\logo150.scale-$scale.png")

    # App list icon, 44 x 44 at 100%.
    $size = [int][Math]::Round(44 * $scale / 100)
    Save-Icon $size $size (Join-Path $assets "logo44\logo44.scale-$scale.png")
}

# Taskbar, title bar and file list icons, with and without the tile plate.
foreach ($size in 16, 20, 24, 30, 32, 36, 40, 48, 60, 64, 72, 80, 96, 256) {
    Save-Icon $size $size (Join-Path $assets "logo44\logo44.targetsize-$size.png")
    Save-Icon $size $size (Join-Path $assets "logo44\logo44.targetsize-${size}_altform-unplated.png")
}

Write-Host "Store icons rebuilt in $assets"
