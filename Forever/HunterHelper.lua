local _, addon = ...

-- Shows at a glance whether your target can be shot. Forever only, hunters only.
--
-- Classic keeps an 8 yard minimum range on ranged attacks, so there is a dead zone
-- where you can neither shoot nor melee. Retail removed minimum range entirely,
-- which is why this is not a shared module.

-- Both probes are auto-attacks: no ranks to renumber, and every hunter has both
-- from level one. Auto Shot carries Classic's 8 yard minimum range, so it reports
-- out of range when you are too close as well as too far -which is the whole point.
-- Auto Attack then separates "close enough to melee" from the dead zone between them.
--
-- CheckInteractDistance is deliberately not used: its shortest band (index 3) is
-- documented at roughly 9.9 yards and so reports true right through the dead zone,
-- claiming melee range when you can actually do neither.
local AUTO_SHOT   = 75
local AUTO_ATTACK = 6603

-- Range state changes far slower than the frame rate, so it is polled rather than
-- recalculated every frame. Cursor position still follows every frame.
local THROTTLE = 0.1

local helperFrame = nil
local lastState = nil
local lastCx, lastCy = nil, nil
local sinceCheck = 0

local function isHunter()
    return select(2, UnitClass("player")) == "HUNTER"
end

local function createFrame()
    local f = CreateFrame("Frame", "MysteriousQoL_HunterHelperFrame", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(false)
    f:SetSize(40, 40)

    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 28, "THICKOUTLINE")
    text:SetPoint("CENTER")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(2, -2)
    f.text = text

    return f
end

-- nil when there is no hostile target worth judging range against.
local function rangeState()
    if not UnitExists("target") then return nil end
    if not UnitCanAttack("player", "target") then return nil end
    if UnitIsDeadOrGhost("target") then return nil end

    if C_Spell.IsSpellInRange(AUTO_SHOT, "target") then return "shoot" end

    if C_Spell.IsSpellInRange(AUTO_ATTACK, "target") then return "melee" end

    return "blocked"
end

local runner = CreateFrame("Frame", nil, UIParent)
runner:Hide()
runner:SetScript("OnUpdate", function(_, elapsed)
    if not helperFrame then helperFrame = createFrame() end

    sinceCheck = sinceCheck + elapsed
    if sinceCheck >= THROTTLE then
        sinceCheck = 0
        local state = rangeState()
        if state ~= lastState then
            lastState = state
            if state then
                local s = STATES[state]
                helperFrame.text:SetText(s.text)
                helperFrame.text:SetTextColor(unpack(s.color))
                helperFrame:Show()
                lastCx, lastCy = nil, nil
            else
                helperFrame:Hide()
            end
        end
    end

    if not helperFrame:IsShown() then return end

    -- Same cursor anchoring the mouse ring uses, so the two sit together.
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = x / scale, y / scale
    if cx ~= lastCx or cy ~= lastCy then
        helperFrame:ClearAllPoints()
        helperFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
        lastCx, lastCy = cx, cy
    end
end)

-- Called on load and whenever the setting changes.
function addon.MI_HunterHelper_SetEnabled()
    if addon.db.forever_hunterHelper_enabled and isHunter() then
        if not helperFrame then helperFrame = createFrame() end
        lastState = nil
        sinceCheck = THROTTLE
        runner:Show()
    else
        runner:Hide()
        if helperFrame then helperFrame:Hide() end
        lastState = nil
        lastCx, lastCy = nil, nil
    end
end

function addon.MI_HunterHelper_Init()
    addon.MI_HunterHelper_SetEnabled()
end
