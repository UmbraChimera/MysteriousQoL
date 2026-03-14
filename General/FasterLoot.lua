local _, addon = ...

-- Rapidly loots all items when LOOT_READY fires.
-- Respects the game's auto-loot setting and modifier key.

local THROTTLE = 0.2
local lastLoot = 0

local f = CreateFrame("Frame")
f:RegisterEvent("LOOT_READY")
f:SetScript("OnEvent", function()
    if not addon.db.general_fasterLoot then return end

    local now = GetTime()
    if now - lastLoot < THROTTLE then return end
    lastLoot = now

    if GetCursorInfo() then return end

    local autoLoot = GetCVarBool("autoLootDefault")
    local modHeld  = IsModifiedClick("AUTOLOOTTOGGLE")
    if (autoLoot and not modHeld) or (not autoLoot and modHeld) then
        for i = GetNumLootItems(), 1, -1 do
            LootSlot(i)
        end
    end
end)
