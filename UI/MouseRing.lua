local addonName, addon = ...

-- Ring that follows the cursor, with an optional outer ring that fills while
-- you cast. Mouse.tga and Dot.tga are from EnhanceQoL.

local RING_TEX = "Interface\\AddOns\\MysteriousQoL\\Assets\\Mouse.tga"
local DOT_TEX  = "Interface\\AddOns\\MysteriousQoL\\Assets\\Dot.tga"

local ringFrame = nil

-- Last applied style, so it's only reapplied when a setting changes
local lastSize       = nil
local lastClassColor = nil
local lastHideDot    = nil

local lastCx, lastCy = nil, nil

local castStart        = 0
local castEnd          = 0
local castIsChannel    = false
local castActive       = false
local castRingSetStart = nil  -- castStart value we last passed to SetCooldown

local function getRingColor()
    if addon.db.ui_mouseRing_useClassColor then
        local _, class = UnitClass("player")
        if class then
            local r, g, b = GetClassColor(class)
            if r then return r, g, b end
        end
    end
    return 1, 1, 1
end

local function isRingVisible()
    if not addon.db.ui_mouseRing_enabled then return false end
    if addon.db.ui_mouseRing_onlyInCombat and not UnitAffectingCombat("player") then return false end
    if addon.db.ui_mouseRing_onlyOnRightClick and not IsMouseButtonDown("RightButton") then return false end
    return true
end

local function createRingFrame()
    local f = CreateFrame("Frame", "MysteriousQoL_MouseRingFrame", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(false)
    f:SetSize(addon.db.ui_mouseRing_size or 70, addon.db.ui_mouseRing_size or 70)

    local ring = f:CreateTexture(nil, "BACKGROUND")
    ring:SetTexture(RING_TEX)
    ring:SetAllPoints()
    f.ring = ring

    local dot = f:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(DOT_TEX)
    dot:SetSize(10, 10)
    dot:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.dot = dot

    -- Cast ring is a cooldown swipe on UIParent so it can be bigger than the ring.
    local castRing = CreateFrame("Cooldown", "MysteriousQoL_CastRing", UIParent, "CooldownFrameTemplate")
    castRing:SetFrameStrata("TOOLTIP")
    castRing:SetDrawSwipe(true)
    castRing:SetDrawEdge(false)
    castRing:SetDrawBling(false)
    castRing:SetHideCountdownNumbers(true)
    castRing:SetSwipeTexture(RING_TEX)
    castRing:SetSwipeColor(1, 1, 1, 0.75)
    castRing:Hide()
    f.castRing = castRing

    return f
end

local function applyRingStyle()
    if not ringFrame then return end
    local db = addon.db
    local size = tonumber(db.ui_mouseRing_size) or 70

    ringFrame:SetSize(size, size)

    local r, g, b = getRingColor()
    ringFrame.ring:SetVertexColor(r, g, b, 1)

    if ringFrame.castRing then
        local castSize = size + math.max(16, math.floor(size * 0.32 + 0.5))
        ringFrame.castRing:SetSize(castSize, castSize)
        ringFrame.castRing:SetSwipeColor(r, g, b, 0.75)
    end

    if ringFrame.dot then
        ringFrame.dot:SetVertexColor(r, g, b, 1)
        if db.ui_mouseRing_hideDot then ringFrame.dot:Hide() else ringFrame.dot:Show() end
    end

    lastSize       = size
    lastClassColor = db.ui_mouseRing_useClassColor
    lastHideDot    = db.ui_mouseRing_hideDot
end

local function pollCast()
    local name, _, _, startMS, endMS = UnitCastingInfo("player")
    if name then
        castActive, castStart, castEnd, castIsChannel = true, startMS, endMS, false
        return
    end
    name, _, _, startMS, endMS = UnitChannelInfo("player")
    if name then
        castActive, castStart, castEnd, castIsChannel = true, startMS, endMS, true
        return
    end
    castActive = false
end

local runner = CreateFrame("Frame", nil, UIParent)
runner:Hide()
runner:SetScript("OnUpdate", function()
    local db = addon.db

    if not ringFrame then ringFrame = createRingFrame() end

    local show = isRingVisible()
    if not show then
        if ringFrame:IsShown() then
            ringFrame:Hide()
            ringFrame.castRing:Hide()
            castRingSetStart = nil
            lastCx, lastCy = nil, nil
        end
        return
    end
    if not ringFrame:IsShown() then
        ringFrame:Show()
        lastCx, lastCy = nil, nil
    end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local cx = x / scale
    local cy = y / scale
    if cx ~= lastCx or cy ~= lastCy then
        ringFrame:ClearAllPoints()
        ringFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
        ringFrame.castRing:ClearAllPoints()
        ringFrame.castRing:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
        lastCx, lastCy = cx, cy
    end

    local size    = tonumber(db.ui_mouseRing_size) or 70
    local cls     = db.ui_mouseRing_useClassColor
    local hideDot = db.ui_mouseRing_hideDot
    if lastSize ~= size or lastClassColor ~= cls or lastHideDot ~= hideDot then
        applyRingStyle()
    end

    -- castActive comes from the cast events further down
    if db.ui_mouseRing_castProgress then
        if castActive and castStart and castEnd then
            local nowMS = GetTime() * 1000
            local dur   = castEnd - castStart
            if dur > 0 and nowMS < castEnd then
                if castRingSetStart ~= castStart then
                    castRingSetStart = castStart
                    -- casts fill up, channels drain
                    ringFrame.castRing:SetReverse(not castIsChannel)
                    ringFrame.castRing:SetCooldown(castStart / 1000, dur / 1000)
                    ringFrame.castRing:Show()
                end
            else
                castRingSetStart = nil
                castActive = false
                ringFrame.castRing:Hide()
            end
        else
            castRingSetStart = nil
            ringFrame.castRing:Hide()
        end
    else
        castRingSetStart = nil
        ringFrame.castRing:Hide()
    end
end)

local function hideRingVisuals()
    if ringFrame then
        ringFrame:Hide()
        ringFrame.castRing:Hide()
    end
    castRingSetStart = nil
    lastCx, lastCy = nil, nil
end

local function refreshRunnerVisibility()
    local db = addon.db
    local shouldRun = db.ui_mouseRing_enabled
        and (not db.ui_mouseRing_onlyInCombat or UnitAffectingCombat("player"))

    if shouldRun then
        runner:Show()
    else
        runner:Hide()
        hideRingVisuals()
    end
end

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_EMPOWER_UPDATE",
}
local castFrame = CreateFrame("Frame")
castFrame:SetScript("OnEvent", pollCast)

local function enableRing()
    if not ringFrame then ringFrame = createRingFrame() end
    for _, event in ipairs(CAST_EVENTS) do
        pcall(castFrame.RegisterUnitEvent, castFrame, event, "player")
    end
    pollCast()
    applyRingStyle()
    refreshRunnerVisibility()
end

local function disableRing()
    castFrame:UnregisterAllEvents()
    castActive = false
    runner:Hide()
    hideRingVisuals()
end

-- For "only in combat"
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evtFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evtFrame:SetScript("OnEvent", function()
    refreshRunnerVisibility()
end)

function addon.MI_MouseRing_SetEnabled(v)
    if v then enableRing() else disableRing() end
end
function addon.MI_MouseRing_ApplyStyle()
    applyRingStyle()
end
function addon.MI_MouseRing_RefreshVisibility()
    refreshRunnerVisibility()
end

function addon.MI_MouseRing_Init()
    if addon.db.ui_mouseRing_enabled then
        enableRing()
    end
end
