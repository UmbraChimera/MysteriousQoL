local _, addon = ...

-- Plays dbz.ogg when the player uses Blink, Shimmer, or Shift.
-- Add spell IDs to MI_BLINK_IDS to extend coverage.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Blink\\dbz.ogg"

local PlaySoundFile = PlaySoundFile

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

function addon.MI_Blink_RegisterSettings(funCat)
    addon.settings.Checkbox(
        funCat,
        "fun_blink_enabled",
        "Blink Sound",
        "Plays a DBZ sound when you use Blink or Shimmer (Mage) or Shift (Demon Hunter)."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_blink_channel",
        "Blink Sound Channel",
        addon.settings.GetChannelOptions,
        "Which audio channel to use for the Blink sound."
    )
end
