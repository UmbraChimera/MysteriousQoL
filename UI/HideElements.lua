local _, addon = ...

-- Hides various UI clutter elements. Blizzard creates several of these frames
-- lazily, so hooks are installed both immediately and after every addon load.

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

local alertsHooked = false
local alertFramesHooked = setmetatable({}, { __mode = "k" })

local function suppressAlertFrame(frame)
    if not frame or type(frame.Hide) ~= "function" then return end

    if not alertFramesHooked[frame] and type(frame.HookScript) == "function" then
        alertFramesHooked[frame] = true
        frame:HookScript("OnShow", function(self)
            if addon.db and addon.db.ui_hideAlerts_enabled then
                self:Hide()
            end
        end)
    end

    if addon.db and addon.db.ui_hideAlerts_enabled then
        frame:Hide()
    end
end

local function suppressActiveAlerts()
    if not AlertFrame then return end

    for alertFrame in pairs(alertFramesHooked) do
        suppressAlertFrame(alertFrame)
    end

    -- Blizzard reparents active alerts to UIParent. Enumerate each registered
    -- subsystem's active pool rather than relying on AlertFrame's children.
    if type(AlertFrame.alertFrameSubSystems) == "table" then
        for _, subSystem in pairs(AlertFrame.alertFrameSubSystems) do
            local pool = type(subSystem) == "table" and subSystem.alertFramePool
            if pool and type(pool.EnumerateActive) == "function" then
                for alertFrame in pool:EnumerateActive() do
                    suppressAlertFrame(alertFrame)
                end
            end
        end
    end
    -- Retain the child walk for older layouts and non-pooled alert frames.
    for _, child in ipairs({ AlertFrame:GetChildren() }) do
        suppressAlertFrame(child)
    end
end

local function hookAlerts()
    if alertsHooked or not AlertFrame or type(AlertFrame.AddAlertFrame) ~= "function" then return end
    alertsHooked = true

    hooksecurefunc(AlertFrame, "AddAlertFrame", function(_, alertFrame)
        suppressAlertFrame(alertFrame)
    end)
end

local function applyAlertVisibility()
    hookAlerts()
    if not AlertFrame then return end

    if addon.db.ui_hideAlerts_enabled then suppressActiveAlerts() end
end

local talkingHeadHooked = false
local talkingHeadSuppressed = false

local function hookTalkingHead()
    if talkingHeadHooked or not TalkingHeadFrame
        or type(TalkingHeadFrame.HookScript) ~= "function" then return end
    talkingHeadHooked = true

    -- OnShow also catches UpdateShownState()->SetShown(true), not just direct
    -- calls to the frame's Show method.
    TalkingHeadFrame:HookScript("OnShow", function(self)
        if addon.db and addon.db.ui_hideTalkingHead_enabled then
            talkingHeadSuppressed = true
            self:Hide()
        end
    end)
end

local function applyTalkingHeadVisibility()
    hookTalkingHead()
    if not TalkingHeadFrame then return end

    if addon.db.ui_hideTalkingHead_enabled then
        if TalkingHeadFrame:IsShown() then talkingHeadSuppressed = true end
        TalkingHeadFrame:Hide()
    elseif talkingHeadSuppressed then
        talkingHeadSuppressed = false
        -- Let Blizzard decide whether dialogue is still playing instead of
        -- resurrecting a completed talking-head scene.
        if type(TalkingHeadFrame.UpdateShownState) == "function" then
            TalkingHeadFrame:UpdateShownState()
        end
    end
end

local toastsHooked = false
local toastClosePending = false

local function closeEventToasts()
    if toastClosePending or not EventToastManagerFrame then return end
    toastClosePending = true
    C_Timer.After(0, function()
        toastClosePending = false
        if addon.db and addon.db.ui_hideEventToasts_enabled
            and EventToastManagerFrame and EventToastManagerFrame.CloseActiveToasts then
            EventToastManagerFrame:CloseActiveToasts()
        end
    end)
end

local function hookEventToasts()
    if toastsHooked or not EventToastManagerFrame
        or type(EventToastManagerFrame.DisplayToast) ~= "function" then return end
    toastsHooked = true

    hooksecurefunc(EventToastManagerFrame, "DisplayToast", function()
        if addon.db and addon.db.ui_hideEventToasts_enabled then
            closeEventToasts()
        end
    end)
end

local function applyEventToastVisibility()
    hookEventToasts()
    if addon.db.ui_hideEventToasts_enabled then
        closeEventToasts()
    end
end

local zoneFramesHooked = {}
local zoneAnimationsHooked = {}

local function suppressZoneFrame(frame)
    if not frame then return end
    for _, group in ipairs({ frame:GetAnimationGroups() }) do
        group:Stop()
    end
    frame:SetAlpha(0)
    frame:Hide()
end

local function hookZoneFrame(frame)
    if not frame then return end

    if not zoneFramesHooked[frame] then
        zoneFramesHooked[frame] = true
        hooksecurefunc(frame, "Show", function(self)
            if addon.db and addon.db.ui_hideZoneText_enabled then
                suppressZoneFrame(self)
            end
        end)
    end

    -- Zone text uses animation groups to fade independently of Show(). New
    -- groups are harmlessly picked up whenever hooks are retried.
    for _, group in ipairs({ frame:GetAnimationGroups() }) do
        if not zoneAnimationsHooked[group] then
            zoneAnimationsHooked[group] = true
            hooksecurefunc(group, "Play", function(self)
                if addon.db and addon.db.ui_hideZoneText_enabled then
                    self:Stop()
                    frame:SetAlpha(0)
                    frame:Hide()
                end
            end)
        end
    end
end

local function hookZoneText()
    hookZoneFrame(ZoneTextFrame)
    hookZoneFrame(SubZoneTextFrame)
end

local function applyZoneTextVisibility()
    hookZoneText()
    local function applyFrame(frame)
        if not frame then return end
        if addon.db.ui_hideZoneText_enabled then
            suppressZoneFrame(frame)
        else
            -- The suppressing animation path sets alpha to zero. Restore it
            -- without forcing stale zone text to become visible.
            frame:SetAlpha(1)
        end
    end
    applyFrame(ZoneTextFrame)
    applyFrame(SubZoneTextFrame)
end

local function applyErrorVisibility()
    if not UIErrorsFrame then return end
    if addon.db.ui_hideErrors_enabled then
        UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    else
        UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    end
end

local function retryHooks()
    hookAlerts()
    hookTalkingHead()
    hookEventToasts()
    hookZoneText()
end

local function applyAll()
    applySocialVisibility()
    applyAlertVisibility()
    applyTalkingHeadVisibility()
    applyEventToastVisibility()
    applyZoneTextVisibility()
    applyErrorVisibility()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event)
    retryHooks()
    if event == "PLAYER_ENTERING_WORLD" or addon.db then
        applyAll()
    end
end)

-- Core frames may already exist by the time this file is evaluated.
retryHooks()

-- Expose immediate-apply callbacks for the custom settings UI.
addon.MI_HideElements_ApplySocial = applySocialVisibility
addon.MI_HideElements_ApplyAlerts = applyAlertVisibility
addon.MI_HideElements_ApplyTalkingHead = applyTalkingHeadVisibility
addon.MI_HideElements_ApplyEventToasts = applyEventToastVisibility
addon.MI_HideElements_ApplyZoneText = applyZoneTextVisibility
addon.MI_HideElements_ApplyErrors = applyErrorVisibility
addon.MI_HideElements_ApplyAll = applyAll
