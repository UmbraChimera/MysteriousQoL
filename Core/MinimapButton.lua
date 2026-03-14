local addonName, addon = ...

-- ── Minimap Button ─────────────────────────────────────────────────────────
-- No-library minimap button. Draggable around the minimap ring.
-- Left-click toggles the custom settings frame.

local RADIUS = 104
local BUTTON_SIZE = 31

local button

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
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 6, -5)
    bg:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 6, -5)
    icon:SetTexture("Interface\\AddOns\\MysteriousQoL\\MysteriousQoL")

    -- Standard WoW minimap border overlay
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(20, 20)	
    highlight:SetPoint("TOPLEFT", 6, -5)
    highlight:SetColorTexture(1, 1, 1, 0.15)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff00ccccMysteriousQoL|r", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Open Settings", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: Hide Button", 0.7, 0.7, 0.7)
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
            addon.db.ui_minimapButton_enabled = false
            button:Hide()
            print("|cff00ccccMysteriousQoL|r: Minimap button hidden. Use /mqol to re-enable it.")
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

-- ── Init ───────────────────────────────────────────────────────────────────

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
