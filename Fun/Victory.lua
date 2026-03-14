local _, addon = ...

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Special\\victory.ogg"

-- Achievement IDs that trigger the victory sound
local ACHIEVEMENTS = {
    [61491] = true,
    [61492] = true,
    [61626] = true,
    [61627] = true,
    [61624] = true,
    [61625] = true,
    [629] = true,
}

local listener = CreateFrame("Frame")

local function OnAchievement(_, _, achievementID)
    if not ACHIEVEMENTS[achievementID] then return end
    PlaySoundFile(SOUND, addon.db.fun_victory_channel)
end

-- Only listen for achievements while inside an instance
local zone = CreateFrame("Frame")
zone:RegisterEvent("PLAYER_ENTERING_WORLD")
zone:SetScript("OnEvent", function()
    if not addon.db.fun_victory_enabled then
        listener:UnregisterEvent("ACHIEVEMENT_EARNED")
        return
    end
    local inInstance = IsInInstance()
    if inInstance then
        listener:RegisterEvent("ACHIEVEMENT_EARNED")
        listener:SetScript("OnEvent", OnAchievement)
    else
        listener:UnregisterEvent("ACHIEVEMENT_EARNED")
    end
end)
