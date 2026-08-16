# Export Guildie Crafts logo TGA to PNG for CurseForge / web upload.
# Run from repo root: .\scripts\export-logo-png.ps1

param(
    [int]$Size = 256,
    [ValidateSet("WorkshopLogo", "WorkshopLogoPortrait")]
    [string]$Source = "WorkshopLogo"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tgaPath = Join-Path $root "GuildieCrafts\Art\$Source.tga"
$outDir = Join-Path $root "Art"
$pngPath = Join-Path $outDir "GuildieCrafts-Logo.png"

if (-not (Test-Path $tgaPath)) {
    Write-Error "Missing $tgaPath"
}

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

Add-Type -AssemblyName System.Drawing

$fs = [System.IO.File]::OpenRead($tgaPath)
$br = New-Object System.IO.BinaryReader $fs
$null = $br.ReadBytes(12)
$w = $br.ReadInt16()
$h = $br.ReadInt16()
$bpp = $br.ReadByte()
$null = $br.ReadByte()
$bytes = $br.ReadBytes($w * $h * 4)
$br.Close()
$fs.Close()

$src = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$data = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $src.PixelFormat)

for ($y = 0; $y -lt $h; $y++) {
    $row = ($h - 1 - $y) * $w * 4
    for ($x = 0; $x -lt $w; $x++) {
        $i = $row + ($x * 4)
        $offset = ($y * $w + $x) * 4
        [System.Runtime.InteropServices.Marshal]::WriteByte($data.Scan0, $offset, $bytes[$i])
        [System.Runtime.InteropServices.Marshal]::WriteByte($data.Scan0, $offset + 1, $bytes[$i + 1])
        [System.Runtime.InteropServices.Marshal]::WriteByte($data.Scan0, $offset + 2, $bytes[$i + 2])
        [System.Runtime.InteropServices.Marshal]::WriteByte($data.Scan0, $offset + 3, $bytes[$i + 3])
    }
}

$src.UnlockBits($data)

$out = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.DrawImage($src, 0, 0, $Size, $Size)
$g.Dispose()
$src.Dispose()

$out.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()

Write-Host "Exported $pngPath (${Size}x${Size} PNG from $Source.tga)"
