# Renders the app icon from Resources\art\icon.svg and icon_small.svg into
# the PNG and ICO files in Resources\art, then rebuilds the Microsoft Store
# icons with uwp_assets.ps1. Run it again whenever the SVGs change:
#
#   powershell -ExecutionPolicy Bypass -File Telegram\build\app_icons.ps1
#
# Microsoft Edge draws every size natively in one headless screenshot, so
# each size gets the browser's own anti-aliasing instead of a downscale.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$art = (Resolve-Path (Join-Path $PSScriptRoot '..\Resources\art')).Path
$edge = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge is needed to render the SVG icons.' }

# Where each size is drawn in the screenshot: the SVG, its size, and its
# position. "nomargin" is the large icon cropped to its tile, for
# logo_256_no_margin.png.
$tiles = @(
    @{ Key = '1024'; Svg = 'icon.svg'; Size = 1024; X = 0; Y = 0 },
    @{ Key = '512'; Svg = 'icon.svg'; Size = 512; X = 1024; Y = 0 },
    @{ Key = '256'; Svg = 'icon.svg'; Size = 256; X = 1536; Y = 0 },
    @{ Key = 'nomargin'; Svg = 'icon.svg'; Size = 256; X = 1792; Y = 0; NoMargin = $true },
    @{ Key = '128'; Svg = 'icon.svg'; Size = 128; X = 1536; Y = 256 },
    @{ Key = '96'; Svg = 'icon.svg'; Size = 96; X = 1664; Y = 256 },
    @{ Key = '64'; Svg = 'icon.svg'; Size = 64; X = 1760; Y = 256 },
    @{ Key = '48'; Svg = 'icon.svg'; Size = 48; X = 1824; Y = 256 },
    @{ Key = '32'; Svg = 'icon_small.svg'; Size = 32; X = 1872; Y = 256 },
    @{ Key = '24'; Svg = 'icon_small.svg'; Size = 24; X = 1904; Y = 256 },
    @{ Key = '16'; Svg = 'icon_small.svg'; Size = 16; X = 1928; Y = 256 }
)

$work = Join-Path ([IO.Path]::GetTempPath()) ('lumigram-icons-' + [Guid]::NewGuid())
New-Item -ItemType Directory $work | Out-Null
try {
    Copy-Item (Join-Path $art 'icon.svg'), (Join-Path $art 'icon_small.svg') $work

    # icon.svg's tile spans 72..952 of 1024, so the no-margin version is
    # drawn 1024 / 880 larger and shifted to put the tile at the edges.
    $html = '<!doctype html><html><head><meta charset="utf-8"><style>' +
        'html,body{margin:0;background:transparent}' +
        'div{position:absolute;overflow:hidden}img{position:absolute;display:block}' +
        '</style></head><body>'
    foreach ($tile in $tiles) {
        if ($tile.NoMargin) {
            $scaled = $tile.Size * 1024 / 880
            $shift = - 72 * $scaled / 1024
            $html += "<div style=`"left:$($tile.X)px;top:$($tile.Y)px;width:$($tile.Size)px;height:$($tile.Size)px`">" +
                "<img src=`"$($tile.Svg)`" style=`"left:${shift}px;top:${shift}px;width:${scaled}px;height:${scaled}px`"></div>"
        } else {
            $html += "<div style=`"left:$($tile.X)px;top:$($tile.Y)px;width:$($tile.Size)px;height:$($tile.Size)px`">" +
                "<img src=`"$($tile.Svg)`" style=`"left:0;top:0;width:$($tile.Size)px;height:$($tile.Size)px`"></div>"
        }
    }
    $html += '</body></html>'
    Set-Content (Join-Path $work 'icons.html') $html -Encoding utf8

    $shot = Join-Path $work 'icons.png'
    $page = 'file:///' + ((Join-Path $work 'icons.html') -replace '\\', '/')
    $process = Start-Process -FilePath $edge -PassThru -Wait -WindowStyle Hidden -ArgumentList @(
        '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--force-device-scale-factor=1', '--window-size=2048,1024',
        '--default-background-color=00000000',
        "--user-data-dir=$work\profile", "--screenshot=$shot", $page)
    if (-not (Test-Path $shot)) { throw "Edge didn't render the icons (exit code $($process.ExitCode))." }

    # Crops each size out of the screenshot.
    $sheet = [Drawing.Bitmap]::FromFile($shot)
    $png = @{}
    try {
        foreach ($tile in $tiles) {
            $rect = New-Object Drawing.Rectangle $tile.X, $tile.Y, $tile.Size, $tile.Size
            $bitmap = $sheet.Clone($rect, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $stream = New-Object IO.MemoryStream
            $bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
            $bitmap.Dispose()
            $png[$tile.Key] = $stream.ToArray()
        }
    } finally {
        $sheet.Dispose()
    }

    $files = [ordered]@{
        'icon16.png' = '16'; 'icon16@2x.png' = '32'
        'icon32.png' = '32'; 'icon32@2x.png' = '64'
        'icon48.png' = '48'; 'icon48@2x.png' = '96'
        'icon64.png' = '64'; 'icon64@2x.png' = '128'
        'icon128.png' = '128'; 'icon128@2x.png' = '256'
        'icon256.png' = '256'; 'icon256@2x.png' = '512'
        'icon512.png' = '512'; 'icon512@2x.png' = '1024'
        'icon_round512@2x.png' = '1024'
        'logo_256.png' = '256'; 'logo_256_no_margin.png' = 'nomargin'
    }
    foreach ($name in $files.Keys) {
        [IO.File]::WriteAllBytes((Join-Path $art $name), $png[$files[$name]])
    }

    # icon256.ico, the exe and installer icon: PNG images at 16 to 256 px.
    $sizes = 16, 24, 32, 48, 64, 128, 256
    $ico = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter $ico
    $writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    foreach ($size in $sizes) {
        $data = $png["$size"]
        $writer.Write([Byte]($size % 256)); $writer.Write([Byte]($size % 256))
        $writer.Write([Byte]0); $writer.Write([Byte]0)
        $writer.Write([UInt16]1); $writer.Write([UInt16]32)
        $writer.Write([UInt32]$data.Length); $writer.Write([UInt32]$offset)
        $offset += $data.Length
    }
    foreach ($size in $sizes) { $writer.Write($png["$size"]) }
    $writer.Flush()
    [IO.File]::WriteAllBytes((Join-Path $art 'icon256.ico'), $ico.ToArray())
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "App icons rendered in $art"
& (Join-Path $PSScriptRoot 'uwp_assets.ps1')
