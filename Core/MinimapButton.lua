local addonName, addon = ...

-- Minimap button via LibDBIcon-1.0.
-- Left-click opens settings, right-click opens menu, draggable.

local FONT    = "Fonts\\FRIZQT__.TTF"
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]

local ldbObject
local miniMenu, menuClickCatcher

local function BuildMinimapMenu()
    -- Click-catcher at FULLSCREEN strata dismisses the menu when clicking outside it.
    menuClickCatcher = CreateFrame("Frame", nil, UIParent)
    menuClickCatcher:SetAllPoints(UIParent)
    menuClickCatcher:SetFrameStrata("FULLSCREEN")
    menuClickCatcher:EnableMouse(true)
    menuClickCatcher:Hide()
    menuClickCatcher:SetScript("OnMouseDown", function()
        miniMenu:Hide()
        menuClickCatcher:Hide()
    end)

    miniMenu = CreateFrame("Frame", "MysteriousQoL_MinimapMenu", UIParent, "BackdropTemplate")
    miniMenu:SetSize(152, 50)
    miniMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    miniMenu:SetClampedToScreen(true)
    miniMenu:SetBackdrop({
        bgFile = BAR_TEX, edgeFile = BAR_TEX, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    miniMenu:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    miniMenu:SetBackdropBorderColor(0, 0.5, 0.5, 0.8)
    miniMenu:Hide()

    local function AddItem(label, yOffset, onClick)
        local item = CreateFrame("Button", nil, miniMenu)
        item:SetSize(146, 22)
        item:SetPoint("TOPLEFT", 3, yOffset)
        local fs = item:CreateFontString(nil, "OVERLAY")
        fs:SetFont(FONT, 11, "")
        fs:SetPoint("LEFT", 8, 0)
        fs:SetTextColor(0.85, 0.85, 0.85, 1)
        fs:SetText(label)
        item:SetScript("OnEnter", function() fs:SetTextColor(0, 0.85, 0.85, 1) end)
        item:SetScript("OnLeave", function() fs:SetTextColor(0.85, 0.85, 0.85, 1) end)
        item:SetScript("OnClick", function()
            miniMenu:Hide()
            menuClickCatcher:Hide()
            onClick()
        end)
    end

    AddItem("Open Settings", -2, function()
        if addon.customUI and addon.customUI.Toggle then addon.customUI.Toggle() end
    end)
    AddItem("Hide Button", -24, function()
        addon.db.ui_minimapButton_enabled = false
        addon.db.minimapIcon.hide = true
        LibStub("LibDBIcon-1.0"):Hide("MysteriousQoL")
        print("|cff00ccccMysteriousQoL|r: Minimap button hidden. Use /mqol to re-enable it.")
    end)
end

local function ToggleMinimapMenu(button)
    if not miniMenu then BuildMinimapMenu() end
    if miniMenu:IsShown() then
        miniMenu:Hide()
        menuClickCatcher:Hide()
    else
        miniMenu:ClearAllPoints()
        miniMenu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", -10, 4)
        miniMenu:Show()
        menuClickCatcher:Show()
    end
end

function addon.MI_MinimapButton_Init()
    local LDB     = LibStub("LibDataBroker-1.1")
    local DBIcon  = LibStub("LibDBIcon-1.0")

    -- Sync hide state from the enabled flag (covers first login after migration).
    addon.db.minimapIcon.hide = not addon.db.ui_minimapButton_enabled

    ldbObject = LDB:NewDataObject("MysteriousQoL", {
        type = "launcher",
        icon = "Interface\\AddOns\\MysteriousQoL\\MysteriousQoL",
        OnClick = function(self, btn)
            if btn == "RightButton" then
                ToggleMinimapMenu(self)
                return
            end
            if addon.customUI and addon.customUI.Toggle then
                addon.customUI.Toggle()
            end
        end,
        OnTooltipShow = function(tip)
            tip:SetText("|cff00ccccMysteriousQoL|r", 1, 1, 1)
            tip:AddLine("Left-click: Open Settings", 0.7, 0.7, 0.7)
            tip:AddLine("Right-click: Menu", 0.7, 0.7, 0.7)
            tip:AddLine("Drag: Reposition", 0.7, 0.7, 0.7)
        end,
    })

    DBIcon:Register("MysteriousQoL", ldbObject, addon.db.minimapIcon)
end

function addon.MI_MinimapButton_SetShown(show)
    local DBIcon = LibStub("LibDBIcon-1.0")
    addon.db.ui_minimapButton_enabled = show
    addon.db.minimapIcon.hide = not show
    if show then
        DBIcon:Show("MysteriousQoL")
    else
        DBIcon:Hide("MysteriousQoL")
    end
end
