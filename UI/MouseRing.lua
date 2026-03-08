local addonName, addon = ...

-- A configurable ring that follows the cursor.
-- Cast progress: a second ring sweeps along the outside to show cast/channel progress.
-- Textures are borrowed from EnhanceQoL (Mouse.tga / Dot.tga).

local RING_TEX = "Interface\\AddOns\\MysteriousQoL\\Assets\\Mouse.tga"
local DOT_TEX  = "Interface\\AddOns\\MysteriousQoL\\Assets\\Dot.tga"

-- ── Runtime state ─────────────────────────────────────────────────────────────

local ringFrame = nil

-- Cached "last applied" values to detect setting changes without full reapply each frame
local lastSize       = nil
local lastClassColor = nil
local lastHideDot    = nil

-- Cast progress state
local castStart        = 0
local castEnd          = 0
local castIsChannel    = false
local castActive       = false
local castRingSetStart = nil  -- castStart value we last passed to SetCooldown

-- ── Helpers ───────────────────────────────────────────────────────────────────

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

-- ── Ring frame ────────────────────────────────────────────────────────────────

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

    -- Cast progress: a CooldownFrameTemplate swipe ring parented to UIParent so it
    -- can be sized larger than the main ring. Repositioned every frame alongside it.
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

    -- Cast ring: sized slightly larger than the main ring and tinted with ring color
    if ringFrame.castRing then
        local castSize = size + math.max(16, math.floor(size * 0.32 + 0.5))
        ringFrame.castRing:SetSize(castSize, castSize)
        ringFrame.castRing:SetSwipeColor(r, g, b, 0.75)
    end

    if ringFrame.dot then
        if db.ui_mouseRing_hideDot then ringFrame.dot:Hide() else ringFrame.dot:Show() end
    end

    lastSize       = size
    lastClassColor = db.ui_mouseRing_useClassColor
    lastHideDot    = db.ui_mouseRing_hideDot
end

-- ── Cast polling ──────────────────────────────────────────────────────────────

local function pollCast()
    local name, _, _, startMS, endMS = UnitCastingInfo("player")
    if name then
        castActive, castStart, castEnd, castIsChannel = true, startMS, endMS, false
        return
    end
    local chanName, _, _, startMS2, endMS2 = UnitChannelInfo("player")
    if chanName then
        castActive, castStart, castEnd, castIsChannel = true, startMS2, endMS2, true
        return
    end
    castActive = false
end

-- ── OnUpdate runner ───────────────────────────────────────────────────────────
-- Parented to UIParent so it is always available; only runs when shown.

local runner = CreateFrame("Frame", nil, UIParent)
runner:Hide()
runner:SetScript("OnUpdate", function()
    local db = addon.db

    -- Lazy creation
    if not ringFrame then ringFrame = createRingFrame() end

    -- Visibility
    local show = isRingVisible()
    if not show then
        if ringFrame:IsShown() then
            ringFrame:Hide()
            ringFrame.castRing:Hide()
            castRingSetStart = nil
        end
        return
    end
    if not ringFrame:IsShown() then ringFrame:Show() end

    -- Follow cursor
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local cx = x / scale
    local cy = y / scale
    ringFrame:ClearAllPoints()
    ringFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    -- Cast ring follows the same point (it's independently sized)
    ringFrame.castRing:ClearAllPoints()
    ringFrame.castRing:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)

    -- Detect style changes
    local size    = tonumber(db.ui_mouseRing_size) or 70
    local cls     = db.ui_mouseRing_useClassColor
    local hideDot = db.ui_mouseRing_hideDot
    if lastSize ~= size or lastClassColor ~= cls or lastHideDot ~= hideDot then
        applyRingStyle()
    end

    -- Cast progress ring (swipe)
    if db.ui_mouseRing_castProgress then
        pollCast()
        if castActive and castStart and castEnd then
            local nowMS = GetTime() * 1000
            local dur   = castEnd - castStart
            if dur > 0 and nowMS < castEnd then
                if castRingSetStart ~= castStart then
                    castRingSetStart = castStart
                    -- Casts fill 0→100% (SetReverse true); channels drain 100→0% (false)
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

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

local function enableRing()
    if not ringFrame then ringFrame = createRingFrame() end
    applyRingStyle()
    runner:Show()
end

local function disableRing()
    runner:Hide()
    if ringFrame then
        ringFrame:Hide()
        ringFrame.castRing:Hide()
    end
    castRingSetStart = nil
end

-- Refresh ring visibility when combat state changes (for "only in combat" mode)
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evtFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evtFrame:SetScript("OnEvent", function()
    if addon.db.ui_mouseRing_enabled and addon.db.ui_mouseRing_onlyInCombat then
        if not runner:IsShown() then runner:Show() end
    end
end)

-- Called from MysteriousQoL.lua after InitDB.
function addon.MI_MouseRing_Init()
    if addon.db.ui_mouseRing_enabled then
        enableRing()
    end
end

-- ── Settings ──────────────────────────────────────────────────────────────────

function addon.MI_MouseRing_RegisterSettings(uiCat)
    addon.settings.Checkbox(
        uiCat, "ui_mouseRing_enabled", "Mouse Ring",
        "Shows a configurable ring around your cursor.",
        function(v) if v then enableRing() else disableRing() end end
    )
    addon.settings.Slider(
        uiCat, "ui_mouseRing_size", "Ring Size",
        { min = 20, max = 200, step = 1 },
        nil,
        function() applyRingStyle() end
    )
    addon.settings.Checkbox(
        uiCat, "ui_mouseRing_hideDot", "Hide Center Dot",
        nil,
        function() applyRingStyle() end
    )
    addon.settings.Checkbox(
        uiCat, "ui_mouseRing_onlyInCombat", "Only Show In Combat",
        nil
    )
    addon.settings.Checkbox(
        uiCat, "ui_mouseRing_onlyOnRightClick", "Only Show On Right-Click",
        "Ring is visible only while the right mouse button is held."
    )
    addon.settings.Checkbox(
        uiCat, "ui_mouseRing_useClassColor", "Use Class Color",
        nil,
        function() applyRingStyle() end
    )
    addon.settings.Checkbox(
        uiCat, "ui_mouseRing_castProgress", "Show Cast Progress",
        "A ring sweeps along the outside to show cast or channel progress."
    )
end
