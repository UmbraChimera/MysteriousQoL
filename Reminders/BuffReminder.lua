local _, addon = ...

local UnitIsDeadOrGhost = UnitIsDeadOrGhost

-- ── Class buff table ───────────────────────────────────────────────────────────

local CLASS_BUFFS = {
    DRUID   = { spellID = 1126,   label = "Mark of the Wild" },
    MAGE    = { spellID = 1459,   label = "Arcane Intellect" },
    PRIEST  = { spellID = 21562,  label = "Power Word: Fortitude" },
    WARRIOR = { spellID = 6673,   label = "Battle Shout" },
    EVOKER  = { spellID = 381732, label = "Blessing of the Bronze" },
    SHAMAN  = { spellID = 462854, label = "Skyfury" },
}

-- ── Suppression helper ─────────────────────────────────────────────────────────

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

local function getBuffReminder()
    if not addon.db.combat_buffReminder_enabled then return nil end
    local entry = CLASS_BUFFS[addon.playerClass]
    if not entry then return nil end
    if isSuppressed() then return nil end
    if not anyoneMissingBuff(entry.spellID) then return nil end
    return entry
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

-- ── Update ─────────────────────────────────────────────────────────────────────

function addon.MI_BuffReminder_Update()
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
end

-- ── Settings ───────────────────────────────────────────────────────────────────

function addon.MI_BuffReminder_RegisterSettings(cat, layout)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Class Buff"))
    addon.settings.Checkbox(
        cat, "combat_buffReminder_enabled", "Class Buff Reminder",
        "Shows a glowing icon when your class buff is missing from you or any group member.",
        function() addon.MI_BuffReminder_Update() end
    )
end
