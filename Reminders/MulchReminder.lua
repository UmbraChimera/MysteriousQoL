local _, addon = ...

-- Shows a reminder to use Imbued Mulch when herbing and the item is available and off cooldown.

local ITEM_ID    = 238388  -- Imbued Mulch
local SPELL_HERB = 471009  -- Herb Gathering (Midnight)

local function isMulchReady()
    if GetItemCount(ITEM_ID) == 0 then return false end
    local startTime, _, enable = GetItemCooldown(ITEM_ID)
    return enable == 1 and startTime == 0
end

local mulchFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_MulchReminderFrame", {
    baseY    = 160,
    bounce   = 6,
    speed    = 2.5,
    fontSize = 34,
    color    = { 1, 0.8, 0, 1 },
    strata   = "HIGH",
    text     = "USE MULCH!",
})

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP",  "player")
eventFrame:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_START" then
        if not addon.db.combat_mulchReminder_enabled then return end
        if IsInInstance() then return end
        if spellID == SPELL_HERB and isMulchReady() then
            mulchFrame.ResetBounce()
            mulchFrame:Show()
        end
    elseif event == "UNIT_SPELLCAST_STOP" then
        mulchFrame.ResetBounce()
        mulchFrame:Hide()
    end
end)
