local _, addon = ...

-- Center-screen reminders for:
--   • Missing class buff (buff-providing classes only)
--   • No active pet (Warlock / Hunter BM+Survival)
--   • Pet idle in combat (same classes)
--   • Don't release in a raid instance

-- ── Update logic ───────────────────────────────────────────────────────────────

local function updateReminders()
    addon.MI_BuffReminder_Update()
    addon.MI_PetReminder_Update()
    addon.MI_DeathReminder_Update()
end

-- ── Event handling ─────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
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
eventFrame:SetScript("OnEvent", function() updateReminders() end)

-- ── Lifecycle ──────────────────────────────────────────────────────────────────

function addon.MI_Reminders_Init()
    local _, class = UnitClass("player")
    addon.playerClass = class
    -- Fallback ticker for taxi and edge cases not covered by events
    C_Timer.NewTicker(5, updateReminders)
    updateReminders()
end

-- ── Settings ───────────────────────────────────────────────────────────────────

function addon.MI_Reminders_RegisterSettings(combatCat, combatLayout)
    addon.MI_BuffReminder_RegisterSettings(combatCat, combatLayout)
    addon.MI_PetReminder_RegisterSettings(combatCat, combatLayout)
    addon.MI_DeathReminder_RegisterSettings(combatCat, combatLayout)
end
