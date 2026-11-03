-- Compatibility workaround for the surplus visible GameTooltip lines captured on
-- Era 1.15.9: one active line, with six old recipe lines still shown underneath.
-- The capture establishes the invalid visibility state, not which addon caused it.
-- Hide only registered line names beyond NumLines(); keep their text available
-- to scanners and leave all active lines and custom tooltip regions untouched.
local _, _, _, interfaceVersion = GetBuildInfo()
if interfaceVersion ~= 11509 then return end

local tooltip = GameTooltip
if not tooltip then return end

local function HideSurplusLines(self)
    if self:IsForbidden() then return end
    local count = self:NumLines()
    local index = count + 1
    while true do
        local left = _G["GameTooltipTextLeft" .. index]
        local right = _G["GameTooltipTextRight" .. index]
        if not left and not right then break end
        if left and left:IsShown() then left:Hide() end
        if right and right:IsShown() then right:Hide() end
        index = index + 1
    end
end

-- SetText may display a tooltip without a separate Lua Show call. The Show hook
-- also covers addon refreshes while it is already visible. No OnUpdate polling.
hooksecurefunc(tooltip, "SetText", HideSurplusLines)
hooksecurefunc(tooltip, "Show", HideSurplusLines)
tooltip:HookScript("OnShow", HideSurplusLines)
