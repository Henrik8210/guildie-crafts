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
5. Run `.\scripts\deploy-to-wow.ps1` (copies addon *contents* into the WoW AddOns folder — do not nest `GuildWorkshop\GuildWorkshop\`).

Legacy manual path (same result):

`Copy-Item -Path "GuildWorkshop\*" -Destination "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\GuildWorkshop" -Recurse -Force`

## CurseForge

Use `.pkgmeta` with `package-as: GuildWorkshop`. Tag releases (e.g. `v1.0.0`) for auto-packaging.

## Coexistence with GemOrder

Different saved variables (`GuildWorkshopDB` vs `GemOrderDB`) and sync prefix (`GuildWrk` vs `GemOrd`). Both can be installed; use one in production.

## Pitfall: test mirror must not alias the main global

**Symptom in game:** chat shows `Guild Workshop UI failed to load.` when using `/gw` or the minimap button (often twice if clicked twice). The main window never opens.

**Cause:** If `GuildWorkshopTest` files contain:

```lua
GuildWorkshopTest = GuildWorkshop or {}
```

then the test addon points at the **same Lua table** as the main addon. When `GuildWorkshopTest/UI.lua` loads it runs:

```lua
local UI = {}
GuildWorkshopTest.UI = UI
```

That **replaces** `GuildWorkshop.UI` with a new empty table before `UI:Init` is defined again. If anything interrupts that file (or load order differs), `GuildWorkshop.UI.Init` stays missing and the main addon breaks even though you only wanted to use `/gw`.

**Fix (required in sync script):** `scripts/sync-guildworkshoptest.ps1` must rewrite module headers to use a **separate** global:

```lua
GuildWorkshopTest = GuildWorkshopTest or {}
```

Never `GuildWorkshopTest = GuildWorkshop or {}`.

**Defence in main `UI.lua`:** keep the UI table across reloads:

```lua
local UI = GuildWorkshop.UI or {}
GuildWorkshop.UI = UI
```

Do not revert to `local UI = {}` without reason.

**When debugging:** you can disable **GuildWorkshopTest** in the addon list and `/reload` to confirm the main addon works in isolation. Both addons can run together after the namespace fix above.

**Do not reintroduce:** recipe-indicator or other order-modal experiments that call new helpers in `Recipes.lua` without verifying `/gw` loads after `/reload` with **both** addons enabled.
