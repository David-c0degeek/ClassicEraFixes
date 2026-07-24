--[[
	!ClassicEraFixes

	Patch 1.15.9 moved a number of global API functions into C_* namespaces and deleted
	the Blizzard deprecation shims that used to keep the old global names alive. Addons
	that have not been updated call those names and error out.

	This addon restores the removed globals by forwarding them to their replacements.
	Every restoration is guarded twice: it only runs if the global is actually missing,
	and only if the replacement exists on this client. That makes the file inert on any
	client where Blizzard still provides the original function.
]]

local _G = _G

--------------------------------------------------------------------------------
-- Addon management: the pre-C_AddOns globals
--------------------------------------------------------------------------------
-- Note on GetAddOnEnableState: the argument order changed when it moved. The old
-- global took (character, addon); C_AddOns.GetAddOnEnableState takes (addon, character).
-- The new order is what we expose, because every addon here that still calls the bare
-- global (AtlasLoot) already passes arguments in the new order. Addons that use the old
-- order (AnS, BagBrother) test for C_AddOns first and never reach the global.

do
	local C_AddOns = _G.C_AddOns
	if C_AddOns then
		local names = {
			"DisableAddOn",
			"DisableAllAddOns",
			"EnableAddOn",
			"EnableAllAddOns",
			"GetAddOnDependencies",
			"GetAddOnEnableState",
			"GetAddOnInfo",
			"GetAddOnMetadata",
			"GetAddOnOptionalDependencies",
			"GetNumAddOns",
			"IsAddOnLoadOnDemand",
			"IsAddOnLoadable",
			"IsAddOnLoaded",
			"LoadAddOn",
			"ResetAddOns",
			"SaveAddOns",
		}

		for i = 1, #names do
			local name = names[i]
			if _G[name] == nil and C_AddOns[name] then
				_G[name] = C_AddOns[name]
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Assorted globals that moved namespace
--------------------------------------------------------------------------------

if _G.StripHyperlinks == nil and _G.C_StringUtil and _G.C_StringUtil.StripHyperlinks then
	_G.StripHyperlinks = _G.C_StringUtil.StripHyperlinks
end

if _G.GuildRoster == nil and _G.C_GuildInfo and _G.C_GuildInfo.GuildRoster then
	_G.GuildRoster = _G.C_GuildInfo.GuildRoster
end

-- Prat calls SwapChatChannelByLocalID and C_ChatInfo.SwapChatChannelsByChannelIndex with
-- the same two arguments on its Classic and non-Classic paths, so they are interchangeable.
if _G.SwapChatChannelByLocalID == nil and _G.C_ChatInfo and _G.C_ChatInfo.SwapChatChannelsByChannelIndex then
	_G.SwapChatChannelByLocalID = _G.C_ChatInfo.SwapChatChannelsByChannelIndex
end

-- GetWatchedFactionInfo became C_Reputation.GetWatchedFactionData, which returns a struct
-- instead of a tuple. Field names are taken from Blizzard's own 1.15.9 ReputationBar.lua.
if _G.GetWatchedFactionInfo == nil and _G.C_Reputation and _G.C_Reputation.GetWatchedFactionData then
	function _G.GetWatchedFactionInfo()
		local data = _G.C_Reputation.GetWatchedFactionData()
		if not data then
			return nil
		end
		return data.name, data.reaction, data.currentReactionThreshold,
			data.nextReactionThreshold, data.currentStanding, data.factionID
	end
end

--------------------------------------------------------------------------------
-- DebuffTypeColor
--------------------------------------------------------------------------------
-- The table moved into AuraUtil's DEBUFF_DISPLAY_INFO, which is a local exposed
-- through AuraUtil.GetDebuffDisplayInfoTable(). The documented C_UnitAuras
-- replacement (GetAuraDispelTypeColor) cannot serve these callers: it needs a
-- live aura instance and a colour curve, whereas addons index this by dispel-type
-- string. So rebuild the old table, preferring Blizzard's live colours.

if _G.DebuffTypeColor == nil then
	-- Values from 1.15.8 Blizzard_FrameXMLUtil/Classic/AuraUtil.lua, used only if
	-- the live table is unavailable.
	local colors = {
		["Magic"]   = { r = 0.20, g = 0.60, b = 1.00 },
		["Curse"]   = { r = 0.60, g = 0.00, b = 1.00 },
		["Disease"] = { r = 0.60, g = 0.40, b = 0.00 },
		["Poison"]  = { r = 0.00, g = 0.60, b = 0.00 },
		["none"]    = { r = 0.80, g = 0.00, b = 0.00 },
	}

	local info = _G.AuraUtil and _G.AuraUtil.GetDebuffDisplayInfoTable
		and _G.AuraUtil.GetDebuffDisplayInfoTable()

	if info then
		for dispelType, entry in pairs(info) do
			local color = entry and entry.color
			if color and color.r then
				-- Blizzard renamed the fallback key "none" to "None".
				local key = (dispelType == "None") and "none" or dispelType
				colors[key] = { r = color.r, g = color.g, b = color.b }
			end
		end
	end

	-- Callers use both DebuffTypeColor.none and DebuffTypeColor[""].
	colors[""] = colors["none"]

	_G.DebuffTypeColor = colors
end

--------------------------------------------------------------------------------
-- ChatFrame_OnHyperlinkShow
--------------------------------------------------------------------------------
-- Chat hyperlink handling was rewritten into ChatFrameMixin:OnHyperlinkClick, which
-- calls the still-global SetItemRef. Addons hook the old name with hooksecurefunc to
-- learn that the user clicked a link in chat, so restoring the name alone is not
-- enough -- something has to call it. We publish an empty function for addons to hook
-- and drive it from SetItemRef, translating to the old argument order.

if _G.ChatFrame_OnHyperlinkShow == nil and type(_G.SetItemRef) == "function" then
	function _G.ChatFrame_OnHyperlinkShow(chatFrame, link, text, button)
		-- Intentionally empty. Addons attach their handlers via hooksecurefunc.
	end

	hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
		-- Read the global fresh: hooksecurefunc replaces it with a wrapper each time
		-- another addon hooks it, and we need to reach the current head of that chain.
		local dispatch = _G.ChatFrame_OnHyperlinkShow
		if dispatch then
			dispatch(chatFrame or _G.DEFAULT_CHAT_FRAME, link, text, button)
		end
	end)
end

--------------------------------------------------------------------------------
-- TargetFrame_Update
--------------------------------------------------------------------------------
-- Became TargetFrameMixin:Update. The mixin is copied onto each frame when it is
-- created, so hooking the mixin table now would not reach the existing TargetFrame;
-- we hook the frame instance instead.

if _G.TargetFrame_Update == nil and _G.TargetFrame and type(_G.TargetFrame.Update) == "function" then
	function _G.TargetFrame_Update(self)
		-- Intentionally empty. Addons attach their handlers via hooksecurefunc.
	end

	hooksecurefunc(_G.TargetFrame, "Update", function(self)
		local dispatch = _G.TargetFrame_Update
		if dispatch then
			dispatch(self)
		end
	end)
end
