# !ClassicEraFixes

A tiny compatibility shim for **WoW Classic Era 1.15.9**.

Patch 1.15.9 moved a batch of global API functions into `C_*` namespaces and, unlike
most retail deprecations, shipped **no compatibility shim** for the old global names.
Addons that have not been updated call those names and throw Lua errors. `!ClassicEraFixes`
restores the removed globals so those addons keep working until their authors update.
It also includes a Classic Era 1.15.9 workaround for old item and recipe text
remaining visible underneath a shorter tooltip.

The API restorations are limited to the verified globals below. Each restoration
is skipped when Blizzard still provides the original function. The tooltip
workaround runs only on interface version `11509`.

## Tooltip cleanup

When the shared GameTooltip is reused, old item or recipe lines can remain visible
below its current contents. This can affect flight maps, auction buttons and
other windows. The workaround hides named tooltip lines beyond `NumLines()` when
the tooltip is displayed or its title is replaced.

Active lines and addon-added information are preserved. Hidden text remains
available to tooltip scanners, and no per-frame polling is used. The malformed
tooltip state was captured and the workaround was tested in game; the addon
originally responsible has not been conclusively identified.

Use `/cef` or `/classicerafixes` to check that the addon loaded and see which
compatibility APIs are available. A load-status record is saved in
`ClassicEraFixesDB`.

## What it restores

| Restored global | Backed by |
| --- | --- |
| The pre-`C_AddOns` family — `IsAddOnLoaded`, `GetAddOnMetadata`, `LoadAddOn`, `EnableAddOn`, `GetAddOnInfo`, `GetAddOnEnableState`, … | `C_AddOns.*` |
| `StripHyperlinks` | `C_StringUtil.StripHyperlinks` |
| `GuildRoster` | `C_GuildInfo.GuildRoster` |
| `SwapChatChannelByLocalID` | `C_ChatInfo.SwapChatChannelsByChannelIndex` |
| `GetWatchedFactionInfo` | `C_Reputation.GetWatchedFactionData` (tuple rebuilt from the struct) |
| `DebuffTypeColor` | Rebuilt from Blizzard's live `AuraUtil` table, 1.15.8 literals as fallback |
| `ChatFrame_OnHyperlinkShow` | Dispatch stub driven by a `SetItemRef` hook |
| `TargetFrame_Update` | Dispatch stub driven by a hook on the `TargetFrame` instance |

## How it stays safe

Every restoration is **double-guarded**: it acts only if the global is missing *and* its
replacement exists on the running client. On any client that still ships the original
function, that restoration does nothing. The folder name starts with `!` so it sorts ahead of
every other addon and its shims are in place before anything calls them.

`GetAddOnEnableState` is exposed with the **new** `(addon, character)` argument order —
the order `C_AddOns` uses and the only order any addon still calling the bare global relies
on. `GetCurrencyInfo` is deliberately **not** shimmed: callers disagree on its return shape
and Vanilla has no currencies, so those paths are dead.

## Install (manual)

Copy the `!ClassicEraFixes` folder into:

```
World of Warcraft/_classic_era_/Interface/AddOns/
```

Keep the leading `!` in the folder name — the load order depends on it.

## Contributing / reporting

Found an addon still erroring on a removed 1.15.9 global that isn't in the table above?
Open an issue with the **exact** Lua error and the addon name. New shims must be verifiable:
the ground-truth method is to diff Blizzard's own UI source (`Gethe/wow-ui-source`, branch
`classic_era`) between the 1.15.8 and 1.15.9 tags and confirm the global actually died —
patch-note summaries are not reliable.

## License

MIT — see [LICENSE](LICENSE).

---

## Maintainer: releasing

Releases are automated by the [BigWigs packager](https://github.com/BigWigsMods/packager)
GitHub Action (`.github/workflows/release.yml`). It fires on any pushed tag and substitutes
`@project-version@` in the `.toc` from the tag name.

**First-time setup**

1. Create the GitHub repo (name it `ClassicEraFixes` — GitHub disallows `!` in repo
   names; `.pkgmeta`'s `package-as` restores the `!ClassicEraFixes` folder name in the zip).
2. Edit `!ClassicEraFixes.toc`:
   - `## X-Website:` → your repo URL.
   - `## X-Curse-Project-ID:` → the numeric ID CurseForge shows after you create the
     project (leave the placeholder and CurseForge upload is simply skipped).
3. On CurseForge: create the project, then **My API Tokens** → add the token as a repo
   secret named `CF_API_KEY`. (Optional: `WAGO_API_TOKEN`, `WOWI_API_TOKEN` for those sites.)
   `GITHUB_TOKEN` is provided automatically and always makes a GitHub release.

**Cut a release**

```sh
git tag v1.0.0
git push origin v1.0.0
```

The Action packages the zip and publishes it. Verify the zip's top-level folder is
`!ClassicEraFixes/` and contains `!ClassicEraFixes.toc` — WoW requires the `.toc` filename
to match the folder name.

**Before a big patch:** `DebuffTypeColor` is rebuilt from Blizzard's live tables with 1.15.8
literals as fallback. After a major client patch, confirm those colours still resolve and
re-cut if the data shifted.
