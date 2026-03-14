local _, addon = ...

-- Hides various UI clutter elements.

-- ── Hide Social Button ──────────────────────────────────────────────────────

local function applySocialVisibility()
    if not QuickJoinToastButton then return end
    if addon.db.ui_hideSocial_enabled then
        QuickJoinToastButton:SetAlpha(0)
        QuickJoinToastButton:EnableMouse(false)
    else
        QuickJoinToastButton:SetAlpha(1)
        QuickJoinToastButton:EnableMouse(true)
    end
end

-- ── Hide Alerts ─────────────────────────────────────────────────────────────

local alertsHooked = false
local function hookAlerts()
    if alertsHooked then return end
    if not AlertFrame then return end
    alertsHooked = true

    hooksecurefunc(AlertFrame, "AddAlertFrame", function(self, frame)
        if addon.db.ui_hideAlerts_enabled and frame then
            frame:Hide()
        end
    end)
end

-- ── Hide Talking Head ───────────────────────────────────────────────────────

local talkingHeadHooked = false
local function hookTalkingHead()
    if talkingHeadHooked then return end
    if not TalkingHeadFrame then return end
    talkingHeadHooked = true

    hooksecurefunc(TalkingHeadFrame, "Show", function(self)
        if addon.db.ui_hideTalkingHead_enabled then
            self:Hide()
        end
    end)
end

-- ── Hide Event Toasts ───────────────────────────────────────────────────────

local toastsHooked = false
local function hookEventToasts()
    if toastsHooked then return end
    if not EventToastManagerFrame then return end
    toastsHooked = true

    hooksecurefunc(EventToastManagerFrame, "DisplayToast", function(self)
        if addon.db.ui_hideEventToasts_enabled then
            C_Timer.After(0.05, function()
                if self.CloseActiveToasts then
                    self:CloseActiveToasts()
                end
            end)
        end
    end)
end

-- ── Hide Zone Text ──────────────────────────────────────────────────────────

local zoneTextHooked = false
local function hookZoneText()
    if zoneTextHooked then return end
    zoneTextHooked = true

    local function suppressFrame(frame)
        if not frame then return end
        hooksecurefunc(frame, "Show", function(self)
            if addon.db.ui_hideZoneText_enabled then
                self:Hide()
            end
        end)
        -- Also suppress animation-driven fades (zone text uses SetTextAnimationWithTranslation)
        for _, group in ipairs({ frame:GetAnimationGroups() }) do
            hooksecurefunc(group, "Play", function(self)
                if addon.db.ui_hideZoneText_enabled then
                    self:Stop()
                    frame:SetAlpha(0)
                    frame:Hide()
                end
            end)
        end
    end

    suppressFrame(ZoneTextFrame)
    suppressFrame(SubZoneTextFrame)
end

local function applyZoneTextVisibility()
    hookZoneText()
    if addon.db.ui_hideZoneText_enabled then
        if ZoneTextFrame then ZoneTextFrame:Hide() end
        if SubZoneTextFrame then SubZoneTextFrame:Hide() end
    end
end

-- ── Event Handling ──────────────────────────────────────────────────────────

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_ENTERING_WORLD" then
        applySocialVisibility()
        hookAlerts()
        hookTalkingHead()
        hookEventToasts()
        applyZoneTextVisibility()
    elseif event == "ADDON_LOADED" then
        if name == "Blizzard_TalkingHeadUI" then
            hookTalkingHead()
        end
    end
end)

-- Expose for custom settings UI
function addon.MI_HideSocial_ApplySocial()
    applySocialVisibility()
end
