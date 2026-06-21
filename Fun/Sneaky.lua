local _, addon = ...

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Sneaky\\sus.ogg"

-- Add any stealth/prowl spell ID here.
local SPELL_IDS = {
    [1784] = true,  -- Stealth (Rogue)
    [5215] = true,  -- Prowl   (Druid)
}

addon.MI_CreateSpellCastSound({
    dbKey      = "fun_sneaky_enabled",
    channelKey = "fun_sneaky_channel",
    spellIDs   = SPELL_IDS,
    sounds     = SOUND,
})
