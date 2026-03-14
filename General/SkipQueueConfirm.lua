local _, addon = ...

-- Auto-clicks "Sign Up" in the LFG application dialog.
-- Hold Ctrl to bypass and see the dialog normally.

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()

    if LFGListApplicationDialog then
        LFGListApplicationDialog:HookScript("OnShow", function()
            if not addon.db.general_skipQueueConfirm then return end
            if IsControlKeyDown() then return end
            if LFGListApplicationDialog.SignUpButton
                and LFGListApplicationDialog.SignUpButton:IsEnabled()
            then
                LFGListApplicationDialog.SignUpButton:Click()
            end
        end)
    end
end)
