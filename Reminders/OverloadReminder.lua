local _, addon = ...

-- Shows a reminder to use Overload when you start gathering a node and the spell is off cooldown.
-- Detects mining and herb gathering casts via UNIT_SPELLCAST_START whitelist.

local OVERLOAD_MINING = 1225392  -- Overload Infused Deposit
local OVERLOAD_HERB   = 1223014  -- Overload Infused Herb

-- Universal gathering spell IDs (one per profession in Midnight)
local GATHERING_SPELLS = {
    [471013] = OVERLOAD_MINING,  -- Midnight Mining
    [471009] = OVERLOAD_HERB,    -- Herb Gathering
}

local function isOffCooldown(spellID)
    local info = C_Spell.GetSpellCooldown(spellID)
    return info and info.startTime == 0
end

-- ── Display frame ─────────────────────────────────────────────────────────────

local overloadFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_OverloadReminderFrame", {
    baseY    = 80,
    bounce   = 6,
    speed    = 2.5,
    fontSize = 34,
    color    = { 1, 0.8, 0, 1 },
    strata   = "HIGH",
    text     = "USE OVERLOAD!",
})

-- ── Event handling ─────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP",  "player")
eventFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
    if event == "UNIT_SPELLCAST_START" then
        if not addon.db.combat_overloadReminder_enabled then return end
        local overloadID = GATHERING_SPELLS[spellID]
        if overloadID and isOffCooldown(overloadID) then
            overloadFrame.ResetBounce()
            overloadFrame:Show()
        end
    elseif event == "UNIT_SPELLCAST_STOP" then
        overloadFrame.ResetBounce()
        overloadFrame:Hide()
    end
end)
