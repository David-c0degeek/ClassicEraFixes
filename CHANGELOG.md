# Changelog

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
