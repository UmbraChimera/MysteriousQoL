local addonName, addon = ...

-- Plays r2d2.mp3 when a Bloodlust-type haste effect is applied to the player.
-- Add spell IDs to MI_LUST_IDS to extend coverage.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Lust\\r2d2.mp3"

-- Add any Bloodlust-equivalent spell ID here.
local MI_LUST_IDS = {
    [2825]   = true,  -- Bloodlust         (Shaman)
    [32182]  = true,  -- Heroism           (Shaman)
    [80353]  = true,  -- Time Warp         (Mage)
    [90355]  = true,  -- Ancient Hysteria  (Hunter exotic pet)
    [264667] = true,  -- Primal Rage       (Ferocity pet)
    [390386] = true,  -- Fury of the Aspects (Evoker)
}

local played = false

local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_AURA", "player")
f:SetScript("OnEvent", function()
    if not addon.db or not addon.db.fun_bloodlust_enabled then
        played = false
        return
    end

    local active = false
    for id in pairs(MI_LUST_IDS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(id) then
            active = true
            break
        end
    end

    if active and not played then
        PlaySoundFile(SOUND, addon.db.fun_bloodlust_channel or "Master")
        played = true
    elseif not active then
        played = false
    end
end)

function addon.MI_Bloodlust_RegisterSettings(funCat)
    local function GetChannelOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("Master",   "Master")
        container:Add("SFX",      "Sound Effects")
        container:Add("Music",    "Music")
        container:Add("Ambience", "Ambience")
        container:Add("Dialog",   "Dialog")
        return container:GetData()
    end

    addon.settings.Checkbox(
        funCat,
        "fun_bloodlust_enabled",
        "Bloodlust Sound",
        "Plays an R2-D2 sound when Bloodlust, Heroism, Time Warp, or any equivalent haste effect is applied to you."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_bloodlust_channel",
        "Bloodlust Sound Channel",
        GetChannelOptions,
        "Which audio channel to use for the Bloodlust sound."
    )
end
