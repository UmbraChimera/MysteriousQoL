local _, addon = ...

-- Auto-clicks "Sign Up" in the LFG application dialog.
-- Hold Ctrl to bypass and see the dialog normally.

local hooked

local function ConfirmApplication()
    if not addon.db or not addon.db.general_skipQueueConfirm then return end
    if IsControlKeyDown() then return end
    if LFGListApplicationDialog and LFGListApplicationDialog.SignUpButton
        and LFGListApplicationDialog.SignUpButton:IsEnabled()
    then
        LFGListApplicationDialog.SignUpButton:Click()
    end
end

local function TryInstallHook()
    if hooked or not LFGListApplicationDialog then return hooked end

    LFGListApplicationDialog:HookScript("OnShow", ConfirmApplication)

    hooked = true
    if LFGListApplicationDialog:IsShown() then
        C_Timer.After(0, ConfirmApplication)
    end
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
    if TryInstallHook() then
        self:UnregisterAllEvents()
    end
end)

-- The Group Finder may already exist when this file is evaluated.
TryInstallHook()
