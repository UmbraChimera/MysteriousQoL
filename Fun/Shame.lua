local _, addon = ...

-- Plays a shame sound when you release spirit in a raid instance.
-- Alive-member check runs at PLAYER_ALIVE time so full wipes don't trigger it.

local PlaySoundFile = PlaySoundFile

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
        local inRaid = IsInRaid()
        if inRaid and instanceType == "raid" and not isLFR then
            diedInRaid = true
        end

    elseif event == "PLAYER_ALIVE" then
        if diedInRaid then
            if hasAliveRaidMember() and addon.db.fun_shame_enabled then
                PlaySoundFile(SOUND, addon.db.fun_shame_channel)
            end
            diedInRaid = false
        end

    end
end)

-- ── Settings ──────────────────────────────────────────────────────────────────

function addon.MI_Shame_RegisterSettings(cat)
    addon.settings.Checkbox(
        cat, "fun_shame_enabled", "Shame Sound",
        "Plays a sound when you release spirit in a raid instance while others are still alive. Does not fire on full wipes or healer rezzes."
    )
    addon.settings.Dropdown(
        cat, "fun_shame_channel", "Audio Channel",
        addon.settings.GetChannelOptions,
        "Which audio channel to play the shame sound on."
    )
end
