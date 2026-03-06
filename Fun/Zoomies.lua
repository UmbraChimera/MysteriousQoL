local _, addon = ...

-- Plays a sound when the player uses a major speed ability.
-- Structured like Bloodlust: single SOUND_DIR + dropdown for future sound choices.
-- Add spell IDs to MI_ZOOM_IDS to extend coverage.

local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Zoomies\\"

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
        PlaySoundFile(SOUND_DIR .. addon.db.fun_zoomies_sound, addon.db.fun_zoomies_channel)
    end
end)

function addon.MI_Zoomies_RegisterSettings(funCat)
    local function GetSoundOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("benny_hill.ogg", "Benny Hill")
        return container:GetData()
    end

    addon.settings.Checkbox(
        funCat,
        "fun_zoomies_enabled",
        "Zoomies Sound",
        "Plays a sound when you use Aspect of the Cheetah, Dash, Divine Steed, or any equivalent speed ability."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_zoomies_sound",
        "Zoomies Sound Choice",
        GetSoundOptions,
        "Which sound to play when you zoom."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_zoomies_channel",
        "Zoomies Sound Channel",
        addon.settings.GetChannelOptions,
        "Which audio channel to use for the zoomies sound."
    )
end
