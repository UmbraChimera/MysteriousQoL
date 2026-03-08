local _, addon = ...

-- Sound files live in Sounds/OwenWilson/.
-- WoW's sandbox can't enumerate files at runtime, so the names are listed here.
-- To add more clips: drop the .ogg into Sounds/OwenWilson/ and add the filename below.
local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\OwenWilson\\"

local PlaySoundFile = PlaySoundFile
local random        = math.random

local SOUND_NAMES = {
    "wowa.ogg", "wowb.ogg", "wowc.ogg", "wowd.ogg", "wowe.ogg",
    "wowf.ogg", "wowg.ogg", "wowh.ogg", "wowi.ogg", "wowj.ogg",
    "wowk.ogg",
}
local SOUNDS = {}
for i, name in ipairs(SOUND_NAMES) do
    SOUNDS[i] = SOUND_DIR .. name
end

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("LOOT_OPENED")
lootFrame:SetScript("OnEvent", function()
    if not addon.db.fun_owenWilson_enabled then return end
    PlaySoundFile(SOUNDS[random(#SOUNDS)], addon.db.fun_owenWilson_channel)
end)

-- Called from MysteriousQoL.lua once the Settings panel is being built.
-- funCat : the "Fun" vertical layout subcategory
function addon.MI_OwenWilson_RegisterSettings(funCat)
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
        addon.settings.GetChannelOptions,
        "Which audio channel to use for Owen Wilson sounds."
    )
end
