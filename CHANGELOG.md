# Changelog

## 1.1.3

- Fix missing set pieces and set-bonus descriptions after the tooltip cleanup
  hides rows that a longer item tooltip later reuses.
- Keep the stale-text cleanup and restore only rows it hid when those rows become
  active again, including lines added after the tooltip is displayed.
- Add Lua 5.1 regression coverage for stale text, reused rows, delayed updates,
  blank rows, forbidden tooltips and coexistence with other tooltip hooks.
- Confirmed in game: set-bonus text is visible with the cleanup enabled.

## 1.1.1

- Hide stale text left beneath a shorter tooltip on Classic Era 1.15.9. This
  addresses old item and recipe descriptions remaining visible on flight maps,
  auction buttons and other uses of the shared GameTooltip.
- Preserve active tooltip lines, including addon additions, and retain hidden text
  for tooltip scanners. The workaround uses display hooks without update polling.
- Add `/cef` and `/classicerafixes` to report the client build and available APIs,
  with a load-status record in `ClassicEraFixesDB`.
- Verified with Lua 5.1 behavioural checks and an in-game retest. The captured
  surplus-line state is confirmed; the addon originally responsible is not known.

## 1.0.0

Initial release. Restores global API functions removed by Classic Era patch
1.15.9 without a Blizzard deprecation shim:

- The pre-`C_AddOns` family (`IsAddOnLoaded`, `GetAddOnMetadata`, `LoadAddOn`,
  `GetAddOnEnableState`, and the rest).
- `StripHyperlinks`, `GuildRoster`, `SwapChatChannelByLocalID`,
  `GetWatchedFactionInfo`.
- `DebuffTypeColor` — rebuilt from Blizzard's live `AuraUtil` data.
- `ChatFrame_OnHyperlinkShow` and `TargetFrame_Update` — restored as dispatch
  stubs driven by the functions Blizzard still calls, so `hooksecurefunc`
  consumers keep firing.

Every restoration is double-guarded: it acts only when the global is missing
**and** the replacement exists, so the addon is inert on any other client.
