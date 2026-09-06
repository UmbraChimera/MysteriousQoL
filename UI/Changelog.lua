local _, addon = ...

-- WoW add-ons cannot read packaged Markdown files at runtime. Keep this compact
-- in-game summary aligned with CHANGELOG.md instead of duplicating every detail.
local RELEASE_NOTES = [[
|cff20d5e8Version 1.4.0|r
Ready Check Preflight: personal gear and consumable checks, plus Healthstone and group Soulstone coverage when a Warlock is present.

|cff20d5e8Version 1.3.0|r
Gear indicators, improved settings reliability, Victory Sound, UI/reminder fixes, and Guild Manager retirement.

|cff20d5e8Version 1.2.2|r
No Pet Sound, Hide Error Messages, and Retail 12.0.7 / 12.1 support.

|cff20d5e8Earlier releases|r
Core QoL features: custom settings, skyriding tracker, combat reminders, vendor automation, and sound effects.
]]

local BAR_TEXTURE = [[Interface\Buttons\WHITE8x8]]
local frame

local function createFrame()
    if frame then return end

    frame = CreateFrame("Frame", "MysteriousQoL_ChangelogFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 390)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(210)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = BAR_TEXTURE,
        edgeFile = BAR_TEXTURE,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.045, 0.05, 0.06, 0.98)
    frame:SetBackdropBorderColor(0.008, 0.486, 0.565, 0.8)
    frame:Hide()
    table.insert(UISpecialFrames, "MysteriousQoL_ChangelogFrame")

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(3)
    accent:SetColorTexture(0.008, 0.486, 0.565, 1)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    title:SetPoint("TOPLEFT", 18, -14)
    title:SetTextColor(1, 1, 1, 1)
    title:SetText("CHANGELOG")

    local subtitle = frame:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -3)
    subtitle:SetTextColor(0.5, 0.6, 0.63, 1)
    subtitle:SetText("Recent highlights - drag to move")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -4)
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -58)
    scroll:SetPoint("BOTTOMRIGHT", -32, 16)

    local body = CreateFrame("Frame", nil, scroll)
    body:SetWidth(432)
    local text = body:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetPoint("TOPRIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetTextColor(0.9, 0.92, 0.94, 1)
    text:SetText(RELEASE_NOTES)
    body:SetHeight(text:GetStringHeight() + 8)
    scroll:SetScrollChild(body)
end

function addon.MI_Changelog_Toggle()
    createFrame()
    frame:SetShown(not frame:IsShown())
end
