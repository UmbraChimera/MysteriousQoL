local _, addon = ...

local GetSpec     = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization     or GetSpecialization
local GetSpecInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo

-- Hunter specs that require a pet (Beast Mastery = 253, Survival = 255)
local HUNTER_PET_SPECS = { [253] = true, [255] = true }

-- Hunter talents that remove pet requirement
local HUNTER_NO_PET_TALENTS = { 466846, 1232995, 1223323 }

-- Warlock: Grimoire of Sacrifice
local GRIMOIRE_OF_SACRIFICE      = 108503
local GRIMOIRE_SACRIFICE_BUFF    = 196099

local function isSuppressed()
    return UnitIsDeadOrGhost("player")
        or IsMounted()
        or IsResting()
        or UnitHasVehicleUI("player")
        or UnitOnTaxi("player")
end

local function isPetExpected()
    if addon.playerClass == "WARLOCK" then
        -- Grimoire of Sacrifice active = no pet needed
        if IsPlayerSpell(GRIMOIRE_OF_SACRIFICE) then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(GRIMOIRE_SACRIFICE_BUFF)
            if aura then return false end
        end
        return true
    end
    if addon.playerClass == "HUNTER" then
        -- Check for no-pet talents first
        for _, spellID in ipairs(HUNTER_NO_PET_TALENTS) do
            if IsPlayerSpell(spellID) then return false end
        end
        local specIndex = GetSpec()
        local specID = specIndex and GetSpecInfo(specIndex)
        return HUNTER_PET_SPECS[specID] == true
    end
    if addon.playerClass == "DEATHKNIGHT" then
        local specIndex = GetSpec()
        local specID = specIndex and GetSpecInfo(specIndex)
        return specID == 252  -- Unholy only
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

local petFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_PetReminderFrame", {
    baseY    = 155,
    bounce   = 6,
    speed    = 2.5,
    fontSize = 26,
    color    = { 1, 0.2, 0.2, 1 },
    icon     = 132161,
})

function addon.MI_PetReminder_Update()
    local petMsg = getPetMessage()
    if petMsg then
        petFrame.text:SetText(petMsg)
        petFrame:Show()
    else
        petFrame.ResetBounce()
        petFrame:Hide()
    end
end
