local _, addon = ...

-- Plays mail.ogg on initial login if the player has unread mail.
-- Invoked by the central dispatcher on PLAYER_ENTERING_WORLD with isInitialLogin = true.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Reminders\\mail.ogg"

function addon.MI_MailReminder_OnLogin()
    if not addon.db.combat_mailReminder_enabled then return end
    -- Delay slightly to let mail status populate
    C_Timer.After(2, function()
        if HasNewMail() then
            PlaySoundFile(SOUND, "Master")
        end
    end)
end
