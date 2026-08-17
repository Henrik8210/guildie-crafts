# Convert PNG to 32-bit TGA (BGRA) for WoW addon textures.
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [int]$Size = 64,
    [int]$CropPercent = 0,
    [switch]$CircularMask
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile((Resolve-Path $InputPath))
$bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$cropRatio = [Math]::Max(0, [Math]::Min(45, $CropPercent)) / 100.0
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

if ($CircularMask) {
    $center = ($Size - 1) / 2.0
    $radius = $Size / 2.0
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $dx = $x - $center
            $dy = $y - $center
            if (($dx * $dx + $dy * $dy) -gt ($radius * $radius)) {
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
            }
        }
    }
}

$rect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $bmp.PixelFormat)
$bytes = New-Object byte[] ($Size * $Size * 4)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data)
$bmp.Dispose()

$fs = [System.IO.File]::Create($OutputPath)
$bw = New-Object System.IO.BinaryWriter $fs

# TGA header (18 bytes), type 2 uncompressed true-color
$bw.Write([byte]0)
$bw.Write([byte]0)
$bw.Write([byte]2)
$bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)
$bw.Write([byte]0); $bw.Write([byte]0)
$bw.Write([byte]0); $bw.Write([byte]0)
$bw.Write([byte]($Size -band 0xFF)); $bw.Write([byte](($Size -shr 8) -band 0xFF))
$bw.Write([byte]($Size -band 0xFF)); $bw.Write([byte](($Size -shr 8) -band 0xFF))
$bw.Write([byte]32)
$bw.Write([byte]0x28)

for ($y = 0; $y -lt $Size; $y++) {
    $row = $y * $Size * 4
    for ($x = 0; $x -lt $Size; $x++) {
        $i = $row + ($x * 4)
        # GDI+ LockBits are BGRA; TGA pixel order is also BGRA.
        $bw.Write($bytes[$i])
        $bw.Write($bytes[$i + 1])
        $bw.Write($bytes[$i + 2])
        $bw.Write($bytes[$i + 3])
    }
}

$bw.Close()
Write-Host "Wrote $OutputPath (${Size}x${Size} TGA, crop ${CropPercent}%, circular=$CircularMask)"
