# Guildie Crafts

Guild crafting workshops for **WoW TBC Anniversary** — organize orders, stock, and recipe coverage by profession and content phase.

Successor to [GemOrder](https://github.com/Henrik8210/wow-addons); GemOrder remains on CurseForge for existing users.

**CurseForge:** upload the `GuildieCrafts/` folder (or tag a release — see [WORKSHOP-GUIDELINES.md](WORKSHOP-GUIDELINES.md)). Logo for the project page: [Art/GuildieCrafts-Logo.png](Art/GuildieCrafts-Logo.png).

## Features

- **Multiple workshops** per guild — each has a name, expansion/phase (e.g. TBC Phase 3), and profession
- **Jewelcrafting** — order queue, epic gem stock, recipe coverage, PVE/PVP socket orders
- **Tailoring** — Heart of Darkness stock, all 9 Phase 3 craft recipes, and craft orders
- **Leatherworking / Blacksmithing (v2.1)** — HoD stock, Phase 3 craft orders, and recipe coverage (same patterns as Tailoring)
- **Workshop picker** — select an existing workshop or create a new one; profession icons in the main window portrait

## Commands

| Command | Action |
|---------|--------|
| `/guildiecrafts`, `/gc`, or `/gw` | Toggle main window |

## Development

See [WORKSHOP-GUIDELINES.md](WORKSHOP-GUIDELINES.md) for sync, deploy, and release workflow.

Phase content (materials, recipes, order catalogs) is documented in [PHASES.md](PHASES.md).

Validate HoD craft categories before a release:

```powershell
.\scripts\check-craft-categories.ps1
```

## License

Same as GemOrder — personal/guild use.
