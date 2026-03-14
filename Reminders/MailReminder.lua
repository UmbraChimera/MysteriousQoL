local _, addon = ...

-- Plays mail.ogg on initial login if the player has unread mail.
-- Does NOT fire on /reload or zone transitions -only the first login.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Reminders\\mail.ogg"

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, _, isInitialLogin)
    if not isInitialLogin then return end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    if not addon.db.combat_mailReminder_enabled then return end

    -- Delay slightly to let mail status populate
    C_Timer.After(2, function()
        if HasNewMail() then
            PlaySoundFile(SOUND, "Master")
        end
    end)
end)
