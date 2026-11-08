local _, addon = ...

-- Plays a sound at login if you have unread mail. Not part of Reminders.lua
-- since it only runs once.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Reminders\\mail.ogg"
local pendingTimer = nil

function addon.MI_MailReminder_OnLogin()
    if not addon.db.combat_mailReminder_enabled then return end
    -- Mail status isn't ready right at login
    pendingTimer = C_Timer.NewTimer(2, function()
        pendingTimer = nil
        if addon.db.combat_mailReminder_enabled and HasNewMail() then
            PlaySoundFile(SOUND, addon.db.sound_channel)
        end
    end)
end

local mailFrame = CreateFrame("Frame")
local initialized = false

function addon.MI_MailReminder_Init()
    if initialized then return end
    initialized = true
    mailFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    mailFrame:SetScript("OnEvent", function(self, _, isInitialLogin)
        -- Login only, not every loading screen.
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if isInitialLogin then
            addon.MI_MailReminder_OnLogin()
        end
    end)
end

function addon.MI_MailReminder_SetEnabled(enabled)
    if not enabled and pendingTimer then
        pendingTimer:Cancel()
        pendingTimer = nil
    end
end
