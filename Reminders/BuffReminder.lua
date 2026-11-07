local _, addon = ...

local CLASS_BUFFS = {
    DRUID   = { spellID = 1126 },
    MAGE    = { spellID = 1459 },
    PRIEST  = { spellID = 21562 },
    WARRIOR = { spellID = 6673 },
    EVOKER  = { spellID = 381732 },
    SHAMAN  = { spellID = 462854 },
}

local function isSuppressed()
    return UnitIsDeadOrGhost("player")
        or IsMounted()
        or IsFlying()
        or UnitHasVehicleUI("player")
        or UnitOnTaxi("player")
        or IsResting()
end

local function anyoneMissingBuff(spellID)
    if not C_UnitAuras.GetPlayerAuraBySpellID(spellID) then return true end
    local spellName = C_Spell.GetSpellName(spellID)
    if not spellName then return true end
    local numMembers = GetNumGroupMembers()
    if numMembers > 0 and IsInInstance() then
        local inRaid = IsInRaid()
        for i = 1, numMembers do
            local unit = inRaid and ("raid" .. i) or ("party" .. i)
            if UnitExists(unit) and UnitIsConnected(unit)
                and not C_UnitAuras.GetAuraDataBySpellName(unit, spellName, "HELPFUL") then
                return true
            end
        end
    end
    return false
end

local function getBuffReminder()
    if not addon.RETAIL then return nil end
    if not addon.db.combat_buffReminder_enabled then return nil end
    local entry = CLASS_BUFFS[addon.playerClass]
    if not entry then return nil end
    if isSuppressed() then return nil end
    if not anyoneMissingBuff(entry.spellID) then return nil end
    return entry
end

-- Paladin seals, Forever only. Retail has no seals.
--
-- Each seal has a separate spell ID per rank, and Forever adds seals with no
-- published IDs, so seals are matched by aura name instead. Names come from the
-- rank 1 IDs below so they follow the client's locale. Any aura starting with the
-- same "Seal of " prefix also counts, which picks up Forever-only seals on
-- English clients.
local SEAL_IDS = {
    21084, -- Seal of Righteousness
    20375, -- Seal of Command
    21082, -- Seal of the Crusader
    20164, -- Seal of Justice
    20165, -- Seal of Light
    20166, -- Seal of Wisdom
}

-- Shown as the icon. Every paladin has Seal of Righteousness from level 1.
local SEAL_ICON_ID = 21084

local sealNames = nil
local sealPrefix = nil

-- Names can come back nil before spell data has loaded, so nothing is cached
-- until at least one resolves.
local function loadSealNames()
    if sealNames then return end
    local names = {}
    local found = false
    for _, id in ipairs(SEAL_IDS) do
        local name = C_Spell.GetSpellName(id)
        if name then
            names[name] = true
            found = true
        end
    end
    if not found then return end
    sealNames = names
    -- "Seal of Righteousness" -> "Seal of "
    local base = C_Spell.GetSpellName(SEAL_IDS[1])
    sealPrefix = base and base:match("^(.* )%S+$")
end

local function isSealName(name)
    if not sealNames or not name then return false end
    if sealNames[name] then return true end
    return sealPrefix ~= nil and name:sub(1, #sealPrefix) == sealPrefix
end

local function isAuraSecret(index)
    return C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret
        and C_Secrets.ShouldUnitAuraIndexBeSecret("player", index, "HELPFUL")
end

-- Judgement can only be cast with a seal up, and its usable state is not hidden
-- in combat the way buffs are. So when the buffs are hidden, Judgement stands in:
-- usable means a seal is up, unusable for any reason other than mana means none.
-- Out of mana tells us nothing, so that returns nil.
local JUDGEMENT = 20271

local function judgementSaysSeal()
    if not IsPlayerSpell(JUDGEMENT) then return nil end
    local usable, noMana = C_Spell.IsSpellUsable(JUDGEMENT)
    if usable then return true end
    if noMana then return nil end
    return false
end

-- Returns true with a seal up, false with none, and nil when it cannot tell.
-- In combat the client can hide aura details from addons ("secret" values), and
-- a hidden aura might be the seal. Those are skipped rather than read, since
-- touching a secret name errors.
local function hasSeal()
    loadSealNames()
    if not sealNames then return nil end
    local unknown = false
    for i = 1, 40 do
        if isAuraSecret(i) then
            unknown = true
        else
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            if isSealName(aura.name) then return true end
        end
    end
    if unknown then return judgementSaysSeal() end
    return false
end

-- Seals only last 30 seconds, so outside combat this would nag constantly.
-- It only shows once you are fighting without one.
local function getSealReminder()
    if not addon.FOREVER then return nil end
    if not addon.db.combat_sealReminder_enabled then return nil end
    if addon.playerClass ~= "PALADIN" then return nil end
    if not UnitAffectingCombat("player") then return nil end
    if UnitIsDeadOrGhost("player") or IsMounted() or UnitOnTaxi("player")
        or UnitHasVehicleUI("player") then
        return nil
    end
    -- Only nag when certain. A hidden aura could be the seal.
    if hasSeal() ~= false then return nil end
    return { spellID = SEAL_ICON_ID }
end

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
local fadeIn = buffPulse:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0.35)
fadeIn:SetToAlpha(1.0)
fadeIn:SetDuration(0.55)
fadeIn:SetOrder(1)
local fadeOut = buffPulse:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1.0)
fadeOut:SetToAlpha(0.35)
fadeOut:SetDuration(0.55)
fadeOut:SetOrder(2)

function addon.MI_BuffReminder_Update()
    local entry = getBuffReminder() or getSealReminder()
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
