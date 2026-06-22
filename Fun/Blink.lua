local _, addon = ...

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Blink\\dbz.ogg"

-- Add any blink/dash/teleport spell ID here.
local SPELL_IDS = {
    [1953]    = true,  -- Blink    (Mage)
    [212653]  = true,  -- Shimmer  (Mage talent)
    [1234796] = true,  -- Shift    (Demon Hunter)
}

addon.MI_CreateSpellCastSound({
    dbKey    = "fun_blink_enabled",
    spellIDs = SPELL_IDS,
    sounds   = SOUND,
})
