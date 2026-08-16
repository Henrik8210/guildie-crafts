# Phase content

Guild Workshop tracks **scarce phase materials** and the crafts that consume them. When Blizzard adds a new TBC Anniversary phase, update this file and the addon data.

## TBC — Phase 3 (current)

All four professions launch in Phase 3. JC tracks epic gems; the other three share **Heart of Darkness** as the scarce phase material.

| Profession | Scarce materials | Order catalog |
|------------|------------------|---------------|
| Jewelcrafting | Epic gems (Pyrestone, etc.) | Epic cuts, socketed gear, PVP gear — **v1.0 (live)** |
| Tailoring | Heart of Darkness | All 9 Phase 3 HoD crafts — **v1.2 (live)** |
| Leatherworking | Heart of Darkness | HoD crafts — *next release* |
| Blacksmithing | Heart of Darkness | HoD crafts — *next release* |

Design workshops so each profession tab reuses the same patterns as JC: promoted crafters, phase stock, recipe coverage, and an order modal for that profession’s Phase 3 materials.

### Enabling a new phase

1. Add the phase to `GuildWorkshop_EXPANSION_PHASES` in `GuildWorkshop/Workshops.lua`
2. Add gem IDs in `Gems.lua`, tailoring HoD crafts in `CraftsTailoring.lua`, and profession recipe scans in `Recipes.lua`
3. Bump version in `GuildWorkshop.toc` and run `.\scripts\sync-guildworkshoptest.ps1`
