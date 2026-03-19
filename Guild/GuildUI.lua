local _, addon = ...

local GU = {}
addon.GuildUI = GU

local FONT    = "Fonts\\FRIZQT__.TTF"
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]

GU.FONT     = FONT
GU.FONT_HDR = "Interface\\AddOns\\MysteriousQoL\\Fonts\\DejaVuLGCSans.ttf"

GU.GOLD_R,  GU.GOLD_G,  GU.GOLD_B  = 0.90, 0.76, 0.22
GU.GOLD_BR, GU.GOLD_BG, GU.GOLD_BB = 0.50, 0.40, 0.09
GU.RED_R,   GU.RED_G,   GU.RED_B   = 1.00, 0.40, 0.40
GU.RED_BR,  GU.RED_BG,  GU.RED_BB  = 0.55, 0.10, 0.10

function GU.MakeBackdrop()
    return { bgFile = BAR_TEX, edgeFile = BAR_TEX, edgeSize = 1,
             insets = { left = 1, right = 1, top = 1, bottom = 1 } }
end

function GU.StyleButton(btn, r, g, b)
    btn:SetBackdrop(GU.MakeBackdrop())
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
    btn:SetBackdropBorderColor(r, g, b, 0.7)
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(r, g, b, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(r, g, b, 0.7) end)
end

function GU.StyleGoldButton(btn) GU.StyleButton(btn, GU.GOLD_BR, GU.GOLD_BG, GU.GOLD_BB) end
function GU.StyleRedButton(btn)  GU.StyleButton(btn, GU.RED_BR,  GU.RED_BG,  GU.RED_BB)  end

function GU.MakeLabel(parent, font, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or FONT, size or 11, "")
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    return fs
end

-- Draggable scrollbar attached to the right of scrollFrame.
function GU.MakeScrollbar(scrollFrame, scrollChild, thumbMinH)
    thumbMinH = thumbMinH or 16
    local track = CreateFrame("Frame", nil, scrollFrame:GetParent())
    track:SetWidth(5)
    track:SetPoint("TOPLEFT",    scrollFrame, "TOPRIGHT",    1, 0)
    track:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 1, 0)
    track:EnableMouse(true)
    local bg = track:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.12, 0.10, 0.03, 0.35)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(4); thumb:Hide(); thumb:EnableMouse(true)
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints(); thumbTex:SetColorTexture(0.55, 0.44, 0.10, 0.75)

    local function UpdateThumb()
        local childH = scrollChild:GetHeight(); local viewH = scrollFrame:GetHeight()
        if childH <= viewH then thumb:Hide(); return end
        thumb:Show()
        local trackH = track:GetHeight(); if trackH <= 0 then return end
        local thumbH = math.max(thumbMinH, trackH * viewH / childH)
        thumb:SetHeight(thumbH)
        local maxS  = scrollFrame:GetVerticalScrollRange()
        local cur   = scrollFrame:GetVerticalScroll()
        local ratio = maxS > 0 and (cur / maxS) or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -ratio * (trackH - thumbH))
    end

    local function CursorUIY() return select(2, GetCursorPosition()) / UIParent:GetEffectiveScale() end
    local dragging, dragStartY, dragStartScroll = false, 0, 0

    thumb:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        dragging = true; dragStartY = CursorUIY(); dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    thumb:SetScript("OnMouseUp", function() dragging = false end)
    thumb:SetScript("OnUpdate", function()
        if not dragging then return end
        local tTop = track:GetTop(); local tBot = track:GetBottom()
        if not tTop or not tBot then return end
        local trackH_UI = tTop - tBot
        local thumbH_UI = (thumb:GetTop() and thumb:GetBottom()) and (thumb:GetTop() - thumb:GetBottom()) or 0
        local range = trackH_UI - thumbH_UI; if range <= 0 then return end
        local delta = dragStartY - CursorUIY()
        local maxS  = scrollFrame:GetVerticalScrollRange()
        scrollFrame:SetVerticalScroll(math.max(0, math.min(maxS, dragStartScroll + (delta / range) * maxS)))
        UpdateThumb()
    end)
    track:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        local thumbTop = thumb:IsShown() and thumb:GetTop()
        local cur = scrollFrame:GetVerticalScroll(); local viewH = scrollFrame:GetHeight()
        local maxS = scrollFrame:GetVerticalScrollRange()
        if thumbTop and CursorUIY() > thumbTop then
            scrollFrame:SetVerticalScroll(math.max(0, cur - viewH))
        else
            scrollFrame:SetVerticalScroll(math.min(maxS, cur + viewH))
        end
        UpdateThumb()
    end)
    scrollFrame:HookScript("OnVerticalScroll",     UpdateThumb)
    scrollFrame:HookScript("OnScrollRangeChanged", UpdateThumb)
end
