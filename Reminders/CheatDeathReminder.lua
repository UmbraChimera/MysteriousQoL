local _, addon = ...

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Reminders\\almost_died.ogg"

local CHEAT_DEATH_DEBUFFS = {
    116888, -- Perdition (Purgatory - Death Knight)
    45182,  -- Cheat Death (Subtlety Rogue)
    87023,  -- Cauterize (Fire Mage)
    209261, -- Uncontained Fel (Last Resort - Demon Hunter)
}

local wasActive = false

local function isCheatDeathActive()
    if not UnitAffectingCombat("player") then return false end
    if not IsInInstance() then return false end
    for _, spellID in ipairs(CHEAT_DEATH_DEBUFFS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            return true
        end
    end
    return false
end

local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_AURA", "player")
f:SetScript("OnEvent", function()
    if not addon.db.combat_cheatDeathReminder_enabled then
        wasActive = false
        return
    end
    local active = isCheatDeathActive()
    if active and not wasActive then
        PlaySoundFile(SOUND, "Master")
    end
    wasActive = active
end)
