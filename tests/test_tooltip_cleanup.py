"""Run with Python and lupa[lua51]: python tests/test_tooltip_cleanup.py."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parents[1]
setup = r'''
interfaceVersion = 11509
function GetBuildInfo() return '1.15.9', '70576', '', interfaceVersion end
function hooksecurefunc(target, method, callback)
    local original = target[method]
    target[method] = function(...)
        local result = {original(...)}
        callback(...)
        return unpack(result)
    end
end
GameTooltip = { count = 1, scripts = {}, forbidden = false, calls = 0 }
function GameTooltip:IsForbidden() return self.forbidden end
function GameTooltip:NumLines() self.calls = self.calls + 1; return self.count end
function GameTooltip:HookScript(event, callback)
    local original = self.scripts[event]
    self.scripts[event] = function(...)
        if original then original(...) end
        callback(...)
    end
end
function GameTooltip:Fire(event)
    if self.scripts[event] then self.scripts[event](self, 0.016) end
end
function GameTooltip:SetText() self.setTextCalls = (self.setTextCalls or 0) + 1; return 'preserved' end
function GameTooltip:Show() self:Fire('OnShow') end
for i = 1, 40 do
    for _, side in ipairs({'Left', 'Right'}) do
        local line = { shown = side == 'Left' and i <= 7 or side == 'Right' and i == 4,
                       text = 'old recipe row ' .. i }
        function line:IsShown() return self.shown end
        function line:Hide() self.shown = false end
        function line:Show() self.shown = true end
        function line:GetText() return self.text end
        _G['GameTooltipText' .. side .. i] = line
    end
end
'''
checks = r'''
local tip = GameTooltip
local observerCalls = 0
hooksecurefunc(tip, 'SetText', function() observerCalls = observerCalls + 1 end)
assert(tip:SetText() == 'preserved')
assert(tip.setTextCalls == 1 and observerCalls == 1)
assert(GameTooltipTextLeft1:IsShown())
for i = 2, 7 do assert(not _G['GameTooltipTextLeft' .. i]:IsShown(), 'stale recipe row visible') end
assert(not GameTooltipTextRight4:IsShown())
-- The item builder reuses hidden rows and grows the active line count.
tip.count = 30
for i = 1, 30 do
    local line = _G['GameTooltipTextLeft' .. i]
    line.text = 'item/set bonus row ' .. i
    if i >= 8 then line.shown = i ~= 13 end
end
GameTooltipTextRight4.text = 'new right-side item text'
tip:Fire('OnTooltipSetItem')
for i = 1, 30 do
    if i ~= 13 then assert(_G['GameTooltipTextLeft' .. i]:IsShown(), 'active row stays hidden: ' .. i) end
end
assert(not GameTooltipTextLeft13:IsShown(), 'must respect a row hidden by another addon')
assert(GameTooltipTextRight4:IsShown(), 'right-side reused row stays hidden')
assert(not GameTooltipTextRight5:IsShown(), 'unused right-side row must remain hidden')
-- A Show during partial construction is followed only by an OnUpdate.
tip.count = 1
tip:Show()
assert(not GameTooltipTextLeft20:IsShown())
tip.count = 30
tip:Fire('OnUpdate')
assert(GameTooltipTextLeft20:IsShown(), 'late item row not restored')
assert(not GameTooltipTextLeft13:IsShown())
-- A blank right side must not be shown just because its index is active.
tip.count = 1
tip:SetText()
GameTooltipTextRight4.text = ''
tip.count = 30
tip:Fire('OnUpdate')
assert(not GameTooltipTextRight4:IsShown())
GameTooltipTextRight4.text = 'later right text'
tip:Fire('OnUpdate')
assert(GameTooltipTextRight4:IsShown())
-- Forbidden tooltips must not have their contents inspected or changed.
tip.forbidden = true
local before = tip.calls
tip:SetText(); tip:Show(); tip:Fire('OnTooltipSetItem'); tip:Fire('OnUpdate')
assert(tip.calls == before)
'''
source = (root / 'TooltipCleanup.lua').read_text(encoding='utf-8-sig')
lua = LuaRuntime()
lua.execute(setup)
lua.execute(source)
lua.execute(checks)
print('PASS: stale text hidden; reused rows restored; late construction, other hidden rows, blanks, forbidden tooltips, and hook chains handled.')
lua = LuaRuntime()
lua.execute(setup)
lua.execute('interfaceVersion = 11508')
lua.execute(source)
assert lua.eval('next(GameTooltip.scripts) == nil')
print('PASS: workaround remains inert on other interface versions.')
toc = (root / '!ClassicEraFixes.toc').read_text(encoding='utf-8-sig')
files = [s.strip() for s in toc.splitlines() if s.strip() and not s.startswith('#')]
assert files == ['Fixes.lua', 'TooltipCleanup.lua'], files
parser = LuaRuntime()
for name in files:
    parser.execute('assert(loadstring(...))', (root / name).read_text(encoding='utf-8-sig'))
print('PASS: both addon files are loaded by the TOC and parse under Lua 5.1.')
