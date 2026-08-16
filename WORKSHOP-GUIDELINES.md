# Guild Workshop — dev guidelines

## Repo

- **Remote:** https://github.com/Henrik8210/guild-workshop
- **Main addon:** `GuildWorkshop/`
- **Test mirror:** `GuildWorkshopTest/` — separate saved vars and sync prefix (`GuildWrkT`)

## WoW install path

After changes, copy both folders to:

`C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\`

Then `/reload` in game.

## Workflow

1. Edit `GuildWorkshop/` only (not the test folder directly).
2. Run `.\scripts\sync-guildworkshoptest.ps1` to mirror into `GuildWorkshopTest/`.
3. Bump `## Version:` in `GuildWorkshop.toc` when shipping a release.
4. Commit and push when asked.
5. Copy `GuildWorkshop/` and `GuildWorkshopTest/` to the WoW AddOns path.

## CurseForge

Use `.pkgmeta` with `package-as: GuildWorkshop`. Tag releases (e.g. `v1.0.0`) for auto-packaging.

## Coexistence with GemOrder

Different saved variables (`GuildWorkshopDB` vs `GemOrderDB`) and sync prefix (`GuildWrk` vs `GemOrd`). Both can be installed; use one in production.
