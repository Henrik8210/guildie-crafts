# Sync GuildieCraftsTest from GuildieCrafts (same version, test-specific names/prefix).
# Run from repo root: .\scripts\sync-guildiecraftstest.ps1 [-Version 1.0.0]

param(
    [string]$Version = $(if (Test-Path "GuildieCrafts\GuildieCrafts.toc") {
        (Select-String -Path "GuildieCrafts\GuildieCrafts.toc" -Pattern "## Version: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value })
    } else { "?" })
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$src = Join-Path $root "GuildieCrafts"
$dst = Join-Path $root "GuildieCraftsTest"
if (-not (Test-Path $dst)) {
    New-Item -ItemType Directory -Path $dst | Out-Null
}

function Convert-GuildieCraftsToTest([string]$text) {
    # Quoted identifiers first — GuildieCrafts_ runs before Test is appended and would double-replace.
    $text = $text -replace '"GuildieCrafts', '"GuildieCraftsTest'
    $text = $text -replace '\^GuildieCrafts', '^GuildieCraftsTest'
    $text = $text -replace 'GuildieCraftsDB', 'GuildieCraftsTestDB'
    $text = $text -replace 'GuildieCrafts_', 'GuildieCraftsTest_'
    $text = $text -replace 'GuildieCrafts\.', 'GuildieCraftsTest.'
    $text = $text -replace 'GuildieCrafts = GuildieCrafts or \{\}', 'GuildieCraftsTest = GuildieCraftsTest or {}'
    $text = $text -replace 'GuildieCrafts =', 'GuildieCraftsTest ='
    $text = $text -replace 'GUILDIECRAFTS_', 'GUILDIECRAFTSTEST_'
    $text = $text -replace '\|cff00ccffGuildie Crafts\|r', '|cff00ccffGuildieCraftsTest|r'
    $text = $text -replace '\|cffff0000Guildie Crafts', '|cffff0000GuildieCraftsTest'
    $text = $text -replace 'local PREFIX = "GuildieCft"', 'local PREFIX = "GuildieCftT"'
    return $text
}

$luaFiles = @(
    "Core.lua", "Workshops.lua", "CraftsTailoring.lua", "Materials.lua", "Gems.lua", "GearPvp.lua", "Gear.lua", "Rooms.lua", "Stock.lua",
    "Recipes.lua", "Tooltips.lua", "Sync.lua", "UI.lua", "Minimap.lua"
)

foreach ($file in $luaFiles) {
    $sourcePath = Join-Path $src $file
    if (-not (Test-Path $sourcePath)) {
        Write-Warning "Missing $file - skipped"
        continue
    }
    $content = Get-Content -Path $sourcePath -Raw -Encoding UTF8
    $content = Convert-GuildieCraftsToTest $content
    Set-Content -Path (Join-Path $dst $file) -Value $content -Encoding UTF8 -NoNewline
    Write-Host "Synced $file"
}

$artSrc = Join-Path $src "Art"
if (Test-Path $artSrc) {
    Copy-Item -Path $artSrc -Destination (Join-Path $dst "Art") -Recurse -Force
    Write-Host "Synced Art/"
}

# Commands: transform then apply test slash aliases
$commandsSrc = Get-Content -Path (Join-Path $src "Commands.lua") -Raw -Encoding UTF8
$commands = Convert-GuildieCraftsToTest $commandsSrc
$commandLines = $commands -split "`r?`n"
$filtered = @()
foreach ($line in $commandLines) {
    if ($line -match '^SLASH_GUILDIECRAFTSTEST') { continue }
    if ($line -match '^SLASH_GUILDIECRAFTS') { continue }
    if ($line -match 'SlashCmdList\[') {
        $line = 'SlashCmdList["GUILDIECRAFTSTEST"] = function(msg)'
        $filtered += $line
        continue
    }
    $filtered += $line
}
$commandsBody = ($filtered -join "`r`n").TrimStart()
$commands = "SLASH_GUILDIECRAFTSTEST1 = `"/gwtest`"`r`nSLASH_GUILDIECRAFTSTEST2 = `"/gwt`"`r`nSLASH_GUILDIECRAFTSTEST3 = `"/gwtt`"`r`n`r`n" + $commandsBody
Set-Content -Path (Join-Path $dst "Commands.lua") -Value $commands -Encoding UTF8 -NoNewline
Write-Host "Synced Commands.lua"

# Update .toc
$toc = @"
## Interface: 20505, 20506
## Title: GuildieCraftsTest
## Notes: Bisect/debug mirror of Guildie Crafts v$Version. Separate saved vars and sync prefix (GuildieCftT). Disable main GuildieCrafts when testing logout.
## Author: Henrik8210
## Version: $Version
## SavedVariables: GuildieCraftsTestDB

Core.lua
Workshops.lua
CraftsTailoring.lua
Materials.lua
Gems.lua
GearPvp.lua
Gear.lua
Rooms.lua
Stock.lua
Recipes.lua
Tooltips.lua
Sync.lua
UI.lua
Minimap.lua
Commands.lua
"@
Set-Content -Path (Join-Path $dst "GuildieCraftsTest.toc") -Value $toc.TrimEnd() -Encoding UTF8
Write-Host "Updated GuildieCraftsTest.toc to v$Version"

Write-Host "Done. GuildieCraftsTest synced to v$Version"
