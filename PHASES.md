# Phase content

Guildie Crafts tracks **scarce phase materials** and the crafts that consume them. When Blizzard adds a new TBC Anniversary phase, update this file and the addon data.

## TBC — Phase 3 (current)

All four professions are live in Phase 3. JC tracks epic gems; Tailoring, Leatherworking, and Blacksmithing share **Heart of Darkness** as the scarce phase material.

| Profession | Scarce materials | Order catalog |
|------------|------------------|---------------|
| Jewelcrafting | Epic gems (Pyrestone, etc.) | Epic cuts, PVE/PVP socketed gear |
| Tailoring | Heart of Darkness | 9 HoD crafts — Shadow Resist, Healer, Caster |
| Leatherworking | Heart of Darkness | 16 HoD crafts — Physical DPS, Healer, Shadow Resist |
| Blacksmithing | Heart of Darkness | 8 HoD crafts — Physical DPS, Healer, Shadow Resist |

### HoD craft categories by profession

| Profession | Categories | Notes |
|------------|------------|-------|
| Tailoring | Shadow Resist, Healer, Caster | No physical DPS cloth HoD crafts in Phase 3 |
| Leatherworking | Physical DPS, Healer, Shadow Resist | Mail + leather DPS/healer; two shadow-resist sets |
| Blacksmithing | Physical DPS, Healer, Shadow Resist | Swiftsteel = DPS; Dawnsteel = healer plate |

Run `.\scripts\check-craft-categories.ps1` to verify every craft is in the correct category before shipping.

**Phase 4** and **WOTLK** appear in the workshop picker as disabled “coming soon” options until content is added.

Design workshops so each profession tab reuses the same patterns as JC: promoted crafters, phase stock, recipe coverage, and an order modal for that profession’s Phase 3 materials.

### Enabling a new phase

1. Add the phase to `GuildieCrafts_EXPANSION_PHASES` in `GuildieCrafts/Workshops.lua`
2. Add gem IDs in `Gems.lua`, HoD crafts in the relevant `Crafts*.lua`, and profession recipe scans in `Recipes.lua`
3. Bump version in `GuildieCrafts.toc` and run `.\scripts\sync-guildiecraftstest.ps1`
4. Run `.\scripts\check-craft-categories.ps1` if HoD crafts changed
