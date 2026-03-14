local _, addon = ...

-- Skips the "type DELETE" confirmation when destroying items.
-- Hooks StaticPopup_Show to detect delete dialogs and auto-fill the text.

local DELETE_STRING = DELETE_ITEM_CONFIRM_STRING or "DELETE"

local function TryAutoFill()
    if not addon.db.general_easyDestroy then return end

    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() and
           (popup.which == "DELETE_GOOD_ITEM" or popup.which == "DELETE_GOOD_QUEST_ITEM") then
            local editBox = _G["StaticPopup" .. i .. "EditBox"]
            local button  = _G["StaticPopup" .. i .. "Button1"]
            if editBox then
                editBox:SetText(DELETE_STRING)
                editBox:Hide()
            end
            if button then button:Enable() end
            return
        end
    end
end

hooksecurefunc("StaticPopup_Show", function(which)
    if which == "DELETE_GOOD_ITEM" or which == "DELETE_GOOD_QUEST_ITEM" then
        C_Timer.After(0, TryAutoFill)
    end
end)
