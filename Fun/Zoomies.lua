local _, addon = ...

-- Plays a sound when the player uses a major speed ability.
-- When multiple sounds are available, convert SOUND to SOUND_DIR + dropdown (see Bloodlust.lua).
-- Add spell IDs to MI_ZOOM_IDS to extend coverage.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Zoomies\\benny_hill.ogg"

local PlaySoundFile = PlaySoundFile

-- Add any major speed ability spell ID here.
local MI_ZOOM_IDS = {
    [186257] = true,  -- Aspect of the Cheetah (Hunter)
    [1850]   = true,  -- Dash                  (Druid)
    [190784] = true,  -- Divine Steed          (Paladin)
}

local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:SetScript("OnEvent", function(_, _, _, _, spellID)
    if addon.db.fun_zoomies_enabled and MI_ZOOM_IDS[spellID] then
        PlaySoundFile(SOUND, addon.db.fun_zoomies_channel)
    end
end)

function addon.MI_Zoomies_RegisterSettings(funCat)
    addon.settings.Checkbox(
        funCat,
        "fun_zoomies_enabled",
        "Zoomies Sound",
        "Plays a sound when you use Aspect of the Cheetah, Dash, Divine Steed, or any equivalent speed ability."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_zoomies_channel",
        "Zoomies Sound Channel",
        addon.settings.GetChannelOptions,
        "Which audio channel to use for the zoomies sound."
    )
end
