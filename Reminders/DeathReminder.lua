local _, addon = ...

-- ── Death check ────────────────────────────────────────────────────────────────

local function getDeathReminder()
    if not addon.db.combat_deathReminder_enabled then return false end
    if not UnitIsDeadOrGhost("player") then return false end
    if not IsInRaid() then return false end
    local _, instanceType, difficultyID = GetInstanceInfo()
    if instanceType ~= "raid" then return false end
    local isLFR = select(8, GetDifficultyInfo(difficultyID))
    return not isLFR
end

-- ── Display frame ──────────────────────────────────────────────────────────────

local deathFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_DeathReminderFrame", {
    baseY    = 0,
    bounce   = 8,
    speed    = 3.0,
    fontSize = 40,
    color    = { 1, 0.15, 0.15, 1 },
    shadow   = { 3, -3 },
    width    = 600,
    height   = 80,
    strata   = "HIGH",
    text     = "Don't release you dolt!",
})

-- ── Release Protection (Alt-hold blocker) ───────────────────────────────────────

local HOLD_DURATION = 1.0

local blocker = CreateFrame("Frame", "MysteriousQoL_ReleaseBlocker", UIParent, "BackdropTemplate")
blocker:SetFrameStrata("DIALOG")
blocker:SetFrameLevel(999)
blocker:Hide()

local blockerText = blocker:CreateFontString(nil, "OVERLAY")
blockerText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
blockerText:SetPoint("CENTER")
blockerText:SetTextColor(1, 0.65, 0, 1)  -- orange

local holdElapsed = 0
local holding = false

blocker:SetScript("OnUpdate", function(self, dt)
    if IsAltKeyDown() then
        if not holding then
            holding = true
            holdElapsed = 0
        end
        holdElapsed = holdElapsed + dt
        local remaining = HOLD_DURATION - holdElapsed
        if remaining <= 0 then
            blockerText:SetText("RELEASE")
            blockerText:SetTextColor(0, 0.8, 0.8, 1)  -- teal when ready
            self:EnableMouse(false)
        else
            blockerText:SetText(string.format("Hold Alt: %.1f", remaining))
        end
    else
        holding = false
        holdElapsed = 0
        blockerText:SetText("Hold Alt to Release")
        blockerText:SetTextColor(1, 0.65, 0, 1)
        self:EnableMouse(true)
    end
end)

local function shouldBlockRelease()
    if not addon.db.combat_deathReleaseProtection then return false end
    if not UnitIsDeadOrGhost("player") then return false end
    if not (IsInGroup() or IsInRaid()) then return false end
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party" or instanceType == "raid"
end

local function UpdateBlocker()
    if shouldBlockRelease() then
        local popup = StaticPopup_FindVisible("DEATH")
        if popup and popup.button1 then
            blocker:ClearAllPoints()
            blocker:SetAllPoints(popup.button1)
            blocker:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            })
            blocker:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
            blocker:EnableMouse(true)
            blocker:Show()
            holding = false
            holdElapsed = 0
            blockerText:SetText("Hold Alt to Release")
            blockerText:SetTextColor(1, 0.65, 0, 1)
        end
    else
        blocker:Hide()
    end
end

local blockerEvents = CreateFrame("Frame")
blockerEvents:RegisterEvent("PLAYER_DEAD")
blockerEvents:RegisterEvent("PLAYER_ALIVE")
blockerEvents:RegisterEvent("PLAYER_UNGHOST")
blockerEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_DEAD" then
        C_Timer.After(0.1, UpdateBlocker)
    else
        blocker:Hide()
    end
end)

-- ── Update ─────────────────────────────────────────────────────────────────────

function addon.MI_DeathReminder_Update()
    if getDeathReminder() then
        deathFrame:Show()
    else
        deathFrame.ResetBounce()
        deathFrame:Hide()
    end
end
