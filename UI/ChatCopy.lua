local _, addon = ...

local StripHyperlinks = StripHyperlinks or (C_StringUtil and C_StringUtil.StripHyperlinks)

-- ── Constants ────────────────────────────────────────────────────────────────

local BUTTON_SIZE   = 18
local COPY_WIDTH    = 600
local COPY_HEIGHT   = 400
local BAR_TEX       = [[Interface\Buttons\WHITE8x8]]
local FONT          = "Fonts\\FRIZQT__.TTF"

-- ── Copy window ──────────────────────────────────────────────────────────────

local copyFrame, copyEdit, copyScroll

local function BuildCopyFrame()
    if copyFrame then return end

    copyFrame = CreateFrame("Frame", "MysteriousQoL_ChatCopyFrame", UIParent, "BackdropTemplate")
    copyFrame:SetSize(COPY_WIDTH, COPY_HEIGHT)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetFrameStrata("DIALOG")
    copyFrame:SetFrameLevel(200)
    copyFrame:SetClampedToScreen(true)
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:RegisterForDrag("LeftButton")
    copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
    copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
    copyFrame:SetBackdrop({
        bgFile   = BAR_TEX,
        edgeFile = BAR_TEX,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    copyFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    copyFrame:SetBackdropBorderColor(0, 0.5, 0.5, 0.6)
    copyFrame:Hide()

    table.insert(UISpecialFrames, "MysteriousQoL_ChatCopyFrame")

    -- Top accent
    local accent = copyFrame:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(0, 0.8, 0.8, 1)

    -- Title
    local title = copyFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 13, "OUTLINE")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetTextColor(0, 0.8, 0.8, 1)
    title:SetText("Chat Copy")

    -- Hint
    local hint = copyFrame:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 10, "")
    hint:SetPoint("LEFT", title, "RIGHT", 10, 0)
    hint:SetTextColor(0.5, 0.5, 0.5, 1)
    hint:SetText("Ctrl+A to select all, Ctrl+C to copy")

    -- Close button
    local close = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() copyFrame:Hide() end)

    -- Scroll frame
    copyScroll = CreateFrame("ScrollFrame", "MysteriousQoL_ChatCopyScroll", copyFrame, "UIPanelScrollFrameTemplate")
    copyScroll:SetPoint("TOPLEFT", 8, -28)
    copyScroll:SetPoint("BOTTOMRIGHT", -28, 8)

    -- EditBox
    copyEdit = CreateFrame("EditBox", nil, copyScroll)
    copyEdit:SetMultiLine(true)
    copyEdit:SetAutoFocus(false)
    copyEdit:SetFont(FONT, 12, "")
    copyEdit:SetTextColor(1, 1, 1, 1)
    copyEdit:SetWidth(COPY_WIDTH - 40)
    copyEdit:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    copyScroll:SetScrollChild(copyEdit)
end

-- ── Extract chat messages ────────────────────────────────────────────────────

local function CleanText(text)
    text = text:gsub("|K.-|k", "???")       -- encrypted/secret values
    if StripHyperlinks then
        return StripHyperlinks(text, false, true)
    end
    -- Fallback if StripHyperlinks unavailable
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return text
end

local function GetChatMessages(chatFrame)
    local lines = {}
    local numMessages = chatFrame:GetNumMessages()

    if numMessages and numMessages > 0 then
        for i = 1, numMessages do
            local msg = chatFrame:GetMessageInfo(i)
            if msg and msg ~= "" then
                table.insert(lines, CleanText(msg))
            end
        end
    end

    -- Fallback: historyBuffer
    if #lines == 0 then
        local buffer = chatFrame.historyBuffer
        if buffer then
            local count = buffer:GetNumElements()
            if count and count > 0 then
                for i = count, 1, -1 do
                    local entry = buffer:GetEntryAtIndex(i)
                    if entry and entry.message then
                        table.insert(lines, CleanText(entry.message))
                    end
                end
            end
        end
    end

    if #lines == 0 then
        return "(No chat messages found)"
    end
    return table.concat(lines, "\n")
end

local function OpenCopyWindow(chatFrame)
    BuildCopyFrame()
    local text = GetChatMessages(chatFrame)
    copyEdit:SetTextColor(1, 1, 1, 1)
    copyEdit:SetText(text)
    copyFrame:Show()
    copyEdit:SetFocus()
    copyEdit:HighlightText()
    -- Scroll to bottom
    C_Timer.After(0, function()
        copyScroll:SetVerticalScroll(copyScroll:GetVerticalScrollRange())
    end)
end

-- ── Chat frame buttons ───────────────────────────────────────────────────────

local chatButtons = {}

local function CreateCopyButton(chatFrame, index)
    local btn = CreateFrame("Button", nil, chatFrame)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -2, -2)
    btn:SetFrameLevel(chatFrame:GetFrameLevel() + 10)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.06, 0.7)

    local icon = btn:CreateFontString(nil, "OVERLAY")
    icon:SetFont(FONT, 12, "OUTLINE")
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTextColor(0, 0.6, 0.6, 0.6)
    icon:SetText("C")

    btn:SetScript("OnEnter", function()
        icon:SetTextColor(0, 0.9, 0.9, 1)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff00ccccCopy Chat|r")
        GameTooltip:AddLine("Click to copy chat text", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        icon:SetTextColor(0, 0.6, 0.6, 0.6)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
        OpenCopyWindow(chatFrame)
    end)

    chatButtons[index] = btn
    return btn
end

local function UpdateButtonVisibility()
    local show = addon.db.ui_chatCopy_enabled
    for _, btn in pairs(chatButtons) do
        btn:SetShown(show)
    end
end

-- ── Init ─────────────────────────────────────────────────────────────────────

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    if not addon.db.ui_chatCopy_enabled then return end

    -- Add copy button to each chat tab
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            CreateCopyButton(chatFrame, i)
        end
    end
end)

function addon.MI_ChatCopy_UpdateVisibility()
    -- Create buttons if they don't exist yet
    if not chatButtons[1] and addon.db.ui_chatCopy_enabled then
        for i = 1, NUM_CHAT_WINDOWS do
            local chatFrame = _G["ChatFrame" .. i]
            if chatFrame then
                CreateCopyButton(chatFrame, i)
            end
        end
    end
    UpdateButtonVisibility()
end
