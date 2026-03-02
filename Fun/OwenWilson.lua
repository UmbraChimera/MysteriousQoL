local addonName, addon = ...

-- Sound files live in Sounds/OwenWilson/.
-- WoW's sandbox can't enumerate files at runtime, so the names are listed here.
-- To add more clips: drop the .mp3 into Sounds/OwenWilson/ and add the filename below.
local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\OwenWilson\\"
local SOUND_NAMES = {
    "wowa.mp3", "wowb.mp3", "wowc.mp3", "wowd.mp3", "wowe.mp3",
    "wowf.mp3", "wowg.mp3", "wowh.mp3", "wowi.mp3", "wowj.mp3",
    "wowk.mp3",
}
local SOUNDS = {}
for _, name in ipairs(SOUND_NAMES) do
    SOUNDS[#SOUNDS + 1] = SOUND_DIR .. name
end

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("LOOT_OPENED")
lootFrame:SetScript("OnEvent", function()
    if not addon.db or not addon.db.fun_owenWilson_enabled then return end
    PlaySoundFile(SOUNDS[math.random(#SOUNDS)], addon.db.fun_owenWilson_channel or "Master")
end)

-- Called from MysteriousQoL.lua once the Settings panel is being built.
-- funCat : the "Fun" vertical layout subcategory
function addon.MI_OwenWilson_RegisterSettings(funCat)
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
        "fun_owenWilson_enabled",
        "Owen Wilson Loot Sounds",
        "Plays a random Owen Wilson \"wow\" sound whenever a loot window opens."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_owenWilson_channel",
        "Sound Channel",
        GetChannelOptions,
        "Which audio channel to use for Owen Wilson sounds."
    )
end
