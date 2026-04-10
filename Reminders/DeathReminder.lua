local _, addon = ...

local function getDeathReminder()
    if not addon.db.combat_deathReminder_enabled then return false end
    if not UnitIsDeadOrGhost("player") then return false end
    if not IsInRaid() then return false end
    local _, instanceType, difficultyID = GetInstanceInfo()
    if instanceType ~= "raid" then return false end
    local _, _, _, _, _, _, isLFR = GetDifficultyInfo(difficultyID)
    return not isLFR
end

local deathFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_DeathReminderFrame", {
    baseY    = 0,
    bounce   = 8,
    speed    = 3.0,
    fontSize = 40,
    color    = { 1, 0.15, 0.15, 1 },
    shadow   = { 3, -3 },
    width    = 600,
    height   = 80,
    strata   = "HIGH",
    text     = "Don't release you dolt!",
})

function addon.MI_DeathReminder_Update()
    if getDeathReminder() then
        deathFrame:Show()
    else
        deathFrame.ResetBounce()
        deathFrame:Hide()
    end
end
