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

-- Only listen for achievements while inside an instance
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, achievementID)
    if event == "ACHIEVEMENT_EARNED" then
        if ACHIEVEMENTS[achievementID] then
            PlaySoundFile(SOUND, addon.db.fun_victory_channel)
        end
    else
        if IsInInstance() then
            f:RegisterEvent("ACHIEVEMENT_EARNED")
        else
            f:UnregisterEvent("ACHIEVEMENT_EARNED")
        end
    end
end)
