local _, addon = ...

-- ── Durability check ─────────────────────────────────────────────────────────

local function needsRepair()
    if not addon.db.combat_repairReminder_enabled then return false end
    if UnitAffectingCombat("player") then return false end
    for slot = 1, 19 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            if current / maximum <= 0.5 then return true end
        end
    end
    return false
end

-- ── Display frame ──────────────────────────────────────────────────────────

local repairFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_RepairReminderFrame", {
    baseY    = -60,
    bounce   = 8,
    speed    = 3.0,
    fontSize = 40,
    color    = { 1, 0.82, 0, 1 },
    shadow   = { 3, -3 },
    width    = 600,
    height   = 80,
    strata   = "HIGH",
    text     = "Fix your shit!",
})

-- ── Update ───────────────────────────────────────────────────────────────────

function addon.MI_RepairReminder_Update()
    if needsRepair() then
        repairFrame:Show()
    else
        repairFrame.ResetBounce()
        repairFrame:Hide()
    end
end
