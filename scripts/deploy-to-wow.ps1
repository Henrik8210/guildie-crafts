# Deploy GuildWorkshop and GuildWorkshopTest to the WoW AddOns folder.
# Copies *contents* into each addon folder (avoids nested GuildWorkshop/GuildWorkshop/).
# Run from repo root: .\scripts\deploy-to-wow.ps1

param(
    [string]$WowAddOns = "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Deploy-AddonFolder {
    param(
        [string]$SourceName,
        [string]$TargetName
    )
    $src = Join-Path $root $SourceName
    $dst = Join-Path $WowAddOns $TargetName
    if (-not (Test-Path $src)) {
        Write-Warning "Missing source folder $SourceName - skipped"
        return
    }
    if (-not (Test-Path $dst)) {
        New-Item -ItemType Directory -Path $dst | Out-Null
    }
    Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
    # Remove accidental nested copy from older deploys
    $nested = Join-Path $dst $SourceName
    if (Test-Path $nested) {
        Remove-Item -Path $nested -Recurse -Force
        Write-Host "Removed stale nested folder $TargetName\$SourceName"
    }
    $toc = Get-ChildItem -Path $dst -Filter "*.toc" | Select-Object -First 1
    $version = if ($toc) {
        (Select-String -Path $toc.FullName -Pattern "## Version: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value })
    } else { "?" }
    Write-Host "Deployed $TargetName (v$version) -> $dst"
}

Deploy-AddonFolder -SourceName "GuildWorkshop" -TargetName "GuildWorkshop"
Deploy-AddonFolder -SourceName "GuildWorkshopTest" -TargetName "GuildWorkshopTest"
Write-Host "Done. /reload in game."
