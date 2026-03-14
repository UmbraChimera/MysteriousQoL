local _, addon = ...

-- Plays sus.ogg when the player enters stealth or prowl.
-- Add spell IDs to MI_SNEAKY_IDS to extend coverage.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Sneaky\\sus.ogg"

-- Add any stealth/prowl spell ID here.
local MI_SNEAKY_IDS = {
    [1784]   = true,  -- Stealth      (Rogue)
    [5215]   = true,  -- Prowl        (Druid)
}

local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:SetScript("OnEvent", function(_, _, _, _, spellID)
    if addon.db.fun_sneaky_enabled and MI_SNEAKY_IDS[spellID] then
        PlaySoundFile(SOUND, addon.db.fun_sneaky_channel)
    end
end)
