local _, addon = ...

-- Repair Reminder: when any equipped item drops to the set durability, plays a
-- sound and prints a chat line once, and shows "Fix your shit!" while out of
-- combat. Re-arms once gear is back above the setting (repaired).

local PREFIX = "|cff00ccff[MysteriousQoL]|r "
local REARM_MARGIN = 0.05

-- Lowest durability of any equipped item, 0..1, or nil with nothing that wears.
local function lowestDurability()
    local lowest
    for slot = 1, 19 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            local pct = current / maximum
            if not lowest or pct < lowest then lowest = pct end
        end
    end
    return lowest
end

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

local warned = false

local function hideFrame()
    repairFrame.ResetBounce()
    repairFrame:Hide()
end

function addon.MI_RepairReminder_Update()
    if not addon.db.combat_repairReminder_enabled then
        warned = false
        hideFrame()
        return
    end

    local lowest = lowestDurability()
    local limit = addon.db.combat_repairReminder_pct / 100
    if not lowest or lowest > limit then
        if not lowest or lowest > limit + REARM_MARGIN then warned = false end
        hideFrame()
        return
    end

    if not warned then
        warned = true
        print(PREFIX .. string.format("Your gear is at %d%% durability.", math.floor(lowest * 100 + 0.5)))
        PlaySound(SOUNDKIT.RAID_WARNING, addon.db.sound_channel)
    end

    if UnitAffectingCombat("player") then
        hideFrame()
    else
        repairFrame:Show()
    end
end
