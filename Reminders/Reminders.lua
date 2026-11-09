local _, addon = ...

-- Runs every reminder's update function off one shared set of events.
-- Listed by name because each TOC loads different reminders, and any that
-- aren't loaded just get skipped. Repair is the only one on both versions.
local UPDATE_FUNCS = {
    "MI_RepairReminder_Update",
}

local ENABLE_KEYS = {
    "combat_repairReminder_enabled",
}

if addon.RETAIL then
    table.insert(UPDATE_FUNCS, "MI_BuffReminder_Update")
    table.insert(UPDATE_FUNCS, "MI_PetReminder_Update")
    table.insert(UPDATE_FUNCS, "MI_DeathReminder_Update")
    table.insert(UPDATE_FUNCS, "MI_DiveReminder_Update")
    table.insert(UPDATE_FUNCS, "MI_CheatDeathReminder_Update")
    table.insert(UPDATE_FUNCS, "MI_MulchReminder_Update")
    table.insert(UPDATE_FUNCS, "MI_OverloadReminder_Update")

    table.insert(ENABLE_KEYS, "combat_buffReminder_enabled")
    table.insert(ENABLE_KEYS, "combat_petReminder_enabled")
    table.insert(ENABLE_KEYS, "combat_petIdleReminder_enabled")
    table.insert(ENABLE_KEYS, "combat_deathReminder_enabled")
    table.insert(ENABLE_KEYS, "combat_diveReminder_enabled")
    table.insert(ENABLE_KEYS, "combat_cheatDeathReminder_enabled")
    table.insert(ENABLE_KEYS, "combat_mulchReminder_enabled")
    table.insert(ENABLE_KEYS, "combat_overloadReminder_enabled")
end

if addon.FOREVER then
    table.insert(UPDATE_FUNCS, "MI_ClassBuffs_Update")
    if addon.MI_ClassBuffs_AllKeys then
        for _, key in ipairs(addon.MI_ClassBuffs_AllKeys()) do
            table.insert(ENABLE_KEYS, key)
        end
    end
    table.insert(UPDATE_FUNCS, "MI_CampfireReminder_Update")
    table.insert(UPDATE_FUNCS, "MI_BuffReminder_Update")
    table.insert(ENABLE_KEYS, "forever_campfireReminder_enabled")
    table.insert(ENABLE_KEYS, "combat_sealReminder_enabled")
end

local function updateReminders()
    for _, name in ipairs(UPDATE_FUNCS) do
        local update = addon[name]
        if update then update() end
    end
end

-- At most twice a second, UNIT_AURA spams in raids
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
    eventFrame:RegisterUnitEvent("UNIT_AURA",            "player")
    eventFrame:RegisterUnitEvent("UNIT_PET",             "player")
    eventFrame:RegisterUnitEvent("UNIT_FLAGS",           "player", "pet")
    eventFrame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    eventFrame:RegisterUnitEvent("UNIT_EXITED_VEHICLE",  "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP",  "player")
    eventFrame:RegisterEvent("PET_BAR_UPDATE")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    -- Seal Reminder reads Judgement's usable state in combat, where buffs are hidden.
    if addon.FOREVER then
        eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
        -- Class buffs: Thorns in bear form only, Righteous Fury with a shield only.
        eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        -- Poisons and weapon imbues are not auras.
        eventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
        pcall(eventFrame.RegisterEvent, eventFrame, "WEAPON_ENCHANT_CHANGED")
    end
    eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
    eventFrame:SetScript("OnEvent", function()
        updateRemindersThrottled()
    end)
    -- Catches taxis and anything the events miss
    ticker = C_Timer.NewTicker(5, updateReminders)
end

local function UnregisterReminderEvents()
    if not eventsRegistered then return end
    eventsRegistered = false
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    if ticker then ticker:Cancel() ticker = nil end
    if pendingTimer then pendingTimer:Cancel() pendingTimer = nil end
end

local function AnyReminderEnabled()
    local db = addon.db
    for _, key in ipairs(ENABLE_KEYS) do
        if db[key] then return true end
    end
    return false
end

function addon.MI_Reminders_Init()
    local _, class = UnitClass("player")
    addon.playerClass = class
    if AnyReminderEnabled() then
        RegisterReminderEvents()
        updateReminders()
    end
end

-- Any reminder toggle in settings
function addon.MI_Reminders_RefreshState()
    if AnyReminderEnabled() then
        RegisterReminderEvents()
        updateReminders()
    else
        -- One last update so anything still showing gets hidden
        updateReminders()
        UnregisterReminderEvents()
    end
end
