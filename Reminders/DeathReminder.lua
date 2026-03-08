local _, addon = ...

local sin             = math.sin
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

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

-- ── Death display frame (large bouncing text) ──────────────────────────────────

local DEATH_BASE_Y = 0
local DEATH_BOUNCE = 8
local DEATH_SPEED  = 3.0

local deathFrame = CreateFrame("Frame", "MysteriousQoL_DeathReminderFrame", UIParent)
deathFrame:SetSize(600, 80)
deathFrame:SetPoint("CENTER", UIParent, "CENTER", 0, DEATH_BASE_Y)
deathFrame:SetFrameStrata("HIGH")
deathFrame:Hide()

local deathText = deathFrame:CreateFontString(nil, "OVERLAY")
deathText:SetAllPoints()
deathText:SetJustifyH("CENTER")
deathText:SetJustifyV("MIDDLE")
deathText:SetFont("Fonts\\FRIZQT__.TTF", 40, "THICKOUTLINE")
deathText:SetTextColor(1, 0.15, 0.15, 1)
deathText:SetShadowColor(0, 0, 0, 1)
deathText:SetShadowOffset(3, -3)
deathText:SetText("Don't release you dolt!")

local deathBounceT = 0
deathFrame:SetScript("OnUpdate", function(self, elapsed)
    deathBounceT = deathBounceT + elapsed
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, DEATH_BASE_Y + sin(deathBounceT * DEATH_SPEED) * DEATH_BOUNCE)
end)

-- ── Update ─────────────────────────────────────────────────────────────────────

function addon.MI_DeathReminder_Update()
    if getDeathReminder() then
        deathFrame:Show()
    else
        deathBounceT = 0
        deathFrame:Hide()
    end
end

-- ── Settings ───────────────────────────────────────────────────────────────────

function addon.MI_DeathReminder_RegisterSettings(cat, layout)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Death"))
    addon.settings.Checkbox(
        cat, "combat_deathReminder_enabled", "Don't Release Reminder",
        "Shows a large center-screen warning when you die in a raid instance to stop you releasing.",
        function() addon.MI_DeathReminder_Update() end
    )
end
