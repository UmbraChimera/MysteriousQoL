local _, addon = ...

-- Swaps a spell on your action bars for its new rank when you learn one. Forever only.
--
-- Only runs at the moment a rank is learned, and only replaces lower ranks of that
-- same spell. A lower rank you drag back on afterwards (for downranking) stays put
-- until you learn the next rank.

-- Every action slot, including the extra bars and bonus/stance pages.
local NUM_SLOTS = 180

local pending = {}
local queued = false

-- "Rank 3" -> 3. Takes the digits so it works in any locale. nil when the spell
-- has no rank.
local function rankOf(spellID)
    local subtext = C_Spell.GetSpellSubtext(spellID)
    local n = subtext and subtext:match("(%d+)")
    return n and tonumber(n)
end

local function upgrade(newID)
    local name = C_Spell.GetSpellName(newID)
    local newRank = rankOf(newID)
    if not name or not newRank then return end

    for slot = 1, NUM_SLOTS do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and id and id ~= newID
            and C_Spell.GetSpellName(id) == name then
            local oldRank = rankOf(id)
            if oldRank and oldRank < newRank then
                C_Spell.PickupSpell(newID)
                PlaceAction(slot)
                ClearCursor()
            end
        end
    end
end

-- Placing a spell goes through the cursor, so this waits while anything is on
-- it rather than drop what you are dragging. Action bars cannot change in combat.
local function flush()
    if InCombatLockdown() or GetCursorInfo() then
        queued = true
        return
    end
    queued = false
    for id in pairs(pending) do
        pending[id] = nil
        upgrade(id)
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, spellID)
    if event == "LEARNED_SPELL_IN_SKILL_LINE" then
        if spellID then pending[spellID] = true end
        -- The new rank is not always placeable in the same frame it is learned.
        C_Timer.After(0.2, flush)
    elseif queued then
        flush()
    end
end)

-- Called on load and whenever the setting changes.
function addon.MI_SpellRankUpgrade_SetEnabled()
    if not (GetActionInfo and PlaceAction) then return end
    if addon.db.forever_rankUpgrade_enabled then
        frame:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:RegisterEvent("CURSOR_CHANGED")
    else
        frame:UnregisterAllEvents()
        wipe(pending)
        queued = false
    end
end
