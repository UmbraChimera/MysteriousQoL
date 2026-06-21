local _, addon = ...

local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Rolling\\"

local SOUNDS = {
    SOUND_DIR .. "rollin.ogg",
    SOUND_DIR .. "ridin.ogg",
}

-- Add any roll/dash spell ID here.
local SPELL_IDS = {
    [109132] = true,  -- Roll         (Monk)
    [115008] = true,  -- Chi Torpedo  (Monk talent)
}

addon.MI_CreateSpellCastSound({
    dbKey      = "fun_rolling_enabled",
    channelKey = "fun_rolling_channel",
    spellIDs   = SPELL_IDS,
    sounds     = SOUNDS,
})
