local _, addon = ...

-- Plays a shame sound when you release spirit in a raid instance.
-- Shares the "Don't Release Reminder" toggle (combat_deathReminder_enabled).
-- Alive-member check runs at PLAYER_ALIVE time so full wipes don't trigger it.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Reminders\\shame.ogg"

local diedInRaid = false

local function hasAliveRaidMember()
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = "raid" .. i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            return true
        end
    end
    return false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_DEAD" then
        local _, instanceType, difficultyID = GetInstanceInfo()
        local isLFR = select(8, GetDifficultyInfo(difficultyID))
        if IsInRaid() and instanceType == "raid" and not isLFR then
            diedInRaid = true
        end

    elseif event == "PLAYER_ALIVE" then
        if diedInRaid then
            if hasAliveRaidMember() and addon.db.combat_deathReminder_enabled then
                PlaySoundFile(SOUND, "Master")
            end
            diedInRaid = false
        end
    end
end)
