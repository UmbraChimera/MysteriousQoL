local _, addon = ...

-- Prompts you to take a campfire's rest bonus while levelling. Forever only.
--
-- Campfire Nearby is applied just by standing in range of one. Camp Benefits is the
-- buff you get from actually resting there. Having the first without the second
-- means a campfire is sitting right next to you with its bonus unclaimed.

local CAMPFIRE_NEARBY = 1283391
local CAMP_BENEFITS   = 1229741

-- Forever caps here, and the rest bonus stops mattering once you arrive.
local MAX_LEVEL = 60

local campfireFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_CampfireReminderFrame", {
    baseY    = 60,
    bounce   = 5,
    speed    = 2.2,
    fontSize = 28,
    color    = { 1, 0.75, 0.3, 1 },
    shadow   = { 3, -3 },
    width    = 600,
    height   = 60,
    strata   = "HIGH",
    text     = "Stay a while and listen...",
})

local function shouldPrompt()
    if not addon.db.forever_campfireReminder_enabled then return false end
    if UnitLevel("player") >= MAX_LEVEL then return false end
    if UnitIsDeadOrGhost("player") then return false end
    if UnitAffectingCombat("player") then return false end
    if not C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY) then return false end
    -- Already rested here, nothing to prompt for.
    return C_UnitAuras.GetPlayerAuraBySpellID(CAMP_BENEFITS) == nil
end

function addon.MI_CampfireReminder_Update()
    if shouldPrompt() then
        campfireFrame:Show()
    else
        campfireFrame.ResetBounce()
        campfireFrame:Hide()
    end
end
