local _, addon = ...

-- Plays dbz.ogg when the player uses Blink, Shimmer, or Shift.
-- Add spell IDs to MI_BLINK_IDS to extend coverage.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Blink\\dbz.ogg"

-- Add any blink/dash/teleport spell ID here.
local MI_BLINK_IDS = {
    [1953]    = true,  -- Blink    (Mage)
    [212653]  = true,  -- Shimmer  (Mage talent)
    [1234796] = true,  -- Shift    (Demon Hunter)
}

local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:SetScript("OnEvent", function(_, _, _, _, spellID)
    if addon.db.fun_blink_enabled and MI_BLINK_IDS[spellID] then
        PlaySoundFile(SOUND, addon.db.fun_blink_channel)
    end
end)
