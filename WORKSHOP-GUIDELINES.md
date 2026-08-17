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

**The right way (what actually works):** push a version tag → **GitHub Actions** runs [BigWigs packager](https://github.com/BigWigsMods/packager) → uploads to CurseForge via the [Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-api).

Pushing to `main` alone does **not** publish. Only pushing a **version tag** (`v2.2.8`) triggers `.github/workflows/release.yml`.

Official webhook docs ([Automatic Packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging)) exist but are **unreliable** for this repo layout — see [Why not webhook-only?](#why-not-webhook-only) below.

### One-time setup

| Step | Where | What |
|------|--------|------|
| Project ID | CurseForge → Overview | **1655417** (also in `## X-Curse-Project-ID` in toc) |
| API token | [authors.curseforge.com → API tokens](https://authors.curseforge.com/#/settings/api-tokens) | Create token (e.g. “GitHub Actions”) |
| GitHub secret | Repo → Settings → Secrets → Actions | Name **`CF_API_KEY`**, value = API token |
| Source (optional) | CurseForge → Source | GitHub URL + “Package any new tagged commits” + **Save** |
| Webhook (optional) | GitHub → Settings → Webhooks | `https://www.curseforge.com/api/projects/1655417/package?token={token}` — see caveats below |

No GitHub OAuth is required on the CurseForge Source page; URL + secret is enough.

### Repo packaging files

| File | Purpose |
|------|---------|
| `.pkgmeta` (repo root) | `package-as: GuildieCrafts`, `manual-changelog: CHANGELOG.md`, `ignore:` list. **Must be UTF-8 without BOM.** |
| `CHANGELOG.md` | Release notes; packager picks the section matching the tag (e.g. `## v2.2.8`) |
| `GuildieCrafts/GuildieCrafts.toc` | `## Version:` must match tag; `## X-Curse-Project-ID: 1655417`; `## Interface: 20505, 20506` |
| `.github/workflows/release.yml` | Tag push → flatten `GuildieCrafts/` → `BigWigsMods/packager@v2` → CurseForge upload |

Do **not** use nested `manual-changelog:` YAML blocks — use the simple string form from the docs: `manual-changelog: CHANGELOG.md`.

### Release checklist (agents)

Only when the user **explicitly** asks to publish on CurseForge:

1. Bump `## Version:` in `GuildieCrafts/GuildieCrafts.toc` and `GuildieCrafts.VERSION` in `Core.lua`.
2. Add a `## vX.Y.Z` section to `CHANGELOG.md`.
3. Run `.\scripts\sync-guildiecraftstest.ps1`.
4. Run `.\scripts\check-craft-categories.ps1` if HoD crafts changed.
5. Commit and push to `main`.
6. Create and push tag (name must match toc version with `v` prefix):

```powershell
git tag v2.2.8
git push origin v2.2.8
```

7. Watch **GitHub → Actions → Release** — must show **success**.
8. Check CurseForge → **Files** — new file appears as **Processing**, then **Approved** (may show as `vX.Y.Z-bcc` for TBC).

**Do not** push a tag unless the user asked for a CurseForge release. Commits to `main` alone are not releases.

**Do not** delete and re-push tags to “retry” — GitHub sends tag-delete webhooks that CurseForge ignores; use a **new patch version** instead (e.g. `v2.2.9`).

### How the GitHub Action works

Our addon source lives in `GuildieCrafts/`, but [BigWigs packager](https://github.com/BigWigsMods/packager) expects `GuildieCrafts.toc` at the **checkout root**. The workflow fixes this:

```yaml
# .github/workflows/release.yml (summary)
on:
  push:
    tags: ["v*"]
steps:
  - checkout (fetch-depth: 0)
  - run: cp -a GuildieCrafts/. . && rm -rf GuildieCrafts   # flatten for packager
  - uses: BigWigsMods/packager@v2
    env:
      CF_API_KEY: ${{ secrets.CF_API_KEY }}
```

Output zip still installs as `Interface/AddOns/GuildieCrafts/` because `package-as: GuildieCrafts` in `.pkgmeta`.

Local dev layout (`GuildieCrafts/` folder, `deploy-to-wow.ps1`) is unchanged — flattening happens **only in CI**.

### Release type

| Tag pattern | CurseForge file type |
|-------------|----------------------|
| Contains `alpha` | Alpha |
| Contains `beta` | Beta |
| `v2.2.8`, etc. | Release |

### Why not webhook-only?

The CurseForge webhook (`/api/projects/{id}/package?token=`) can return `{"success":true}` without creating a file. Known issues for this repo:

- Packager expects a **flat** checkout; nested `GuildieCrafts/` is not found without the CI flatten step.
- Webhook deliveries for **tag delete** (`"deleted": true`) do not package; only **tag create** (`"created": true`) should.
- `.pkgmeta` with a UTF-8 BOM breaks YAML parsing (fixed in v2.2.4+).

**Use GitHub Actions + `CF_API_KEY` as the supported path.** Keep the webhook if you want, but do not rely on it.

### Agent instructions

**Do not create or push CurseForge release tags** unless the user explicitly asks (e.g. “release to CurseForge”, “push v2.3.0 to CurseForge”).

When they do ask, follow [Release checklist](#release-checklist-agents) above.

Normal “commit to GitHub” or “update docs” requests do **not** include tagging.

Project logo: [Art/GuildieCrafts-Logo.png](Art/GuildieCrafts-Logo.png).

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
