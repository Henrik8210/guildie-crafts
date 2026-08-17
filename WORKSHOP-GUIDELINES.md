# Guildie Crafts — dev guidelines

## Repo

- **Remote:** https://github.com/Henrik8210/guildie-crafts
- **Main addon:** `GuildieCrafts/`
- **Test mirror:** `GuildieCraftsTest/` — separate saved vars and sync prefix (`GuildieCftT`)

## WoW install path

After changes, copy both folders to:

`C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\`

Then `/reload` in game.

## Icon assets

Source art: [Art/GuildieCrafts-Icon.png](Art/GuildieCrafts-Icon.png). In-game textures:

| File | Size | Use |
|------|------|-----|
| `GuildieCrafts/Art/WorkshopLogo.tga` | 256×256 | Minimap button |
| `GuildieCrafts/Art/WorkshopLogoPortrait.tga` | 64×64 | Workshop UI portrait (no workshop selected) |

Rebuild after editing the PNG:

```powershell
.\scripts\export-icon-tga.ps1
.\scripts\sync-guildiecraftstest.ps1
.\scripts\deploy-to-wow.ps1
```

`export-icon-tga.ps1` crops the baked-in square frame (~17%) and applies a circular alpha mask for the portrait. `png-to-tga.ps1` writes BGRA directly (GDI+ LockBits order) — do not swap R/B when exporting.

CurseForge / web logo: [Art/GuildieCrafts-Logo.png](Art/GuildieCrafts-Logo.png) (export via `.\scripts\export-logo-png.ps1` if needed).

## Workflow

1. Edit `GuildieCrafts/` only (not the test folder directly).
2. Run `.\scripts\sync-guildiecraftstest.ps1` to mirror into `GuildieCraftsTest/`.
3. Bump `## Version:` in `GuildieCrafts.toc` when shipping a release.
4. Commit and push when asked.
5. Run `.\scripts\deploy-to-wow.ps1` (copies addon *contents* into the WoW AddOns folder — do not nest `GuildieCrafts\GuildieCrafts\`).

Legacy manual path (same result):

`Copy-Item -Path "GuildieCrafts\*" -Destination "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\GuildieCrafts" -Recurse -Force`

## CurseForge release

Official docs: [Automatic Packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging).

CurseForge packages from GitHub when a **tagged commit** is pushed (with “package tagged commits” enabled). Pushing to `main` alone does **not** publish a new file — only pushing a **version tag** does.

### Project setup (one-time)

**1. CurseForge → Project → Source**

| Setting | Value |
|---------|--------|
| Source code | GitHub |
| Repository URL | `https://github.com/Henrik8210/guildie-crafts` |
| Automatic packaging | **Package any new tagged commits** (not “package all commits”) |

**2. GitHub webhook** (required for packaging to trigger — linking the repo in Source alone is not enough)

1. CurseForge → **API tokens** → create a token (e.g. name “Webhooks”).
2. CurseForge → Project → **Overview** → **About This Project** → note the **project ID**.
3. GitHub repo → **Settings** → **Webhooks** → **Add webhook**:
   - **Payload URL:** `https://www.curseforge.com/api/projects/{projectID}/package?token={token}`
   - Replace `{projectID}` and `{token}` with your values.
   - Leave other settings at defaults.

**3. Repo `.pkgmeta`** (repo root, not inside `GuildieCrafts/`)

`package-as: GuildieCrafts` — the packager zips only that folder. `ignore:` excludes `GuildieCraftsTest/`, `scripts/`, dev docs, and root `Art/`. `manual-changelog` pulls release notes from `CHANGELOG.md`.

Project logo: [Art/GuildieCrafts-Logo.png](Art/GuildieCrafts-Logo.png).

### How it works

1. Commit and push changes to `main`.
2. Create a **git tag** on that commit (e.g. `v2.2.2`).
3. Push the tag — GitHub fires the webhook; CurseForge runs the packager.
4. A zip appears under **Files**, version from `## Version:` in `GuildieCrafts/GuildieCrafts.toc`.

Keep tag and `.toc` aligned (`v2.2.2` ↔ `2.2.2`).

**Release type** (from [official docs](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging)):

| Tag pattern | CurseForge file type |
|-------------|----------------------|
| Contains `alpha` (e.g. `2.3.0-alpha1`) | Alpha |
| Contains `beta` | Beta |
| Other tagged commits | Release |
| Untagged (only if “package all commits”) | Alpha |

Our tags (`v2.2.2`, etc.) ship as **Release**.

### Release checklist

Before tagging:

1. Bump `## Version:` in `GuildieCrafts/GuildieCrafts.toc`.
2. Run `.\scripts\sync-guildiecraftstest.ps1`.
3. Run `.\scripts\check-craft-categories.ps1` if HoD crafts changed.
4. Commit and push to `main`.

To publish on CurseForge (only when explicitly requested — see **Agent instructions** below):

```powershell
git tag v2.1.0          # match the .toc version, with a v prefix
git push origin v2.1.0
```

If the tag already exists locally but was never pushed, push it. If you need to move a tag to a newer commit (rare), delete and recreate it — never force-push tags unless you know CurseForge should rebuild that version.

Check CurseForge → **Files** or **Activity** after a minute; packaging is not instant.

### Agent instructions

**Do not create or push CurseForge release tags unless the user explicitly asks** to publish or release a version on CurseForge (e.g. “put this on CurseForge”, “release v2.1.0 to CurseForge”, “push the CurseForge tag”).

When the user does ask:

1. Confirm `GuildieCrafts/GuildieCrafts.toc` version matches the requested release.
2. Confirm changes are committed and pushed to `main`.
3. Create the tag if it does not exist: `git tag v<version>` (e.g. `v2.1.0`).
4. Push the tag: `git push origin v<version>`.
5. Tell the user to check CurseForge Files/Activity for the new build.

Normal “commit to GitHub” requests do **not** include tagging unless the user also asks for CurseForge.

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
