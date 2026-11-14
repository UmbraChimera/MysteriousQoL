local _, addon = ...

-- Prompts you to get some sleep when you have no stacks of Well-Rested at all. Forever only.

local WELL_RESTED = 429959

local MESSAGES = { "SLEEP!!!", "Snuggle Puddle", "Time to get Cozy" }

local restedFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_WellRestedReminderFrame", {
    baseY    = 110,
    bounce   = 5,
    speed    = 2.2,
    fontSize = 28,
    color    = { 0.6, 0.75, 1, 1 },
    shadow   = { 3, -3 },
    width    = 600,
    height   = 60,
    strata   = "HIGH",
})

local function shouldPrompt()
    if not addon.db.forever_wellRestedReminder_enabled then return false end
    if UnitIsDeadOrGhost("player") then return false end
    -- Buffs are secret in combat, so it's only checked out of combat.
    if UnitAffectingCombat("player") then return false end
    return C_UnitAuras.GetPlayerAuraBySpellID(WELL_RESTED) == nil
end

function addon.MI_WellRestedReminder_Update()
    if shouldPrompt() then
        if not restedFrame:IsShown() then
            restedFrame.text:SetText(MESSAGES[math.random(#MESSAGES)])
            restedFrame:Show()
        end
    else
        restedFrame.ResetBounce()
        restedFrame:Hide()
    end
end
