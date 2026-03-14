local _, addon = ...

-- Plays a .ogg sound when a Bloodlust-type haste effect is applied to the player.
-- Detects via the Sated-family debuffs; the buff itself became a private aura in 11.1.
-- Add debuff spell IDs to MI_LUST_IDS to extend coverage.

local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Lust\\"

-- Sated-type debuffs applied alongside each Bloodlust equivalent.
-- These remain publicly readable via C_UnitAuras despite the private aura changes.
local MI_LUST_IDS = {
    [57724]  = true,  -- Sated                 (Bloodlust)
    [264689] = true,  -- Fatigued              (Primal Rage)
    [57723]  = true,  -- Exhaustion            (Heroism)
    [80354]  = true,  -- Temporal Displacement (Time Warp)
    [95809]  = true,  -- Insanity              (Ancient Hysteria)
    [390435] = true,  -- Overpowered           (Fury of the Aspects)
}

local played = false

local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_AURA", "player")
f:SetScript("OnEvent", function()
    if not addon.db.fun_bloodlust_enabled then
        played = false
        return
    end

    local active = false
    for id in pairs(MI_LUST_IDS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(id) then
            active = true
            break
        end
    end

    if active and not played then
        PlaySoundFile(SOUND_DIR .. addon.db.fun_bloodlust_sound, addon.db.fun_bloodlust_channel)
        played = true
    elseif not active then
        played = false
    end
end)
