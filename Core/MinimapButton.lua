local addonName, addon = ...

-- No-library minimap button. Draggable around the minimap ring.
-- Left-click toggles the custom settings frame.

local RADIUS = 104
local BUTTON_SIZE = 31
local FONT = "Fonts\\FRIZQT__.TTF"
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]

local button
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
    miniMenu:SetSize(152, 72)
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
    AddItem("Guild Manager", -24, function()
        if addon.MI_GuildPanel_Toggle then addon.MI_GuildPanel_Toggle() end
    end)
    AddItem("Hide Button", -46, function()
        addon.db.ui_minimapButton_enabled = false
        button:Hide()
        print("|cff00ccccMysteriousQoL|r: Minimap button hidden. Use /mqol to re-enable it.")
    end)
end

local function ToggleMinimapMenu()
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

local function UpdatePosition()
    if not button then return end
    local angle = math.rad(addon.db.ui_minimapButton_angle or 220)
    local x = math.cos(angle) * RADIUS
    local y = math.sin(angle) * RADIUS
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function BuildButton()
    button = CreateFrame("Button", "MysteriousQoL_MinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(true)

    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\MysteriousQoL\\MysteriousQoL")

    -- Standard WoW minimap border overlay
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff00ccccMysteriousQoL|r", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Open Settings", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: Menu", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag: Reposition", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            ToggleMinimapMenu()
            return
        end
        if addon.customUI and addon.customUI.Toggle then
            addon.customUI.Toggle()
        end
    end)

    -- Drag around minimap
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            if not cx then return end
            local mx, my = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            mx, my = mx / scale, my / scale
            local angle = math.atan2(my - cy, mx - cx)
            addon.db.ui_minimapButton_angle = math.deg(angle)
            UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)

    UpdatePosition()
end

function addon.MI_MinimapButton_Init()
    BuildButton()
    if not addon.db.ui_minimapButton_enabled then
        button:Hide()
    end
end

function addon.MI_MinimapButton_SetShown(show)
    if button then
        button:SetShown(show)
    end
end
