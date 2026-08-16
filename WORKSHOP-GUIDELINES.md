# Guildie Crafts — dev guidelines

## Repo

- **Remote:** https://github.com/Henrik8210/guildie-crafts
- **Main addon:** `GuildieCrafts/`
- **Test mirror:** `GuildieCraftsTest/` — separate saved vars and sync prefix (`GuildieCftT`)

## WoW install path

After changes, copy both folders to:

`C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\`

Then `/reload` in game.

## Workflow

1. Edit `GuildieCrafts/` only (not the test folder directly).
2. Run `.\scripts\sync-guildiecraftstest.ps1` to mirror into `GuildieCraftsTest/`.
3. Bump `## Version:` in `GuildieCrafts.toc` when shipping a release.
4. Commit and push when asked.
5. Run `.\scripts\deploy-to-wow.ps1` (copies addon *contents* into the WoW AddOns folder — do not nest `GuildieCrafts\GuildieCrafts\`).

Legacy manual path (same result):

`Copy-Item -Path "GuildieCrafts\*" -Destination "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\GuildieCrafts" -Recurse -Force`

## CurseForge

Use `.pkgmeta` with `package-as: GuildieCrafts`. Tag releases (e.g. `v1.0.0`) for auto-packaging.

## Coexistence with GemOrder

Different saved variables (`GuildieCraftsDB` vs `GemOrderDB`) and sync prefix (`GuildieCft` vs `GemOrd`). Both can be installed; use one in production.

## Pitfall: test mirror must not alias the main global

**Symptom in game:** chat shows `Guildie Crafts UI failed to load.` when using `/gw` or the minimap button (often twice if clicked twice). The main window never opens.

**Cause:** If `GuildieCraftsTest` files contain:

```lua
GuildieCraftsTest = GuildieCrafts or {}
```

then the test addon points at the **same Lua table** as the main addon. When `GuildieCraftsTest/UI.lua` loads it runs:

```lua
local UI = {}
GuildieCraftsTest.UI = UI
```

That **replaces** `GuildieCrafts.UI` with a new empty table before `UI:Init` is defined again. If anything interrupts that file (or load order differs), `GuildieCrafts.UI.Init` stays missing and the main addon breaks even though you only wanted to use `/gw`.

**Fix (required in sync script):** `scripts/sync-guildiecraftstest.ps1` must rewrite module headers to use a **separate** global:

```lua
GuildieCraftsTest = GuildieCraftsTest or {}
```

Never `GuildieCraftsTest = GuildieCrafts or {}`.

**Defence in main `UI.lua`:** keep the UI table across reloads:

```lua
local UI = GuildieCrafts.UI or {}
GuildieCrafts.UI = UI
```

Do not revert to `local UI = {}` without reason.

**When debugging:** you can disable **GuildieCraftsTest** in the addon list and `/reload` to confirm the main addon works in isolation. Both addons can run together after the namespace fix above.

**Do not reintroduce:** recipe-indicator or other order-modal experiments that call new helpers in `Recipes.lua` without verifying `/gw` loads after `/reload` with **both** addons enabled.
