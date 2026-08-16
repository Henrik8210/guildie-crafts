# Convert PNG to 32-bit TGA (BGRA) for WoW addon textures.
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [int]$Size = 64,
    [int]$CropPercent = 0
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile((Resolve-Path $InputPath))
$bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$cropRatio = [Math]::Max(0, [Math]::Min(40, $CropPercent)) / 100.0
if ($cropRatio -gt 0) {
    $srcW = $src.Width
    $srcH = $src.Height
    $cropX = [int][Math]::Round($srcW * $cropRatio)
    $cropY = [int][Math]::Round($srcH * $cropRatio)
    $cropW = [Math]::Max(1, $srcW - (2 * $cropX))
    $cropH = [Math]::Max(1, $srcH - (2 * $cropY))
    $destRect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
    $graphics.DrawImage($src, $destRect, $cropX, $cropY, $cropW, $cropH, [System.Drawing.GraphicsUnit]::Pixel)
} else {
    $graphics.DrawImage($src, 0, 0, $Size, $Size)
}
$graphics.Dispose()
$src.Dispose()

$rect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $bmp.PixelFormat)
$bytes = New-Object byte[] ($Size * $Size * 4)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data)
$bmp.Dispose()

$fs = [System.IO.File]::Create($OutputPath)
$bw = New-Object System.IO.BinaryWriter $fs

# TGA header (18 bytes), type 2 uncompressed true-color
$bw.Write([byte]0)   # id length
$bw.Write([byte]0)   # color map type
$bw.Write([byte]2)   # image type
$bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0) # color map
$bw.Write([byte]0); $bw.Write([byte]0) # x origin
$bw.Write([byte]0); $bw.Write([byte]0) # y origin
$bw.Write([byte]($Size -band 0xFF)); $bw.Write([byte](($Size -shr 8) -band 0xFF))
$bw.Write([byte]($Size -band 0xFF)); $bw.Write([byte](($Size -shr 8) -band 0xFF))
$bw.Write([byte]32)  # bits per pixel
$bw.Write([byte]0x28) # top-left origin, 8 alpha bits

# BGRA rows top-to-bottom
for ($y = 0; $y -lt $Size; $y++) {
    $row = $y * $Size * 4
    for ($x = 0; $x -lt $Size; $x++) {
        $i = $row + ($x * 4)
        $bw.Write($bytes[$i + 2]) # B
        $bw.Write($bytes[$i + 1]) # G
        $bw.Write($bytes[$i])     # R
        $bw.Write($bytes[$i + 3]) # A
    }
}

$bw.Close()
Write-Host "Wrote $OutputPath (${Size}x${Size} TGA)"
