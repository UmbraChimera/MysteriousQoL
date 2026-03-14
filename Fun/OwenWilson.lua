local _, addon = ...

-- Sound files live in Sounds/OwenWilson/.
-- WoW's sandbox can't enumerate files at runtime, so the names are listed here.
-- To add more clips: drop the .ogg into Sounds/OwenWilson/ and add the filename below.
local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\OwenWilson\\"

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
    PlaySoundFile(SOUNDS[math.random(#SOUNDS)], addon.db.fun_owenWilson_channel)
end)
