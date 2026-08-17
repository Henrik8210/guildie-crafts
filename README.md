# Guildie Crafts

Guild crafting workshops for **WoW TBC Anniversary** — organize orders, stock, and recipe coverage by profession and content phase.

Successor to [GemOrder](https://github.com/Henrik8210/wow-addons); GemOrder remains on CurseForge for existing users.

**CurseForge:** push a version tag → GitHub Actions uploads via BigWigs packager (see [WORKSHOP-GUIDELINES.md](WORKSHOP-GUIDELINES.md) → **CurseForge release**). Logo: [Art/GuildieCrafts-Logo.png](Art/GuildieCrafts-Logo.png).

## Features

- **Multiple workshops** per guild — each has a name, expansion/phase (e.g. TBC Phase 3), and profession
- **Jewelcrafting** — order queue, epic gem stock, recipe coverage, PVE/PVP socket orders
- **Tailoring** — Heart of Darkness stock, all 9 Phase 3 craft recipes, and craft orders
- **Leatherworking / Blacksmithing (v2.1)** — HoD stock, Phase 3 craft orders, and recipe coverage (same patterns as Tailoring)
- **Workshop notifications (v2.2)** — crafters alerted on new orders; order owners alerted on pickup/completion; minimap pulse + tooltip until you open the UI
- **Order status bands** — New / Pending / In progress / Completed slips on the order queue

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

Rebuild in-game icon TGAs after editing `Art/GuildieCrafts-Icon.png`:

```powershell
.\scripts\export-icon-tga.ps1
```

## License

Same as GemOrder — personal/guild use.
