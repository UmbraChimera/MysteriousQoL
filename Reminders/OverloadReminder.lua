local _, addon = ...

-- Shows a reminder to use Overload when you start gathering and the spell is off cooldown.
-- Never shows inside instances.

local SPELL_MINING    = 471013   -- Midnight Mining
local SPELL_HERB      = 471009   -- Herb Gathering

local OVERLOAD_MINING = 1225392  -- Overload Infused Deposit
local OVERLOAD_HERB   = 1223014  -- Overload Infused Herb

local function isOffCooldown(spellID)
    local info = C_Spell.GetSpellCooldown(spellID)
    return info and info.startTime == 0
end

local overloadFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_OverloadReminderFrame", {
    baseY    = 80,
    bounce   = 6,
    speed    = 2.5,
    fontSize = 34,
    color    = { 1, 0.8, 0, 1 },
    strata   = "HIGH",
    text     = "USE OVERLOAD!",
})

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP",  "player")
eventFrame:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_START" then
        if not addon.db.combat_overloadReminder_enabled then return end
        if IsInInstance() then return end
        local overloadID
        if spellID == SPELL_HERB then
            overloadID = OVERLOAD_HERB
        elseif spellID == SPELL_MINING then
            overloadID = OVERLOAD_MINING
        end
        if overloadID and isOffCooldown(overloadID) then
            overloadFrame.ResetBounce()
            overloadFrame:Show()
        end
    elseif event == "UNIT_SPELLCAST_STOP" then
        overloadFrame.ResetBounce()
        overloadFrame:Hide()
    end
end)
