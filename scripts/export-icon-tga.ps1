# Build in-game icon TGAs from Art/GuildieCrafts-Icon.png
# Crops out the baked-in square frame and applies a circular mask for the portrait slot.
# Run from repo root: .\scripts\export-icon-tga.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$pngPath = Join-Path $root "Art\GuildieCrafts-Icon.png"
$artDir = Join-Path $root "GuildieCrafts\Art"

if (-not (Test-Path $pngPath)) {
    Write-Error "Missing $pngPath"
}
if (-not (Test-Path $artDir)) {
    New-Item -ItemType Directory -Path $artDir | Out-Null
}

$script = Join-Path $root "scripts\png-to-tga.ps1"
$crop = 17

& $script -InputPath $pngPath -OutputPath (Join-Path $artDir "WorkshopLogoPortrait.tga") -Size 64 -CropPercent $crop -CircularMask
& $script -InputPath $pngPath -OutputPath (Join-Path $artDir "WorkshopLogo.tga") -Size 256 -CropPercent $crop -CircularMask

Write-Host "Done. Portrait and minimap icons rebuilt from GuildieCrafts-Icon.png (crop ${crop}%)."
