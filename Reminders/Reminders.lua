local _, addon = ...

-- Center-screen reminders for:
--   • Missing class buff (buff-providing classes only)
--   • No active pet (Warlock / Hunter BM+Survival)
--   • Pet idle in combat (same classes)

local sin              = math.sin
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsDeadOrGhost   = UnitIsDeadOrGhost

-- ── Class buff table ───────────────────────────────────────────────────────────

local CLASS_BUFFS = {
    DRUID   = { spellID = 1126,   label = "Mark of the Wild" },
    MAGE    = { spellID = 1459,   label = "Arcane Intellect" },
    PRIEST  = { spellID = 21562,  label = "Power Word: Fortitude" },
    WARRIOR = { spellID = 6673,   label = "Battle Shout" },
    EVOKER  = { spellID = 381732, label = "Blessing of the Bronze" },
    SHAMAN  = { spellID = 462854, label = "Skyfury" },
}

-- Hunter specs that require a pet (Beast Mastery = 253, Survival = 255)
local HUNTER_PET_SPECS = { [253] = true, [255] = true }

-- Cached at init time — class never changes mid-session
local playerClass

-- ── Suppression helpers ────────────────────────────────────────────────────────

local function isSuppressed()
    return UnitIsDeadOrGhost("player")
        or IsMounted()
        or UnitHasVehicleUI("player")
        or UnitOnTaxi("player")
end

-- ── Buff check helpers ─────────────────────────────────────────────────────────

local function unitHasBuff(unit, spellID)
    local found = false
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(auraData)
        if auraData.spellId == spellID then
            found = true
            return true  -- stops iteration
        end
    end, true)  -- usePackedAura = true
    return found
end

local function anyoneMissingBuff(spellID)
    if not C_UnitAuras.GetPlayerAuraBySpellID(spellID) then return true end
    local numMembers = GetNumGroupMembers()
    if numMembers > 0 then
        local inRaid = IsInRaid()
        for i = 1, numMembers do
            local unit = inRaid and ("raid" .. i) or ("party" .. i)
            if UnitExists(unit) and UnitIsConnected(unit) and not unitHasBuff(unit, spellID) then
                return true
            end
        end
    end
    return false
end

-- ── Buff reminder ──────────────────────────────────────────────────────────────

local function getBuffReminder()
    if not addon.db.combat_buffReminder_enabled then return nil end
    local entry = CLASS_BUFFS[playerClass]
    if not entry then return nil end
    if isSuppressed() then return nil end
    if not anyoneMissingBuff(entry.spellID) then return nil end
    return entry
end

-- ── Pet reminder ───────────────────────────────────────────────────────────────

local function isPetExpected()
    if playerClass == "WARLOCK" then return true end
    if playerClass == "HUNTER" then
        local specIndex = GetSpecialization()
        local specID = specIndex and GetSpecializationInfo(specIndex)
        return HUNTER_PET_SPECS[specID] == true
    end
    return false
end

-- Returns a message string if a pet warning should show, nil otherwise.
local function getPetMessage()
    if not isPetExpected() then return nil end
    if isSuppressed() then return nil end

    local petAlive = UnitExists("pet") and not UnitIsDeadOrGhost("pet")

    if not petAlive then
        if addon.db.combat_petReminder_enabled then
            return "No Pet"
        end
    elseif addon.db.combat_petIdleReminder_enabled
        and UnitAffectingCombat("player")
        and not UnitAffectingCombat("pet")
    then
        return "Pet Idle!"
    end

    return nil
end

-- ── Buff display frame (icon + pulsing glow) ───────────────────────────────────

local BUFF_ICON_SIZE = 52

local buffFrame = CreateFrame("Frame", "MysteriousQoL_BuffReminderFrame", UIParent)
buffFrame:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
buffFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 105)
buffFrame:SetFrameStrata("MEDIUM")
buffFrame:Hide()

local buffIcon = buffFrame:CreateTexture(nil, "ARTWORK")
buffIcon:SetAllPoints()
buffIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local buffPulse = buffFrame:CreateAnimationGroup()
buffPulse:SetLooping("REPEAT")
local _p1 = buffPulse:CreateAnimation("Alpha")
_p1:SetFromAlpha(0.35)
_p1:SetToAlpha(1.0)
_p1:SetDuration(0.55)
_p1:SetOrder(1)
local _p2 = buffPulse:CreateAnimation("Alpha")
_p2:SetFromAlpha(1.0)
_p2:SetToAlpha(0.35)
_p2:SetDuration(0.55)
_p2:SetOrder(2)

-- ── Pet display frame (bouncing text) ──────────────────────────────────────────

local PET_BASE_Y = 155
local PET_BOUNCE = 6
local PET_SPEED  = 2.5

local petFrame = CreateFrame("Frame", "MysteriousQoL_PetReminderFrame", UIParent)
petFrame:SetSize(400, 50)
petFrame:SetPoint("CENTER", UIParent, "CENTER", 0, PET_BASE_Y)
petFrame:SetFrameStrata("MEDIUM")
petFrame:Hide()

local petText = petFrame:CreateFontString(nil, "OVERLAY")
petText:SetAllPoints()
petText:SetJustifyH("CENTER")
petText:SetJustifyV("MIDDLE")
petText:SetFont("Fonts\\FRIZQT__.TTF", 26, "THICKOUTLINE")
petText:SetTextColor(1, 0.2, 0.2, 1)
petText:SetShadowColor(0, 0, 0, 1)
petText:SetShadowOffset(2, -2)

local bounceT = 0
petFrame:SetScript("OnUpdate", function(self, elapsed)
    bounceT = bounceT + elapsed
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, PET_BASE_Y + sin(bounceT * PET_SPEED) * PET_BOUNCE)
end)

-- ── Update logic ───────────────────────────────────────────────────────────────

local function updateReminders()
    local entry = getBuffReminder()
    if entry then
        local spellInfo = C_Spell.GetSpellInfo(entry.spellID)
        if spellInfo then
            buffIcon:SetTexture(spellInfo.iconID)
        end
        buffPulse:Play()
        buffFrame:Show()
    else
        buffPulse:Stop()
        buffFrame:SetAlpha(1)
        buffFrame:Hide()
    end

    local petMsg = getPetMessage()
    if petMsg then
        petText:SetText(petMsg)
        petFrame:Show()
    else
        bounceT = 0
        petFrame:Hide()
    end
end

-- ── Event handling ─────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_AURA",           "player")
eventFrame:RegisterUnitEvent("UNIT_PET",            "player")
eventFrame:RegisterUnitEvent("UNIT_FLAGS",          "player", "pet")
eventFrame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE","player")
eventFrame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
eventFrame:SetScript("OnEvent", function() updateReminders() end)

-- ── Lifecycle ──────────────────────────────────────────────────────────────────

function addon.MI_Reminders_Init()
    local _, class = UnitClass("player")
    playerClass = class
    -- Fallback ticker for taxi and edge cases not covered by events
    C_Timer.NewTicker(5, updateReminders)
    updateReminders()
end

-- ── Settings ───────────────────────────────────────────────────────────────────

function addon.MI_Reminders_RegisterSettings(combatCat, combatLayout)
    local function Header(title)
        combatLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
    end

    Header("Class Buff")
    addon.settings.Checkbox(
        combatCat, "combat_buffReminder_enabled", "Class Buff Reminder",
        "Shows a glowing icon when your class buff is missing from you or any group member.",
        function() updateReminders() end
    )

    Header("Pet")
    addon.settings.Checkbox(
        combatCat, "combat_petReminder_enabled", "No Pet Reminder",
        "Shows a center-screen warning when you have no active pet (Warlock, Hunter BM/Survival).",
        function() updateReminders() end
    )
    addon.settings.Checkbox(
        combatCat, "combat_petIdleReminder_enabled", "Pet Idle Reminder",
        "Shows a center-screen warning when your pet is alive but not attacking while you are in combat.",
        function() updateReminders() end
    )
end
