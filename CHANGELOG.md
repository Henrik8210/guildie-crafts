# Changelog

## v2.2.11

- **Stock — Guild Bank** — tracked workshop materials in the guild bank appear in the Stock tab (above Workshop Total) and count toward the total. One guild bank visit scans all enabled professions and syncs to the guild.
- **Auto-join workshops** — installing the addon and logging in adds you as a member of every open guild workshop automatically (no need to select from the dropdown first).
- **Member list class colors** — workshop members show correct class colors; class is synced on login and from the guild roster.
- **UI** — selecting or deselecting a workshop no longer spams chat (order notifications unchanged).

## v2.2.10

- **HoD craft order dropdowns** — Tailoring, Leatherworking, and Blacksmithing order modals now show recipe-known indicators (green check / red X) like Jewelcrafting gem picks.
- **Docs** — CurseForge publishing is GitHub Actions only; GitHub webhook must stay disabled (duplicate/incomplete uploads).

## v2.2.9

- **Fix CurseForge packaging** — use `.pkgmeta` `move-folders` for nested `GuildieCrafts/` layout; remove broken CI flatten step that uploaded an empty zip (only stray PNGs). Remove obsolete `assets/art-source/` from repo.

## v2.2.8

- Fix GitHub Actions release: flatten `GuildieCrafts/` for BigWigs packager before upload.

## v2.2.7

- Fix GitHub Actions: run packager with `-t GuildieCrafts` so nested addon layout packages correctly.

## v2.2.6

- Fix GitHub Actions packager: `move-folders` so TOC is found in `GuildieCrafts/` subfolder.

## v2.2.5

- Publish via GitHub Actions now that CurseForge `CF_API_KEY` is configured.

## v2.2.4

- **CurseForge packaging** — fix `.pkgmeta` (remove BOM, doc-style `manual-changelog`), add `## X-Curse-Project-ID`, exclude debug code from packages, GitHub Actions release workflow.

## v2.2.3

- Republish — same addon content as v2.2.2; triggers CurseForge automatic packaging.

## v2.2.2

- **Icon color fix** — corrected red/blue channel swap in PNG→TGA export; minimap and UI portrait now show the warm forge colors.
- **Portrait crop** — circular mask and inset tex coords for the workshop UI portrait slot.

## v2.2.1

- **New addon icon** — guild knights around a blacksmith at the forge (minimap + workshop UI).
- **CurseForge packaging** — `.pkgmeta` manual changelog wired to `CHANGELOG.md`.

## v2.2.0

- **Crafter notifications** — promoted crafters get a chat alert, sound, and pulsing minimap icon when a new order arrives (all workshop types).
- **Order owner notifications** — notified when your order is picked up, completed, or cancelled; catch-up alerts on login if you were offline.
- **Minimap tooltip** — hover the icon to read unread notifications before opening the UI.
- **Order status bands** — **New**, **Pending**, **In progress**, and **Completed** slips on order rows.
- **Blacksmithing fix** — Dawnsteel bracers/shoulders moved to the Healer category.
- **UI polish** — recipe tooltip hitboxes, gem-row layout on wrapped orders, and craft category health-check script for releases.

## v2.1.0

- Leatherworking and Blacksmithing HoD workshops (orders, stock, recipes).
- Workshop picker UI polish, profession portraits, and Phase 4 (soon) in the picker.

## v2.0.0

- Rebrand to Guildie Crafts; multi-workshop support with expansion/phase selection.
