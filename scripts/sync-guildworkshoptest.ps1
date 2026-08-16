# Sync GuildWorkshopTest from GuildWorkshop (same version, test-specific names/prefix).
# Run from repo root: .\scripts\sync-guildworkshoptest.ps1 [-Version 1.0.0]

param(
    [string]$Version = $(if (Test-Path "GuildWorkshop\GuildWorkshop.toc") {
        (Select-String -Path "GuildWorkshop\GuildWorkshop.toc" -Pattern "## Version: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value })
    } else { "?" })
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$src = Join-Path $root "GuildWorkshop"
$dst = Join-Path $root "GuildWorkshopTest"

function Convert-GuildWorkshopToTest([string]$text) {
    # Quoted identifiers first — GuildWorkshop_ runs before Test is appended and would double-replace.
    $text = $text -replace '"GuildWorkshop', '"GuildWorkshopTest'
    $text = $text -replace '\^GuildWorkshop', '^GuildWorkshopTest'
    $text = $text -replace 'GuildWorkshopDB', 'GuildWorkshopTestDB'
    $text = $text -replace 'GuildWorkshop_', 'GuildWorkshopTest_'
    $text = $text -replace 'GuildWorkshop\.', 'GuildWorkshopTest.'
    $text = $text -replace 'GuildWorkshop = GuildWorkshop or \{\}', 'GuildWorkshopTest = GuildWorkshopTest or {}'
    $text = $text -replace 'GuildWorkshop =', 'GuildWorkshopTest ='
    $text = $text -replace 'GUILDWORKSHOP_', 'GUILDWORKSHOPTEST_'
    $text = $text -replace '\|cff00ccffGuild Workshop\|r', '|cff00ccffGuildWorkshopTest|r'
    $text = $text -replace '\|cffff0000Guild Workshop', '|cffff0000GuildWorkshopTest'
    $text = $text -replace 'local PREFIX = "GuildWrk"', 'local PREFIX = "GuildWrkT"'
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
    $content = Convert-GuildWorkshopToTest $content
    Set-Content -Path (Join-Path $dst $file) -Value $content -Encoding UTF8 -NoNewline
    Write-Host "Synced $file"
}

# Commands: transform then apply test slash aliases
$commandsSrc = Get-Content -Path (Join-Path $src "Commands.lua") -Raw -Encoding UTF8
$commands = Convert-GuildWorkshopToTest $commandsSrc
$commandLines = $commands -split "`r?`n"
$filtered = @()
foreach ($line in $commandLines) {
    if ($line -match '^SLASH_GUILDWORKSHOPTEST') { continue }
    if ($line -match '^SLASH_GUILDWORKSHOP') { continue }
    if ($line -match 'SlashCmdList\[') {
        $line = 'SlashCmdList["GUILDWORKSHOPTEST"] = function(msg)'
        $filtered += $line
        continue
    }
    $filtered += $line
}
$commandsBody = ($filtered -join "`r`n").TrimStart()
$commands = "SLASH_GUILDWORKSHOPTEST1 = `"/gwtest`"`r`nSLASH_GUILDWORKSHOPTEST2 = `"/gwt`"`r`nSLASH_GUILDWORKSHOPTEST3 = `"/gwtt`"`r`n`r`n" + $commandsBody
Set-Content -Path (Join-Path $dst "Commands.lua") -Value $commands -Encoding UTF8 -NoNewline
Write-Host "Synced Commands.lua"

# Update .toc
$toc = @"
## Interface: 20505, 20506
## Title: GuildWorkshopTest
## Notes: Bisect/debug mirror of Guild Workshop v$Version. Separate saved vars and sync prefix (GuildWrkT). Disable main GuildWorkshop when testing logout.
## Author: Henrik8210
## Version: $Version
## SavedVariables: GuildWorkshopTestDB

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
Set-Content -Path (Join-Path $dst "GuildWorkshopTest.toc") -Value $toc.TrimEnd() -Encoding UTF8
Write-Host "Updated GuildWorkshopTest.toc to v$Version"

Write-Host "Done. GuildWorkshopTest synced to v$Version"
