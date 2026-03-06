local _, addon = ...

-- Plays a random rolling sound when the player uses Roll or Chi Torpedo (Monk).
-- Add spell IDs to MI_ROLL_IDS to extend coverage.

local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Rolling\\"

local PlaySoundFile = PlaySoundFile
local random        = math.random

local SOUNDS = {
    SOUND_DIR .. "rollin.ogg",
    SOUND_DIR .. "ridin.ogg",
}

-- Add any roll/dash spell ID here.
local MI_ROLL_IDS = {
    [109132] = true,  -- Roll         (Monk)
    [115008] = true,  -- Chi Torpedo  (Monk talent)
}

local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:SetScript("OnEvent", function(_, _, _, _, spellID)
    if addon.db.fun_rolling_enabled and MI_ROLL_IDS[spellID] then
        PlaySoundFile(SOUNDS[random(#SOUNDS)], addon.db.fun_rolling_channel)
    end
end)

function addon.MI_Rolling_RegisterSettings(funCat)
    addon.settings.Checkbox(
        funCat,
        "fun_rolling_enabled",
        "Roll Sound",
        "Plays a random sound when you use Roll or Chi Torpedo (Monk)."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_rolling_channel",
        "Roll Sound Channel",
        addon.settings.GetChannelOptions,
        "Which audio channel to use for the roll sound."
    )
end
