local _, addon = ...

-- ── Spell IDs ────────────────────────────────────────────────────────────────
local VIGOR_SPELL          = 372608
local SECOND_WIND_SPELL    = 425782
local WHIRLING_SURGE_SPELL = 361584

-- ── Constants ────────────────────────────────────────────────────────────────
local NUM_CHARGES          = 6
local THROTTLE             = 0.0333   -- ~30 FPS
local MAX_SPEED            = 85       -- max forward speed for bar scaling
local SPEED_DISPLAY_FACTOR = 14.285   -- converts raw speed to the ~0-100% display range
local THRILL_THRESHOLD     = 6.003    -- Thrill of the Skies activates above this speed
local GROUND_SKIM_DURATION = 8.28     -- Ground Skimming buff duration in seconds
local BAR_TEXTURE          = [[Interface\Buttons\WHITE8x8]]

-- ── Teal color scheme ────────────────────────────────────────────────────────
local COLOR = {
    charge     = { r = 0.00, g = 0.80, b = 0.80 },  -- #00cccc teal
    thrill     = { r = 1.00, g = 0.66, b = 0.00 },  -- gold (thrill of flight)
    speed      = { r = 0.00, g = 0.60, b = 0.60 },  -- darker teal for speed bar
    secondWind = { r = 0.00, g = 0.55, b = 0.55 },  -- subtle teal
    bg         = { r = 0.10, g = 0.10, b = 0.10 },  -- dark background
    border     = { r = 0.00, g = 0.00, b = 0.00 },  -- black border
}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function IsSkyriding()
    if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return false end
    local _, canGlide = C_PlayerInfo.GetGlidingInfo()
    return canGlide == true
end

local function IsGliding()
    local gliding = C_PlayerInfo.GetGlidingInfo()
    return gliding
end

local function GetForwardSpeed()
    local _, _, spd = C_PlayerInfo.GetGlidingInfo()
    return spd or 0
end

local function GetVigorInfo()
    local data = C_Spell.GetSpellCharges(VIGOR_SPELL)
    if not data then return 0, 6, 0, 0, false, false end
    local isThrill = data.cooldownDuration > 0
        and data.cooldownDuration <= THRILL_THRESHOLD
    local isGroundSkim = math.abs(data.cooldownDuration - GROUND_SKIM_DURATION) < 0.05
        and not isThrill
    return data.currentCharges, data.maxCharges,
           data.cooldownStartTime, data.cooldownDuration,
           isThrill, isGroundSkim
end

local function GetSecondWindCharges()
    local data = C_Spell.GetSpellCharges(SECOND_WIND_SPELL)
    if not data then return 0 end
    return data.currentCharges
end

local function GetWhirlingSurgeCooldown()
    local data = C_Spell.GetSpellCooldown(WHIRLING_SURGE_SPELL)
    if not data then return 0, 0 end
    return data.startTime, data.duration
end

-- ── State ────────────────────────────────────────────────────────────────────

local prevSpeed      = 0
local elapsed        = 0
local lastColorState = nil

-- ── UI elements ──────────────────────────────────────────────────────────────

local updateFrame
local mainFrame, speedBar, speedText
local chargeBars     = {}
local chargeDividers = {}
local secondWindBars = {}
local surgeFrame, surgeCooldown, surgeBorder

-- ── Layout ───────────────────────────────────────────────────────────────────

local function UpdateLayout()
    if not mainFrame then return end

    local barWidth     = addon.db.ui_dragonriding_barWidth
    local speedHeight  = addon.db.ui_dragonriding_speedHeight
    local chargeHeight = addon.db.ui_dragonriding_chargeHeight
    local gap          = addon.db.ui_dragonriding_gap
    local borderSize   = 1

    local totalWidth  = NUM_CHARGES * barWidth + (NUM_CHARGES - 1) * gap
    local totalHeight = speedHeight + gap + chargeHeight

    mainFrame:SetSize(totalWidth + borderSize * 2, totalHeight + borderSize * 2)
    mainFrame:SetBackdrop({
        bgFile   = BAR_TEXTURE,
        edgeFile = BAR_TEXTURE,
        edgeSize = borderSize,
        insets   = { left = borderSize, right = borderSize, top = borderSize, bottom = borderSize },
    })
    mainFrame:SetBackdropColor(COLOR.bg.r, COLOR.bg.g, COLOR.bg.b, 0.8)
    mainFrame:SetBackdropBorderColor(COLOR.border.r, COLOR.border.g, COLOR.border.b, 1)

    -- Speed bar across top
    speedBar:ClearAllPoints()
    speedBar:SetSize(totalWidth, speedHeight)
    speedBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", borderSize, -borderSize)

    -- Speed text (right-aligned inside speed bar)
    speedText:ClearAllPoints()
    speedText:SetPoint("RIGHT", speedBar, "RIGHT", -4, 0)

    -- Charge bars below
    local chargeY = -(speedHeight + gap + borderSize)
    for i = 1, NUM_CHARGES do
        local xOff = borderSize + (i - 1) * (barWidth + gap)

        secondWindBars[i]:ClearAllPoints()
        secondWindBars[i]:SetSize(barWidth, chargeHeight)
        secondWindBars[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff, chargeY)

        chargeBars[i]:ClearAllPoints()
        chargeBars[i]:SetSize(barWidth, chargeHeight)
        chargeBars[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff, chargeY)

        if chargeDividers[i] then
            chargeDividers[i]:ClearAllPoints()
            chargeDividers[i]:SetSize(1, chargeHeight)
            chargeDividers[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff + barWidth, chargeY)
        end
    end

    -- Whirling Surge icon
    if surgeFrame then
        local iconSize = chargeHeight + speedHeight + gap
        surgeFrame:ClearAllPoints()
        surgeFrame:SetSize(iconSize, iconSize)
        surgeFrame:SetPoint("LEFT", mainFrame, "RIGHT", 4, 0)

        if surgeBorder then
            surgeBorder:ClearAllPoints()
            surgeBorder:SetPoint("TOPLEFT", surgeFrame, "TOPLEFT", -1, 1)
            surgeBorder:SetPoint("BOTTOMRIGHT", surgeFrame, "BOTTOMRIGHT", 1, -1)
            surgeBorder:SetBackdrop({ edgeFile = BAR_TEXTURE, edgeSize = 1 })
            surgeBorder:SetBackdropBorderColor(COLOR.border.r, COLOR.border.g, COLOR.border.b, 1)
        end
    end

    lastColorState = nil
end

-- ── Color application ────────────────────────────────────────────────────────

local function ApplyColors(isThrill)
    local state = "speed"
    if isThrill then state = "thrill" end
    if state == lastColorState then return end
    lastColorState = state

    if isThrill then
        speedBar:SetStatusBarColor(COLOR.thrill.r, COLOR.thrill.g, COLOR.thrill.b)
    else
        speedBar:SetStatusBarColor(COLOR.speed.r, COLOR.speed.g, COLOR.speed.b)
    end

    for i = 1, NUM_CHARGES do
        chargeBars[i]:SetStatusBarColor(COLOR.charge.r, COLOR.charge.g, COLOR.charge.b)
    end
end

-- ── Update functions ─────────────────────────────────────────────────────────

local function UpdateSpeedBar(rawSpeed)
    local scaled = math.min(rawSpeed / MAX_SPEED, 1.0)
    prevSpeed = prevSpeed + (scaled - prevSpeed) * 0.15
    speedBar:SetValue(prevSpeed)

    if addon.db.ui_dragonriding_showSpeed then
        local display = math.floor(rawSpeed * SPEED_DISPLAY_FACTOR)
        if display > 0 then
            speedText:SetText(tostring(display))
        else
            speedText:SetText("")
        end
    else
        speedText:SetText("")
    end
end

local function UpdateCharges(charges, maxCharges, startTime, duration)
    local now = GetTime()
    for i = 1, NUM_CHARGES do
        if i > maxCharges then
            chargeBars[i]:SetValue(0)
        elseif i <= charges then
            chargeBars[i]:SetValue(1)
        elseif i == charges + 1 and duration > 0 and startTime > 0 then
            local progress = (now - startTime) / duration
            chargeBars[i]:SetValue(math.min(progress, 1))
        else
            chargeBars[i]:SetValue(0)
        end
    end
end

local function UpdateSecondWind(charges, totalFilled)
    if not addon.db.ui_dragonriding_showSecondWind then
        for i = 1, NUM_CHARGES do
            secondWindBars[i]:SetValue(0)
        end
        return
    end
    for i = 1, NUM_CHARGES do
        if i <= totalFilled then
            secondWindBars[i]:SetValue(1)
        else
            secondWindBars[i]:SetValue(0)
        end
    end
end

local function UpdateWhirlingSurge(startTime, duration)
    if not addon.db.ui_dragonriding_showWhirlingSurge or not surgeFrame then
        if surgeFrame then surgeFrame:Hide() end
        return
    end
    surgeFrame:Show()
    if startTime > 0 and duration > 0 then
        surgeCooldown:SetCooldown(startTime, duration)
    end
end

-- ── Main OnUpdate ────────────────────────────────────────────────────────────

local function OnUpdate(self, dt)
    elapsed = elapsed + dt
    if elapsed < THROTTLE then return end
    elapsed = 0

    if not mainFrame or not speedBar then return end

    if not addon.db.ui_dragonriding_enabled or not IsSkyriding() then
        mainFrame:Hide()
        if surgeFrame then surgeFrame:Hide() end
        prevSpeed = 0
        lastColorState = nil
        return
    end

    local charges, maxCharges, startTime, duration, isThrill, isGroundSkim = GetVigorInfo()

    if addon.db.ui_dragonriding_hideGroundedFull and not IsGliding() and charges >= maxCharges then
        mainFrame:Hide()
        if surgeFrame then surgeFrame:Hide() end
        return
    end

    mainFrame:Show()

    UpdateSpeedBar(GetForwardSpeed())
    UpdateCharges(charges, maxCharges, startTime, duration)
    ApplyColors(isThrill)

    if addon.db.ui_dragonriding_showSecondWind then
        local swCharges = GetSecondWindCharges()
        UpdateSecondWind(charges, charges + swCharges)
    else
        UpdateSecondWind(0, 0)
    end

    if addon.db.ui_dragonriding_showWhirlingSurge then
        local sStart, sDur = GetWhirlingSurgeCooldown()
        UpdateWhirlingSurge(sStart, sDur)
    else
        UpdateWhirlingSurge(0, 0)
    end
end

-- ── Build UI ─────────────────────────────────────────────────────────────────

local function BuildUI()
    mainFrame = CreateFrame("Frame", "MysteriousQoL_Dragonriding", UIParent, "BackdropTemplate")
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(100)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        addon.db.ui_dragonriding_posPoint = point
        addon.db.ui_dragonriding_posX = x
        addon.db.ui_dragonriding_posY = y
    end)

    -- Restore saved position
    local point = addon.db.ui_dragonriding_posPoint or "BOTTOM"
    local x = addon.db.ui_dragonriding_posX or 0
    local y = addon.db.ui_dragonriding_posY or 200
    mainFrame:SetPoint(point, UIParent, point, x, y)
    mainFrame:Hide()

    -- Speed bar
    speedBar = CreateFrame("StatusBar", nil, mainFrame)
    speedBar:SetStatusBarTexture(BAR_TEXTURE)
    speedBar:SetMinMaxValues(0, 1)
    speedBar:SetValue(0)
    speedBar:SetStatusBarColor(COLOR.speed.r, COLOR.speed.g, COLOR.speed.b)

    speedText = speedBar:CreateFontString(nil, "OVERLAY")
    speedText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    speedText:SetJustifyH("RIGHT")
    speedText:SetJustifyV("MIDDLE")
    speedText:SetText("")

    -- Charge bars + second wind + dividers
    local dividerFrame = CreateFrame("Frame", nil, mainFrame)
    dividerFrame:SetAllPoints()
    dividerFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 5)

    for i = 1, NUM_CHARGES do
        local sw = CreateFrame("StatusBar", nil, mainFrame)
        sw:SetStatusBarTexture(BAR_TEXTURE)
        sw:SetMinMaxValues(0, 1)
        sw:SetValue(0)
        sw:SetStatusBarColor(COLOR.secondWind.r, COLOR.secondWind.g, COLOR.secondWind.b, 0.5)
        secondWindBars[i] = sw

        local cb = CreateFrame("StatusBar", nil, mainFrame)
        cb:SetStatusBarTexture(BAR_TEXTURE)
        cb:SetMinMaxValues(0, 1)
        cb:SetValue(0)
        cb:SetFrameLevel(sw:GetFrameLevel() + 1)
        cb:SetStatusBarColor(COLOR.charge.r, COLOR.charge.g, COLOR.charge.b)
        chargeBars[i] = cb

        if i < NUM_CHARGES then
            local divider = dividerFrame:CreateTexture(nil, "OVERLAY")
            divider:SetColorTexture(0, 0, 0, 1)
            chargeDividers[i] = divider
        end
    end

    -- Whirling Surge icon
    surgeFrame = CreateFrame("Frame", nil, mainFrame)
    surgeFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 2)

    local icon = C_Spell.GetSpellTexture(WHIRLING_SURGE_SPELL) or 134400
    local surgeIcon = surgeFrame:CreateTexture(nil, "ARTWORK")
    surgeIcon:SetAllPoints()
    surgeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    surgeIcon:SetTexture(icon)

    surgeCooldown = CreateFrame("Cooldown", nil, surgeFrame, "CooldownFrameTemplate")
    surgeCooldown:SetAllPoints()
    surgeCooldown:SetDrawEdge(false)
    surgeCooldown:SetDrawBling(false)
    surgeCooldown:SetSwipeColor(0, 0, 0, 0.8)
    surgeCooldown:SetHideCountdownNumbers(false)

    surgeBorder = CreateFrame("Frame", nil, surgeFrame, "BackdropTemplate")
    surgeBorder:SetFrameLevel(surgeFrame:GetFrameLevel() + 3)

    UpdateLayout()
end

-- ── Init ─────────────────────────────────────────────────────────────────────

local function StartUpdating()
    if updateFrame then return end
    BuildUI()
    updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", OnUpdate)
end

local function StopUpdating()
    if not updateFrame then return end
    updateFrame:SetScript("OnUpdate", nil)
    updateFrame:Hide()
    updateFrame = nil
    if mainFrame then mainFrame:Hide() end
    if surgeFrame then surgeFrame:Hide() end
    prevSpeed = 0
    lastColorState = nil
end

function addon.MI_Dragonriding_Init()
    if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return end
    if addon.db.ui_dragonriding_enabled then
        StartUpdating()
    end
end

-- Called by settings UI when the toggle changes
function addon.MI_Dragonriding_SetEnabled(v)
    if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return end
    if v then StartUpdating() else StopUpdating() end
end
