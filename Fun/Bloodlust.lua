local _, addon = ...

-- Plays a sound when you get Bloodlust or similar. Looks for the Sated
-- debuffs, since the lust buff itself has been a private aura since 11.1.

local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Lust\\"

-- These are still readable
local MI_LUST_IDS = {
    [57724]  = true,  -- Sated                 (Bloodlust)
    [264689] = true,  -- Fatigued              (Primal Rage)
    [57723]  = true,  -- Exhaustion            (Heroism)
    [80354]  = true,  -- Temporal Displacement (Time Warp)
    [95809]  = true,  -- Insanity              (Ancient Hysteria)
    [390435] = true,  -- Overpowered           (Fury of the Aspects)
}

local played = false

local function isLustActive()
    for id in pairs(MI_LUST_IDS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(id) then
            return true
        end
    end
    return false
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event)
    -- If Sated is already up when you zone in, don't play it again.
    if event == "PLAYER_ENTERING_WORLD" then
        played = isLustActive()
        return
    end

    if not IsInInstance() then
        played = false
        return
    end

    local active = isLustActive()

    if active and not played then
        PlaySoundFile(SOUND_DIR .. addon.db.fun_bloodlust_sound, addon.db.sound_channel)
        played = true
    elseif not active then
        played = false
    end
end)

function addon.MI_Bloodlust_SetEnabled()
    if addon.db.fun_bloodlust_enabled then
        played = isLustActive()
        f:RegisterUnitEvent("UNIT_AURA", "player")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        f:UnregisterAllEvents()
        played = false
    end
end
