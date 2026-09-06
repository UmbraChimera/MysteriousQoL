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

local function UpdateEventRegistration()
    if addon.db.fun_victory_enabled and IsInInstance() then
        f:RegisterEvent("ACHIEVEMENT_EARNED")
    else
        f:UnregisterEvent("ACHIEVEMENT_EARNED")
    end
end

f:SetScript("OnEvent", function(_, event, achievementID)
    if event == "ACHIEVEMENT_EARNED" then
        if addon.db.fun_victory_enabled and ACHIEVEMENTS[achievementID] then
            PlaySoundFile(SOUND, addon.db.sound_channel)
        end
    else
        UpdateEventRegistration()
    end
end)

function addon.MI_Victory_SetEnabled()
    UpdateEventRegistration()
end
