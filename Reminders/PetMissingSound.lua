local _, addon = ...

local SOUND_DIR = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Pet\\"
local SOUNDS = {
    SOUND_DIR .. "BabyMurlocA.ogg",
    SOUND_DIR .. "BabyMurlocB.ogg",
    SOUND_DIR .. "BabyMurlocC.ogg",
}

-- Globals to match against UI_ERROR_MESSAGE text. Filled at file load.
local NO_PET_MESSAGES = {}
for _, name in ipairs({
    "SPELL_FAILED_NO_PET",
    "SPELL_FAILED_PET_IS_DEAD",
    "ERR_PETSPELL_DEAD",
}) do
    local s = _G[name]
    if s then NO_PET_MESSAGES[s] = true end
end

local THROTTLE = 3
local lastPlayed = 0

local f = CreateFrame("Frame")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:SetScript("OnEvent", function(_, _, _, message)
    if not addon.db.combat_petMissingSound_enabled then return end
    if not NO_PET_MESSAGES[message] then return end
    local now = GetTime()
    if now - lastPlayed < THROTTLE then return end
    lastPlayed = now
    PlaySoundFile(SOUNDS[math.random(#SOUNDS)], addon.db.sound_channel)
end)
