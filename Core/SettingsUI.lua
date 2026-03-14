local addonName, addon = ...

-- ── Custom Settings UI ─────────────────────────────────────────────────────
-- Teal-themed settings panel with horizontal top tabs, collapsible sections,
-- and parent-child checkbox gating (what the native API can't do).

-- ── Color palette ──────────────────────────────────────────────────────────

local C = {
    teal        = { 0.00, 0.80, 0.80, 1.0 },  -- #00cccc
    tealBright  = { 0.00, 0.90, 0.90, 1.0 },
    tealDim     = { 0.00, 0.40, 0.40, 1.0 },
    tealBorder  = { 0.00, 0.50, 0.50, 0.6 },
    bgMain      = { 0.06, 0.06, 0.06, 0.95 },
    bgTab       = { 0.08, 0.08, 0.08, 1.0 },
    bgWidget    = { 0.10, 0.10, 0.10, 0.8 },
    text        = { 1.00, 1.00, 1.00, 1.0 },
    textGray    = { 0.66, 0.66, 0.66, 1.0 },
    textDim     = { 0.40, 0.40, 0.40, 1.0 },
    black       = { 0.00, 0.00, 0.00, 1.0 },
    checkBg     = { 0.15, 0.15, 0.15, 1.0 },
    sliderTrack = { 0.12, 0.12, 0.12, 1.0 },
    sliderFill  = { 0.00, 0.70, 0.70, 1.0 },
}

local BAR_TEX = [[Interface\Buttons\WHITE8x8]]
local FONT    = "Fonts\\FRIZQT__.TTF"
local WIDGET_HEIGHT   = 28
local INDENT          = 24
local PADDING_LEFT    = 16
local PADDING_TOP     = 12
local SECTION_GAP     = 12
local FRAME_WIDTH     = 560
local FRAME_HEIGHT    = 500
local TAB_HEIGHT      = 28
local HEADER_HEIGHT   = 30  -- title row

-- ── State ──────────────────────────────────────────────────────────────────

local mainFrame, tabBar, contentFrame, scrollFrame, scrollChild
local activeTab = nil
local tabButtons = {}
local categoryBuilders = {}  -- { name = buildFunc() }
local allWidgets = {}        -- flat list of all widget entries for current tab
local tabCache = {}          -- { name = { widgets = {}, children = {} } } -built tabs are cached and reused

addon.customUI = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Pre-allocated backdrop tables (reused by every MakeBackdrop call to avoid per-call allocations)
local backdrop1 = { bgFile = BAR_TEX, edgeFile = BAR_TEX, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local function MakeBackdrop(frame, bgColor, borderColor, edgeSize)
    edgeSize = edgeSize or 1
    if edgeSize == 1 then
        frame:SetBackdrop(backdrop1)
    else
        frame:SetBackdrop({
            bgFile   = BAR_TEX,
            edgeFile = BAR_TEX,
            edgeSize = edgeSize,
            insets   = { left = edgeSize, right = edgeSize, top = edgeSize, bottom = edgeSize },
        })
    end
    frame:SetBackdropColor(unpack(bgColor))
    if borderColor then
        frame:SetBackdropBorderColor(unpack(borderColor))
    end
end

-- ── Layout engine ──────────────────────────────────────────────────────────

local function RecalcLayout()
    if not scrollChild then return end
    local y = -PADDING_TOP
    for _, entry in ipairs(allWidgets) do
        if entry.frame then
            if entry.visible == false then
                entry.frame:Hide()
            else
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", entry.indent or PADDING_LEFT, y)
                entry.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PADDING_LEFT, y)
                entry.frame:Show()
                y = y - (entry.height or WIDGET_HEIGHT) - 8
            end
        elseif entry.spacer then
            y = y - entry.spacer
        end
    end
    scrollChild:SetHeight(math.abs(y) + 20)
    if addon._updateScrollbar then addon._updateScrollbar() end
end

local function UpdateChildVisibility(parentKey, checked)
    for _, entry in ipairs(allWidgets) do
        if entry.parentKey == parentKey then
            entry.visible = checked
        end
    end
    RecalcLayout()
end

-- ── Widget: Section Header ─────────────────────────────────────────────────

function addon.customUI.Header(title)
    if #allWidgets > 0 then
        table.insert(allWidgets, { spacer = SECTION_GAP })
    end

    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(24)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 13, "OUTLINE")
    text:SetPoint("BOTTOMLEFT", 0, 4)
    text:SetTextColor(unpack(C.teal))
    text:SetText(title)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(unpack(C.tealDim))

    table.insert(allWidgets, { frame = frame, height = 24 })
end

-- ── Widget: Checkbox ───────────────────────────────────────────────────────

function addon.customUI.Checkbox(key, label, tooltip, onChange, children)
    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(WIDGET_HEIGHT)

    local boxSize = 18
    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetSize(boxSize, boxSize)
    box:SetPoint("LEFT", 0, 0)
    MakeBackdrop(box, C.checkBg, C.tealDim)

    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetSize(14, 14)
    check:SetPoint("CENTER")
    check:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
    check:SetVertexColor(unpack(C.teal))

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "")
    text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(C.text))
    text:SetText(label)

    if tooltip then
        local desc = frame:CreateFontString(nil, "OVERLAY")
        desc:SetFont(FONT, 10, "")
        desc:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
        desc:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        desc:SetJustifyH("LEFT")
        desc:SetTextColor(unpack(C.textGray))
        desc:SetText(tooltip)
        desc:SetWordWrap(true)

        frame:SetScript("OnShow", function()
            local lines = math.ceil((desc:GetStringWidth() or 0) / (frame:GetWidth() - boxSize - 8 - PADDING_LEFT * 2))
            local extra = 0
            if lines > 1 then extra = (lines - 1) * 12 end
            local h = WIDGET_HEIGHT + extra
            for _, e in ipairs(allWidgets) do
                if e.frame == frame then e.height = h; break end
            end
        end)
    end

    local function Refresh()
        local val = addon.db[key]
        if val then check:Show() else check:Hide() end
        if children then UpdateChildVisibility(key, val) end
    end

    local clickOverlay = CreateFrame("Button", nil, frame)
    clickOverlay:SetAllPoints()
    clickOverlay:SetScript("OnClick", function()
        addon.db[key] = not addon.db[key]
        Refresh()
        if onChange then onChange(addon.db[key]) end
    end)

    clickOverlay:SetScript("OnEnter", function() box:SetBackdropBorderColor(unpack(C.tealBright)) end)
    clickOverlay:SetScript("OnLeave", function() box:SetBackdropBorderColor(unpack(C.tealDim)) end)

    table.insert(allWidgets, { frame = frame, height = WIDGET_HEIGHT, key = key, refresh = Refresh })

    if children then
        for _, child in ipairs(children) do
            if child.type == "checkbox" then
                addon.customUI.Checkbox(child.key, child.label, child.tooltip, child.onChange)
                local childEntry = allWidgets[#allWidgets]
                childEntry.parentKey = key
                childEntry.indent = PADDING_LEFT + INDENT
                childEntry.visible = addon.db[key]
            elseif child.type == "dropdown" then
                addon.customUI.Dropdown(child.key, child.label, child.options, child.tooltip, child.onChange)
                local childEntry = allWidgets[#allWidgets]
                childEntry.parentKey = key
                childEntry.indent = PADDING_LEFT + INDENT
                childEntry.visible = addon.db[key]
            elseif child.type == "slider" then
                addon.customUI.Slider(child.key, child.label, child.min, child.max, child.step, child.tooltip, child.onChange)
                local childEntry = allWidgets[#allWidgets]
                childEntry.parentKey = key
                childEntry.indent = PADDING_LEFT + INDENT
                childEntry.visible = addon.db[key]
            end
        end
    end

    Refresh()
end

-- ── Widget: Dropdown ───────────────────────────────────────────────────────

function addon.customUI.Dropdown(key, label, options, tooltip, onChange)
    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(WIDGET_HEIGHT)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "")
    text:SetPoint("LEFT", 0, 0)
    text:SetTextColor(unpack(C.text))
    text:SetText(label)

    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("LEFT", text, "RIGHT", 12, 0)
    MakeBackdrop(btn, C.checkBg, C.tealDim)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(FONT, 11, "")
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -6, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetTextColor(unpack(C.text))

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(FONT, 11, "")
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTextColor(unpack(C.teal))
    arrow:SetText("v")

    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
    menu:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -1)
    MakeBackdrop(menu, C.bgMain, C.tealDim)
    menu:Hide()

    local menuButtons = {}
    local function CloseMenu() menu:Hide() end

    local function Refresh()
        local val = addon.db[key]
        for _, opt in ipairs(options) do
            if opt.value == val then
                btnText:SetText(opt.text)
                break
            end
        end
    end

    local menuHeight = 0
    for i, opt in ipairs(options) do
        local optBtn = CreateFrame("Button", nil, menu)
        optBtn:SetHeight(20)
        optBtn:SetPoint("TOPLEFT", 2, -(2 + (i - 1) * 20))
        optBtn:SetPoint("TOPRIGHT", -2, -(2 + (i - 1) * 20))

        local optBg = optBtn:CreateTexture(nil, "BACKGROUND")
        optBg:SetAllPoints()
        optBg:SetColorTexture(0, 0, 0, 0)

        local optText = optBtn:CreateFontString(nil, "OVERLAY")
        optText:SetFont(FONT, 11, "")
        optText:SetPoint("LEFT", 4, 0)
        optText:SetTextColor(unpack(C.text))
        optText:SetText(opt.text)

        optBtn:SetScript("OnEnter", function() optBg:SetColorTexture(unpack(C.tealDim)) end)
        optBtn:SetScript("OnLeave", function() optBg:SetColorTexture(0, 0, 0, 0) end)
        optBtn:SetScript("OnClick", function()
            addon.db[key] = opt.value
            Refresh()
            CloseMenu()
            if onChange then onChange(opt.value) end
        end)

        menuButtons[i] = optBtn
        menuHeight = menuHeight + 20
    end
    menu:SetHeight(menuHeight + 4)

    btn:SetScript("OnClick", function()
        if menu:IsShown() then CloseMenu() else menu:Show() end
    end)

    menu:SetScript("OnUpdate", function()
        if menu:IsShown() and not menu:IsMouseOver() and not btn:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") then CloseMenu() end
        end
    end)

    btn:SetScript("OnEnter", function() btn:SetBackdropBorderColor(unpack(C.tealBright)) end)
    btn:SetScript("OnLeave", function() btn:SetBackdropBorderColor(unpack(C.tealDim)) end)

    if tooltip then
        local desc = frame:CreateFontString(nil, "OVERLAY")
        desc:SetFont(FONT, 10, "")
        desc:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
        desc:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        desc:SetJustifyH("LEFT")
        desc:SetTextColor(unpack(C.textGray))
        desc:SetText(tooltip)
    end

    table.insert(allWidgets, { frame = frame, height = WIDGET_HEIGHT, key = key, refresh = Refresh })
    Refresh()
end

-- ── Widget: Slider ─────────────────────────────────────────────────────────

function addon.customUI.Slider(key, label, minVal, maxVal, step, tooltip, onChange)
    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(WIDGET_HEIGHT + 8)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetTextColor(unpack(C.text))
    text:SetText(label)

    local valText = frame:CreateFontString(nil, "OVERLAY")
    valText:SetFont(FONT, 11, "")
    valText:SetPoint("TOPRIGHT", 0, 0)
    valText:SetTextColor(unpack(C.teal))

    local track = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    track:SetHeight(10)
    track:SetPoint("TOPLEFT", 0, -18)
    track:SetPoint("TOPRIGHT", 0, -18)
    MakeBackdrop(track, C.sliderTrack, C.tealDim)

    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetHeight(8)
    fill:SetColorTexture(unpack(C.sliderFill))

    local thumb = CreateFrame("Frame", nil, track, "BackdropTemplate")
    thumb:SetSize(12, 14)
    thumb:SetFrameLevel(track:GetFrameLevel() + 2)
    MakeBackdrop(thumb, C.teal, C.black)

    local function Refresh()
        local val = addon.db[key] or minVal
        val = math.max(minVal, math.min(maxVal, val))
        local pct = (val - minVal) / (maxVal - minVal)
        local trackWidth = track:GetWidth() - 2
        if trackWidth > 0 then
            fill:SetWidth(math.max(1, pct * trackWidth))
            thumb:ClearAllPoints()
            thumb:SetPoint("CENTER", track, "LEFT", 1 + pct * trackWidth, 0)
        end
        if step >= 1 then
            valText:SetText(tostring(math.floor(val)))
        else
            valText:SetText(string.format("%.1f", val))
        end
    end

    local dragging = false
    local function SetFromMouse()
        local left = track:GetLeft()
        local right = track:GetRight()
        if not left or not right or right <= left then return end
        local cx = GetCursorPosition() / track:GetEffectiveScale()
        local pct = (cx - left) / (right - left)
        pct = math.max(0, math.min(1, pct))
        local raw = minVal + pct * (maxVal - minVal)
        local snapped = math.floor(raw / step + 0.5) * step
        snapped = math.max(minVal, math.min(maxVal, snapped))
        addon.db[key] = snapped
        Refresh()
        if onChange then onChange(snapped) end
    end

    local dragOverlay = CreateFrame("Button", nil, track)
    dragOverlay:SetAllPoints()
    dragOverlay:SetScript("OnMouseDown", function() dragging = true; SetFromMouse() end)
    dragOverlay:SetScript("OnMouseUp", function() dragging = false end)
    dragOverlay:SetScript("OnUpdate", function() if dragging then SetFromMouse() end end)

    dragOverlay:EnableMouseWheel(true)
    dragOverlay:SetScript("OnMouseWheel", function(_, delta)
        local val = (addon.db[key] or minVal) + delta * step
        val = math.max(minVal, math.min(maxVal, val))
        addon.db[key] = val
        Refresh()
        if onChange then onChange(val) end
    end)

    -- Defer initial refresh until track has width (OnUpdate one-shot)
    frame:SetScript("OnShow", function(self)
        self:SetScript("OnUpdate", function(self2)
            if track:GetWidth() > 0 then
                self2:SetScript("OnUpdate", nil)
                Refresh()
            end
        end)
    end)

    table.insert(allWidgets, { frame = frame, height = WIDGET_HEIGHT + 8, key = key, refresh = Refresh })
end

-- ── Category registration ──────────────────────────────────────────────────

function addon.customUI.RegisterCategory(name, buildFunc)
    categoryBuilders[name] = buildFunc
end

-- ── Build horizontal tab button ──────────────────────────────────────────

local function CreateTabButton(parent, name, index, totalTabs)
    local tabWidth = (FRAME_WIDTH - 2) / totalTabs
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(tabWidth, TAB_HEIGHT)
    btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", (index - 1) * tabWidth, 0)

    -- Bottom indicator line (active tab)
    local indicator = btn:CreateTexture(nil, "ARTWORK")
    indicator:SetHeight(2)
    indicator:SetPoint("BOTTOMLEFT", 8, 0)
    indicator:SetPoint("BOTTOMRIGHT", -8, 0)
    indicator:SetColorTexture(unpack(C.teal))
    indicator:Hide()

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "")
    text:SetPoint("CENTER", 0, 1)
    text:SetTextColor(unpack(C.textGray))
    text:SetText(name)

    btn:SetScript("OnEnter", function()
        if activeTab ~= name then
            text:SetTextColor(0.80, 0.80, 0.80, 1)
        end
    end)
    btn:SetScript("OnLeave", function()
        if activeTab ~= name then
            text:SetTextColor(unpack(C.textGray))
        end
    end)

    local function SetActive(active)
        if active then
            indicator:Show()
            text:SetTextColor(unpack(C.teal))
        else
            indicator:Hide()
            text:SetTextColor(unpack(C.textGray))
        end
    end

    btn:SetScript("OnClick", function()
        addon.customUI.OpenTab(name)
    end)

    tabButtons[name] = { button = btn, setActive = SetActive }
    return btn
end

-- ── Open a tab ─────────────────────────────────────────────────────────────

function addon.customUI.OpenTab(name)
    if not categoryBuilders[name] then return end

    activeTab = name

    -- Update tab buttons
    for tabName, info in pairs(tabButtons) do
        info.setActive(tabName == name)
    end

    -- Hide all children of current tab (don't orphan -WoW never GCs frames)
    local children = { scrollChild:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
    end

    -- Build tab content on first visit, then reuse from cache
    if not tabCache[name] then
        allWidgets = {}
        categoryBuilders[name]()
        tabCache[name] = { widgets = allWidgets }
    end

    allWidgets = tabCache[name].widgets

    -- Show frames belonging to this tab
    for _, entry in ipairs(allWidgets) do
        if entry.frame and entry.visible ~= false then
            entry.frame:Show()
        end
    end

    -- Layout
    RecalcLayout()

    -- Deferred refresh for sliders (need track width > 0 after layout)
    C_Timer.After(0, function()
        for _, entry in ipairs(allWidgets) do
            if entry.refresh then entry.refresh() end
        end
    end)

    -- Reset scroll
    scrollFrame:SetVerticalScroll(0)
end

-- ── Build main frame ───────────────────────────────────────────────────────

local function BuildMainFrame()
    mainFrame = CreateFrame("Frame", "MysteriousQoL_SettingsFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetFrameLevel(100)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    MakeBackdrop(mainFrame, C.bgMain, C.tealBorder)
    mainFrame:Hide()

    -- ESC to close
    table.insert(UISpecialFrames, "MysteriousQoL_SettingsFrame")

    -- Top accent bar
    local accent = mainFrame:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(unpack(C.teal))

    -- ── Header row: title (centered) + version (top-left, faded) + close ─

    local title = mainFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 15, "OUTLINE")
    title:SetPoint("TOP", 0, -8)
    title:SetText("|cff00ccccMysteriousQoL|r")

    local version = mainFrame:CreateFontString(nil, "OVERLAY")
    version:SetFont(FONT, 9, "")
    version:SetPoint("TOPLEFT", 8, -10)
    version:SetTextColor(unpack(C.textDim))
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"))

    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() mainFrame:Hide() end)

    -- ── Tab bar ──────────────────────────────────────────────────────────

    tabBar = CreateFrame("Frame", nil, mainFrame)
    tabBar:SetHeight(TAB_HEIGHT)
    tabBar:SetPoint("TOPLEFT", 1, -(HEADER_HEIGHT + 3))
    tabBar:SetPoint("TOPRIGHT", -1, -(HEADER_HEIGHT + 3))

    -- Divider line below tabs
    local tabDivider = tabBar:CreateTexture(nil, "ARTWORK")
    tabDivider:SetHeight(1)
    tabDivider:SetPoint("BOTTOMLEFT", 0, 0)
    tabDivider:SetPoint("BOTTOMRIGHT", 0, 0)
    tabDivider:SetColorTexture(unpack(C.tealDim))

    -- ── Content area ─────────────────────────────────────────────────────

    local contentTop = HEADER_HEIGHT + TAB_HEIGHT + 4

    local SCROLLBAR_WIDTH = 6

    contentFrame = CreateFrame("Frame", nil, mainFrame)
    contentFrame:SetPoint("TOPLEFT", 1, -contentTop)
    contentFrame:SetPoint("BOTTOMRIGHT", -1, 1)

    scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -(SCROLLBAR_WIDTH + 4), 0)
    scrollFrame:EnableMouseWheel(true)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(FRAME_WIDTH - SCROLLBAR_WIDTH - 6)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- ── Scrollbar ────────────────────────────────────────────────────────

    local scrollTrack = CreateFrame("Frame", nil, contentFrame)
    scrollTrack:SetWidth(SCROLLBAR_WIDTH)
    scrollTrack:SetPoint("TOPRIGHT", -2, -2)
    scrollTrack:SetPoint("BOTTOMRIGHT", -2, 2)

    local scrollTrackBg = scrollTrack:CreateTexture(nil, "BACKGROUND")
    scrollTrackBg:SetAllPoints()
    scrollTrackBg:SetColorTexture(0.08, 0.08, 0.08, 0.5)

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack)
    scrollThumb:SetWidth(SCROLLBAR_WIDTH)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)

    local scrollThumbTex = scrollThumb:CreateTexture(nil, "ARTWORK")
    scrollThumbTex:SetAllPoints()
    scrollThumbTex:SetColorTexture(0, 0.5, 0.5, 0.6)

    local function UpdateScrollbar()
        local viewHeight = scrollFrame:GetHeight()
        local contentHeight = scrollChild:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        if contentHeight <= viewHeight or trackHeight <= 0 then
            scrollThumb:Hide()
            return
        end
        scrollThumb:Show()
        local thumbSize = math.max(20, (viewHeight / contentHeight) * trackHeight)
        scrollThumb:SetHeight(thumbSize)
        local scrollRange = contentHeight - viewHeight
        local current = scrollFrame:GetVerticalScroll()
        local pct = current / scrollRange
        local travel = trackHeight - thumbSize
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(pct * travel))
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = math.max(0, (scrollChild:GetHeight() or 0) - self:GetHeight())
        local newScroll = math.max(0, math.min(maxScroll, current - delta * 40))
        self:SetVerticalScroll(newScroll)
        UpdateScrollbar()
    end)

    -- Drag scrollbar thumb
    local thumbDragging = false
    local thumbDragStart = 0
    local thumbScrollStart = 0
    scrollThumb:EnableMouse(true)
    scrollThumb:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            thumbDragging = true
            local _, cy = GetCursorPosition()
            thumbDragStart = cy / scrollTrack:GetEffectiveScale()
            thumbScrollStart = scrollFrame:GetVerticalScroll()
        end
    end)
    scrollThumb:SetScript("OnMouseUp", function() thumbDragging = false end)
    scrollThumb:SetScript("OnUpdate", function()
        if not thumbDragging then return end
        local _, cy = GetCursorPosition()
        cy = cy / scrollTrack:GetEffectiveScale()
        local delta = thumbDragStart - cy
        local trackHeight = scrollTrack:GetHeight()
        local thumbSize = scrollThumb:GetHeight()
        local travel = trackHeight - thumbSize
        if travel <= 0 then return end
        local scrollRange = scrollChild:GetHeight() - scrollFrame:GetHeight()
        local newScroll = thumbScrollStart + (delta / travel) * scrollRange
        newScroll = math.max(0, math.min(scrollRange, newScroll))
        scrollFrame:SetVerticalScroll(newScroll)
        UpdateScrollbar()
    end)

    -- Hover effect on thumb
    scrollThumb:SetScript("OnEnter", function()
        scrollThumbTex:SetColorTexture(0, 0.7, 0.7, 0.8)
    end)
    scrollThumb:SetScript("OnLeave", function()
        if not thumbDragging then
            scrollThumbTex:SetColorTexture(0, 0.5, 0.5, 0.6)
        end
    end)

    -- Store updater for use by RecalcLayout
    addon._updateScrollbar = UpdateScrollbar

    addon._settingsFrame = mainFrame
end

-- ── Init ─────────────────────────────────────────────────────────────────

function addon.MI_SettingsUI_Init()
    BuildMainFrame()
end

-- Called after all categories are registered (from MysteriousQoL.lua)
function addon.MI_SettingsUI_BuildTabs()
    local order = { "General", "UI", "Reminders", "Fun" }
    -- Count valid tabs
    local validTabs = {}
    for _, name in ipairs(order) do
        if categoryBuilders[name] then
            table.insert(validTabs, name)
        end
    end

    for i, name in ipairs(validTabs) do
        CreateTabButton(tabBar, name, i, #validTabs)
    end

    -- Open first tab
    if validTabs[1] then
        addon.customUI.OpenTab(validTabs[1])
    end
end

-- ── Toggle ─────────────────────────────────────────────────────────────────

function addon.customUI.Toggle()
    if not mainFrame then return end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

function addon.customUI.Show()
    if mainFrame then mainFrame:Show() end
end

function addon.customUI.Hide()
    if mainFrame then mainFrame:Hide() end
end
