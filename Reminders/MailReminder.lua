local _, addon = ...

-- Plays mail.ogg on initial login if the player has unread mail.
-- Kept separate from the visual reminder dispatcher so this login-only feature
-- does not keep the full reminder event set and fallback ticker active.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Reminders\\mail.ogg"
local pendingTimer = nil

function addon.MI_MailReminder_OnLogin()
    if not addon.db.combat_mailReminder_enabled then return end
    -- Delay slightly to let mail status populate
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
        -- PLAYER_ENTERING_WORLD can fire again after instance transitions; the
        -- mail reminder is intentionally only evaluated for the login event.
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
