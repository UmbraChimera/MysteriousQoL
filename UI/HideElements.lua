local _, addon = ...

-- Hides bits of the default UI. Some of these frames only exist once their
-- Blizzard addon loads, so hooking is retried on ADDON_LOADED.

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
    if not frame or not frame.HookScript then return end

    if not alertFramesHooked[frame] then
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

    -- Active alerts get moved to UIParent, so go through the pools too.
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
    return true
end

local function applyAlertVisibility()
    hookAlerts()
    if not AlertFrame then return end

    if addon.db.ui_hideAlerts_enabled then suppressActiveAlerts() end
end

local talkingHeadHooked = false
local talkingHeadSuppressed = false

local function hookTalkingHead()
    if talkingHeadHooked or not TalkingHeadFrame then return end
    talkingHeadHooked = true

    -- OnShow and not Show, since it also gets shown through SetShown
    TalkingHeadFrame:HookScript("OnShow", function(self)
        if addon.db and addon.db.ui_hideTalkingHead_enabled then
            talkingHeadSuppressed = true
            self:Hide()
        end
    end)
    return true
end

local function applyTalkingHeadVisibility()
    hookTalkingHead()
    if not TalkingHeadFrame then return end

    if addon.db.ui_hideTalkingHead_enabled then
        if TalkingHeadFrame:IsShown() then talkingHeadSuppressed = true end
        TalkingHeadFrame:Hide()
    elseif talkingHeadSuppressed then
        talkingHeadSuppressed = false
        -- Let the game decide if it should still be up
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
    return true
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
    local added = false

    if not zoneFramesHooked[frame] then
        zoneFramesHooked[frame] = true
        added = true
        hooksecurefunc(frame, "Show", function(self)
            if addon.db and addon.db.ui_hideZoneText_enabled then
                suppressZoneFrame(self)
            end
        end)
    end

    -- Zone text fades in with its own animations, separate from Show().
    for _, group in ipairs({ frame:GetAnimationGroups() }) do
        if not zoneAnimationsHooked[group] then
            zoneAnimationsHooked[group] = true
            added = true
            hooksecurefunc(group, "Play", function(self)
                if addon.db and addon.db.ui_hideZoneText_enabled then
                    self:Stop()
                    frame:SetAlpha(0)
                    frame:Hide()
                end
            end)
        end
    end
    return added
end

local function hookZoneText()
    local a = hookZoneFrame(ZoneTextFrame)
    local b = hookZoneFrame(SubZoneTextFrame)
    return a or b
end

local function applyZoneTextVisibility()
    hookZoneText()
    local function applyFrame(frame)
        if not frame then return end
        if addon.db.ui_hideZoneText_enabled then
            suppressZoneFrame(frame)
        else
            -- Hiding set alpha to 0, put it back without showing old text
            frame:SetAlpha(1)
        end
    end
    applyFrame(ZoneTextFrame)
    applyFrame(SubZoneTextFrame)
end

-- With errors hidden, these still get shown.
local KEEP_ERROR_KEYS = {
    "ERR_INV_FULL", "ERR_BAG_FULL", "ERR_LOOT_NO_SPACE", "ERR_QUEST_LOG_FULL",
    "ERR_ITEM_MAX_COUNT", "ERR_NOT_ENOUGH_MONEY",
    "ERR_BANK_FULL", "ERR_REAGENT_BANK_FULL", "ERR_GUILD_BANK_FULL",
    "ERR_TRADE_BAG_FULL", "ERR_TRADE_TARGET_BAG_FULL", "ERR_LOOT_MASTER_INV_FULL",
    "ERR_EQUIPMENT_MANAGER_BAGS_FULL", "ERR_ITEM_INVENTORY_FULL_SATCHEL",
    "ERR_INVENTORY_TRADE_TOO_MANY_UNIQUE_ITEM", "ERR_ITEM_UNIQUE_EQUIPPABLE",
    "ERR_TAXINOTENOUGHMONEY", "ERR_MUST_REPAIR_DURABILITY",
    "ERR_OUT_OF_SOUL_SHARDS", "ERR_SPELL_FAILED_REAGENTS_GENERIC",
    "ERR_LOGOUT_FAILED",
    -- Forever camps
    "SPELL_FAILED_CUSTOM_ERROR_452",  -- You cannot make your camp here.
    "SPELL_FAILED_CUSTOM_ERROR_6003", -- Too close to a creature or object
    "SPELL_FAILED_CUSTOM_ERROR_6004", -- No room for more features
    "SPELL_FAILED_CUSTOM_ERROR_6005", -- Campfire within 100 yards
    "SPELL_FAILED_CUSTOM_ERROR_6006", -- Camp already has that feature
}
local keepErrors = nil

local function isKeptError(message)
    if not keepErrors then
        keepErrors = {}
        for _, key in ipairs(KEEP_ERROR_KEYS) do
            local text = _G[key]
            if type(text) == "string" then keepErrors[text] = true end
        end
    end
    return keepErrors[message]
end

local errorRelay = CreateFrame("Frame")
errorRelay:SetScript("OnEvent", function(_, _, errorType, message)
    -- Older clients pass only the message.
    if type(errorType) == "string" and message == nil then message = errorType end
    if type(message) == "string" and isKeptError(message) then
        UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1, 1)
    end
end)

local function applyErrorVisibility()
    if not UIErrorsFrame then return end
    if addon.db.ui_hideErrors_enabled then
        UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    else
        UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    end
    if addon.db.ui_hideErrors_enabled and addon.db.ui_hideErrors_keepImportant then
        errorRelay:RegisterEvent("UI_ERROR_MESSAGE")
    else
        errorRelay:UnregisterEvent("UI_ERROR_MESSAGE")
    end
end

-- True when something new got hooked.
local function retryHooks()
    local a = hookAlerts()
    local b = hookTalkingHead()
    local c = hookEventToasts()
    local d = hookZoneText()
    return a or b or c or d
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
-- ADDON_LOADED fires for every addon, so only reapply when it brought in a
-- frame we hadn't hooked yet (talking heads, toasts and so on load late).
f:SetScript("OnEvent", function(_, event)
    local hookedNew = retryHooks()
    if event == "PLAYER_ENTERING_WORLD" or (hookedNew and addon.db) then
        applyAll()
    end
end)

retryHooks()

addon.MI_HideElements_ApplySocial = applySocialVisibility
addon.MI_HideElements_ApplyAlerts = applyAlertVisibility
addon.MI_HideElements_ApplyTalkingHead = applyTalkingHeadVisibility
addon.MI_HideElements_ApplyEventToasts = applyEventToastVisibility
addon.MI_HideElements_ApplyZoneText = applyZoneTextVisibility
addon.MI_HideElements_ApplyErrors = applyErrorVisibility
addon.MI_HideElements_ApplyAll = applyAll
