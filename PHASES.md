# Phase content

Guildie Crafts tracks **scarce phase materials** and the crafts that consume them. When Blizzard adds a new TBC Anniversary phase, update this file and the addon data.

## TBC — Phase 3 (current)

All four professions are live in Phase 3. JC tracks epic gems; Tailoring, Leatherworking, and Blacksmithing share **Heart of Darkness** as the scarce phase material.

| Profession | Scarce materials | Order catalog |
|------------|------------------|---------------|
| Jewelcrafting | Epic gems (Pyrestone, etc.) | Epic cuts, socketed gear, PVP gear |
| Tailoring | Heart of Darkness | All 9 Phase 3 HoD crafts |
| Leatherworking | Heart of Darkness | Phase 3 HoD crafts (DPS, healer, tank, shadow resist) |
| Blacksmithing | Heart of Darkness | Phase 3 HoD crafts (DPS, healer, tank, shadow resist) |

**Phase 4** and **WOTLK** appear in the workshop picker as disabled “coming soon” options until content is added.

Design workshops so each profession tab reuses the same patterns as JC: promoted crafters, phase stock, recipe coverage, and an order modal for that profession’s Phase 3 materials.

### Enabling a new phase

1. Add the phase to `GuildieCrafts_EXPANSION_PHASES` in `GuildieCrafts/Workshops.lua`
2. Add gem IDs in `Gems.lua`, HoD crafts in the relevant `Crafts*.lua`, and profession recipe scans in `Recipes.lua`
3. Bump version in `GuildieCrafts.toc` and run `.\scripts\sync-guildiecraftstest.ps1`
