# Validates HoD profession craft categories: structural integrity + expected gear roles.
# Run from repo root: powershell -ExecutionPolicy Bypass -File scripts/check-craft-categories.ps1

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

# Expected category per itemId (TBC Phase 3 Heart of Darkness crafts).
$expectedByItemId = @{
    # Tailoring
    32420 = "Shadow Resist"   # Night's End
    32392 = "Shadow Resist"   # Soulguard Bracers
    32390 = "Shadow Resist"   # Soulguard Girdle
    32389 = "Shadow Resist"   # Soulguard Leggings
    32391 = "Shadow Resist"   # Soulguard Slippers
    32584 = "Healer"          # Swiftheal Wraps
    32585 = "Healer"          # Swiftheal Mantle
    32586 = "Caster"          # Bracers of Nimble Thought
    32587 = "Caster"          # Mantle of Nimble Thought

    # Leatherworking
    32574 = "Physical DPS"    # Bindings of Lightning Reflexes
    32575 = "Physical DPS"    # Shoulders of Lightning Reflexes
    32580 = "Physical DPS"    # Swiftstrike Bracers
    32581 = "Physical DPS"    # Swiftstrike Shoulders
    32577 = "Healer"          # Living Earth Bindings
    32579 = "Healer"          # Living Earth Shoulders
    32582 = "Healer"          # Bracers of Renewed Life
    32583 = "Healer"          # Shoulderpads of Renewed Life
    32399 = "Shadow Resist"   # Bracers of Shackled Souls
    32397 = "Shadow Resist"   # Waistguard of Shackled Souls
    32400 = "Shadow Resist"   # Greaves of Shackled Souls
    32398 = "Shadow Resist"   # Boots of Shackled Souls
    32395 = "Shadow Resist"   # Redeemed Soul Wristguards
    32393 = "Shadow Resist"   # Redeemed Soul Cinch
    32396 = "Shadow Resist"   # Redeemed Soul Legguards
    32394 = "Shadow Resist"   # Redeemed Soul Moccasins

    # Blacksmithing
    32571 = "Healer"          # Dawnsteel Bracers
    32573 = "Healer"          # Dawnsteel Shoulders
    32568 = "Physical DPS"    # Swiftsteel Bracers
    32570 = "Physical DPS"    # Swiftsteel Shoulders
    32403 = "Shadow Resist"   # Shadesteel Bracers
    32401 = "Shadow Resist"   # Shadesteel Girdle
    32404 = "Shadow Resist"   # Shadesteel Greaves
    32402 = "Shadow Resist"   # Shadesteel Sabots
}

$professions = @(
    @{
        Id = "tailoring"
        CraftsFile = "GuildieCrafts\CraftsTailoring.lua"
        CraftsTable = "GuildieCrafts_TailoringCrafts"
        CategoriesTable = "GuildieCrafts_TailoringCraftCategories"
        ExpectedCategories = @("Shadow Resist", "Healer", "Caster")
    },
    @{
        Id = "leatherworking"
        CraftsFile = "GuildieCrafts\CraftsLeatherworking.lua"
        CraftsTable = "GuildieCrafts_LeatherworkingCrafts"
        CategoriesTable = "GuildieCrafts_LeatherworkingCraftCategories"
        ExpectedCategories = @("Physical DPS", "Healer", "Shadow Resist")
    },
    @{
        Id = "blacksmithing"
        CraftsFile = "GuildieCrafts\CraftsBlacksmithing.lua"
        CraftsTable = "GuildieCrafts_BlacksmithingCrafts"
        CategoriesTable = "GuildieCrafts_BlacksmithingCraftCategories"
        ExpectedCategories = @("Physical DPS", "Healer", "Shadow Resist")
    }
)

function Parse-LuaStringList {
    param([string]$Block)
    [regex]::Matches($Block, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
}

function Parse-CraftEntries {
    param([string]$Content)
    $crafts = @()
    foreach ($match in [regex]::Matches($Content, '\{\s*name\s*=\s*"([^"]+)"[\s\S]*?itemId\s*=\s*(\d+)[\s\S]*?category\s*=\s*"([^"]+)"')) {
        $crafts += [pscustomobject]@{
            Name = $match.Groups[1].Value
            ItemId = [int]$match.Groups[2].Value
            Category = $match.Groups[3].Value
        }
    }
    return $crafts
}

$failures = 0
$warnings = 0

Write-Host ""
Write-Host "Guildie Crafts - HoD craft category health check" -ForegroundColor Cyan
Write-Host ("=" * 60)

foreach ($prof in $professions) {
    $path = Join-Path $repoRoot $prof.CraftsFile
    $content = Get-Content -Raw -Path $path

    Write-Host ""
    Write-Host ("[{0}]" -f $prof.Id.ToUpper()) -ForegroundColor Yellow

    # Parse declared categories
    $catPattern = [regex]::Escape($prof.CategoriesTable) + '\s*=\s*\{([^}]+)\}'
    $catMatch = [regex]::Match($content, $catPattern)
    if (-not $catMatch.Success) {
        Write-Host "  FAIL: Could not parse $($prof.CategoriesTable)" -ForegroundColor Red
        $failures++
        continue
    }
    $declaredCategories = Parse-LuaStringList $catMatch.Groups[1].Value

    # Parse crafts
    $crafts = Parse-CraftEntries $content
    Write-Host ("  Crafts: {0}" -f $crafts.Count)
    Write-Host ("  Declared categories: {0}" -f ($declaredCategories -join ", "))

    # Check expected category list matches declared
    $missingFromDeclared = $prof.ExpectedCategories | Where-Object { $_ -notin $declaredCategories }
    $extraDeclared = $declaredCategories | Where-Object { $_ -notin $prof.ExpectedCategories }
    foreach ($cat in $missingFromDeclared) {
        Write-Host "  FAIL: Expected category '$cat' missing from $($prof.CategoriesTable)" -ForegroundColor Red
        $failures++
    }
    foreach ($cat in $extraDeclared) {
        Write-Host "  WARN: Unexpected category '$cat' in $($prof.CategoriesTable)" -ForegroundColor DarkYellow
        $warnings++
    }

    # Crafts using undeclared categories
    $usedCategories = $crafts | Select-Object -ExpandProperty Category -Unique
    foreach ($cat in $usedCategories) {
        if ($cat -notin $declaredCategories) {
            Write-Host "  FAIL: Craft uses category '$cat' but it is not in $($prof.CategoriesTable)" -ForegroundColor Red
            $failures++
        }
    }

    # Declared categories with no crafts
    foreach ($cat in $declaredCategories) {
        $count = ($crafts | Where-Object { $_.Category -eq $cat }).Count
        if ($count -eq 0) {
            Write-Host "  WARN: Category '$cat' is declared but has no crafts" -ForegroundColor DarkYellow
            $warnings++
        } else {
            Write-Host ("  OK:   {0} ({1} crafts)" -f $cat, $count) -ForegroundColor Green
        }
    }

    # Per-craft role verification
    foreach ($craft in $crafts) {
        if (-not $expectedByItemId.ContainsKey($craft.ItemId)) {
            Write-Host ("  WARN: No expected role for {0} ({1}) - add to reference table" -f $craft.Name, $craft.ItemId) -ForegroundColor DarkYellow
            $warnings++
            continue
        }
        $expected = $expectedByItemId[$craft.ItemId]
        if ($craft.Category -ne $expected) {
            Write-Host ("  FAIL: {0} ({1}) is '{2}', expected '{3}'" -f $craft.Name, $craft.ItemId, $craft.Category, $expected) -ForegroundColor Red
            $failures++
        }
    }

    # Reference entries not present in this profession file
    $profItemIds = $crafts | Select-Object -ExpandProperty ItemId
    foreach ($itemId in $expectedByItemId.Keys) {
        $expectedCat = $expectedByItemId[$itemId]
        $inFile = @($crafts | Where-Object { $_.ItemId -eq $itemId })
        if ($inFile.Count -gt 0) { continue }
        # Only flag if this item belongs to this profession's expected set
        $belongs = $false
        switch ($prof.Id) {
            "tailoring" { $belongs = $itemId -in @(32420, 32392, 32390, 32389, 32391, 32584, 32585, 32586, 32587) }
            "leatherworking" { $belongs = $itemId -in @(32574, 32575, 32580, 32581, 32577, 32579, 32582, 32583, 32399, 32397, 32400, 32398, 32395, 32393, 32396, 32394) }
            "blacksmithing" { $belongs = $itemId -in @(32571, 32573, 32568, 32570, 32403, 32401, 32404, 32402) }
        }
        if ($belongs) {
            Write-Host ("  FAIL: Missing craft itemId {0} (expected category: {1})" -f $itemId, $expectedCat) -ForegroundColor Red
            $failures++
        }
    }
}

# Jewelcrafting uses PVE/PVP gear categories, not HoD role categories
Write-Host ""
Write-Host "[JEWELCRAFTING]" -ForegroundColor Yellow
$gearPath = Join-Path $repoRoot "GuildieCrafts\Gear.lua"
$gearContent = Get-Content -Raw -Path $gearPath
$gearCatPattern = 'GuildieCrafts_GearCategories\s*=\s*\{([^}]+)\}'
$gearCatMatch = [regex]::Match($gearContent, $gearCatPattern)
$gearCategories = Parse-LuaStringList $gearCatMatch.Groups[1].Value
Write-Host ("  Gear order categories: {0}" -f ($gearCategories -join ", "))
Write-Host "  OK:   JC workshop uses gem + PVE/PVP socket orders (no HoD role categories)" -ForegroundColor Green

$pveCount = ([regex]::Matches($gearContent, 'category\s*=\s*"PVE"')).Count
$gearPvpPath = Join-Path $repoRoot "GuildieCrafts\GearPvp.lua"
$gearPvpContent = if (Test-Path $gearPvpPath) { Get-Content -Raw -Path $gearPvpPath } else { "" }
$pvpCount = ([regex]::Matches($gearPvpContent, 'category\s*=\s*"PVP"')).Count
$otherGear = @([regex]::Matches($gearContent, 'category\s*=\s*"(?!PVE|PVP)([^"]+)"'))
$otherGear += @([regex]::Matches($gearPvpContent, 'category\s*=\s*"(?!PVP)([^"]+)"'))
if ($otherGear.Count -gt 0) {
    foreach ($m in $otherGear) {
        Write-Host ("  FAIL: Gear.lua entry uses unexpected category '{0}'" -f $m.Groups[1].Value) -ForegroundColor Red
        $failures++
    }
} else {
    Write-Host ("  OK:   Gear catalog - {0} PVE, {1} PVP entries" -f $pveCount, $pvpCount) -ForegroundColor Green
}

Write-Host ""
Write-Host ("=" * 60)
if ($failures -eq 0) {
    Write-Host ("PASSED - {0} warning(s)" -f $warnings) -ForegroundColor Green
    exit 0
} else {
    Write-Host ("FAILED - {0} failure(s), {1} warning(s)" -f $failures, $warnings) -ForegroundColor Red
    exit 1
}
