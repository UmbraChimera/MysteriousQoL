local _, addon = ...

-- Center-screen reminders for:
--   * Missing class buff (buff-providing classes only)
--   * No active pet (Warlock / Hunter BM+Survival)
--   * Pet idle in combat (same classes)
--   * Don't release in a raid instance

-- ── Update logic ───────────────────────────────────────────────────────────────

local function updateReminders()
    addon.MI_BuffReminder_Update()
    addon.MI_PetReminder_Update()
    addon.MI_DeathReminder_Update()
    addon.MI_RepairReminder_Update()
end

-- Throttled wrapper -coalesces rapid event fires (e.g. UNIT_AURA spam in raids)
local THROTTLE_INTERVAL = 0.5
local lastUpdate = 0
local pendingTimer = nil

local function updateRemindersThrottled()
    local now = GetTime()
    if now - lastUpdate >= THROTTLE_INTERVAL then
        lastUpdate = now
        updateReminders()
    elseif not pendingTimer then
        local delay = THROTTLE_INTERVAL - (now - lastUpdate)
        pendingTimer = C_Timer.NewTimer(delay, function()
            pendingTimer = nil
            lastUpdate = GetTime()
            updateReminders()
        end)
    end
end

-- ── Event handling ─────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
local eventsRegistered = false
local ticker = nil

local function RegisterReminderEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:RegisterEvent("PLAYER_UNGHOST")
    eventFrame:RegisterEvent("PLAYER_ALIVE")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterUnitEvent("UNIT_AURA",           "player")
    eventFrame:RegisterUnitEvent("UNIT_PET",            "player")
    eventFrame:RegisterUnitEvent("UNIT_FLAGS",          "player", "pet")
    eventFrame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE","player")
    eventFrame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    eventFrame:RegisterEvent("PET_BAR_UPDATE")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    eventFrame:SetScript("OnEvent", function() updateRemindersThrottled() end)
    -- Fallback ticker for taxi and edge cases not covered by events
    ticker = C_Timer.NewTicker(5, updateReminders)
end

local function UnregisterReminderEvents()
    if not eventsRegistered then return end
    eventsRegistered = false
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    if ticker then ticker:Cancel() ticker = nil end
end

local function AnyReminderEnabled()
    local db = addon.db
    return db.combat_buffReminder_enabled
        or db.combat_petReminder_enabled
        or db.combat_petIdleReminder_enabled
        or db.combat_deathReminder_enabled
        or db.combat_deathReleaseProtection
        or db.combat_overloadReminder_enabled
        or db.combat_repairReminder_enabled
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────────

function addon.MI_Reminders_Init()
    local _, class = UnitClass("player")
    addon.playerClass = class
    if AnyReminderEnabled() then
        RegisterReminderEvents()
        updateReminders()
    end
end

-- Called by settings UI when any reminder toggle changes
function addon.MI_Reminders_RefreshState()
    if AnyReminderEnabled() then
        RegisterReminderEvents()
        updateReminders()
    else
        UnregisterReminderEvents()
    end
end
