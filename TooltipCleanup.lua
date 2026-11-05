-- Compatibility workaround for the surplus visible GameTooltip lines captured on
-- Era 1.15.9: one active line, with six old recipe lines still shown underneath.
-- The capture establishes the invalid visibility state, not which addon caused it.
-- Hide only registered line names beyond NumLines(); keep their text available
-- to scanners and leave custom tooltip regions untouched. Tooltip rows are reused:
-- any row we hide must be restored when it becomes an active line again.
local _, _, _, interfaceVersion = GetBuildInfo()
if interfaceVersion ~= 11509 then return end

local tooltip = GameTooltip
if not tooltip then return end

local hiddenLines = {}

local function RestoreActiveLines(self)
    if not next(hiddenLines) or self:IsForbidden() then return end
    local count = self:NumLines()
    for line, index in pairs(hiddenLines) do
        if line:IsShown() then
            hiddenLines[line] = nil
        elseif index <= count then
            local text = line:GetText()
            if text and text ~= "" then
                hiddenLines[line] = nil
                line:Show()
            end
        end
    end
end

local function HideLine(line, index)
    if line and line:IsShown() then
        hiddenLines[line] = index
        line:Hide()
    end
end

local function HideSurplusLines(self)
    if self:IsForbidden() then return end
    RestoreActiveLines(self)
    local count = self:NumLines()
    local index = count + 1
    while true do
        local left = _G["GameTooltipTextLeft" .. index]
        local right = _G["GameTooltipTextRight" .. index]
        if not left and not right then break end
        HideLine(left, index)
        HideLine(right, index)
        index = index + 1
    end
end

-- SetText may display a tooltip without a separate Lua Show call. The Show hook
-- also covers addon refreshes while it is already visible.
hooksecurefunc(tooltip, "SetText", HideSurplusLines)
hooksecurefunc(tooltip, "Show", HideSurplusLines)
tooltip:HookScript("OnShow", HideSurplusLines)

-- Item construction and addon updates can add active lines after Show/SetText.
-- Reconcile only rows hidden by this workaround; never hide rows during OnUpdate
-- or show rows hidden by another addon. With no pending rows this is a no-op.
tooltip:HookScript("OnTooltipSetItem", RestoreActiveLines)
tooltip:HookScript("OnUpdate", RestoreActiveLines)
