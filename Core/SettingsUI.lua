local addonName, addon = ...

-- EllesmereUI-inspired settings panel: left sidebar nav, header banner,
-- toggle-switch widgets, smooth scrolling. Locked to #027c90 (RGB 2/124/144).

local C = {
    -- Primary (#027c90) and variants
    primary       = { 0.008, 0.486, 0.565, 1.0 },   -- #027c90
    primaryBright = { 0.012, 0.647, 0.741, 1.0 },   -- hover / active accent
    primaryDim    = { 0.005, 0.290, 0.337, 1.0 },   -- inactive borders
    primaryBorder = { 0.008, 0.486, 0.565, 0.6 },   -- frame edge
    primaryGlow   = { 0.008, 0.486, 0.565, 0.22 },  -- sidebar entry tint

    -- Surfaces
    bgMain        = { 0.05, 0.05, 0.06, 0.97 },
    bgSidebar     = { 0.03, 0.03, 0.04, 1.00 },
    bgHeader      = { 0.04, 0.04, 0.05, 1.00 },
    bgHover       = { 1.00, 1.00, 1.00, 0.04 },

    -- Text
    text          = { 1.00, 1.00, 1.00, 1.0 },
    textGray      = { 0.66, 0.66, 0.66, 1.0 },
    textDim       = { 0.40, 0.40, 0.40, 1.0 },

    -- Misc
    black         = { 0.00, 0.00, 0.00, 1.0 },
    checkBg       = { 0.15, 0.15, 0.15, 1.0 },
    sliderTrack   = { 0.12, 0.12, 0.12, 1.0 },
    sliderFill    = { 0.008, 0.486, 0.565, 1.0 },
    toggleOff     = { 0.18, 0.18, 0.20, 1.0 },
}

local BAR_TEX = [[Interface\Buttons\WHITE8x8]]
local FONT    = "Fonts\\FRIZQT__.TTF"

-- Layout constants
local FRAME_WIDTH     = 900
local FRAME_HEIGHT    = 600
local SIDEBAR_WIDTH   = 220
local HEADER_HEIGHT   = 80
local SCROLLBAR_WIDTH = 8
local CONTENT_PAD_L   = 22
local CONTENT_PAD_R   = 22
local CONTENT_PAD_T   = 14
local WIDGET_HEIGHT   = 30
local INDENT          = 24
local SECTION_GAP     = 14

-- Toggle-switch geometry (used by Checkbox widget)
local TOGGLE_W, TOGGLE_H = 38, 20
local KNOB_SIZE   = 14
local KNOB_OFF_X  = 3
local KNOB_ON_X   = TOGGLE_W - KNOB_SIZE - 3  -- = 21
local KNOB_SPEED  = 16  -- lerp coefficient
local SCROLL_SPEED = 12 -- lerp coefficient for smooth scroll

local CATEGORY_DESCRIPTIONS = {
    ["General"]    = "Automation, camera, loot, and vendor.",
    ["UI"]         = "Interface customization and frame visibility.",
    ["Reminders"]  = "Don't miss the things that matter.",
    ["Fun"]        = "Sounds and silly things.",
    ["Guild"]      = "Guild roster, sync, and member tracking.",
    ["Guild Data"] = "Import, export, and raw guild data.",
}

local mainFrame, contentFrame, scrollFrame, scrollChild
local headerTitle, headerDesc
local sidebarBody  -- holds the entry buttons
local activeTab = nil
local tabButtons = {}
local categoryBuilders = {}
local allWidgets = {}
local tabCache = {}

addon.customUI = {}

-- Pre-allocated backdrop table reused by every MakeBackdrop call to avoid per-call allocations
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

local function RecalcLayout()
    if not scrollChild then return end
    local y = -CONTENT_PAD_T
    for _, entry in ipairs(allWidgets) do
        if entry.frame then
            if entry.visible == false then
                entry.frame:Hide()
            else
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", entry.indent or 0, y)
                entry.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, y)
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

-- Widget: Section Header

function addon.customUI.Header(title)
    if #allWidgets > 0 then
        table.insert(allWidgets, { spacer = SECTION_GAP })
    end

    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(26)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 14, "OUTLINE")
    text:SetPoint("BOTTOMLEFT", 0, 5)
    text:SetTextColor(unpack(C.primaryBright))
    text:SetText(title)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(unpack(C.primaryDim))

    table.insert(allWidgets, { frame = frame, height = 26 })
end

-- Widget: Button

function addon.customUI.Button(label, onClick)
    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(WIDGET_HEIGHT)

    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetSize(160, 24)
    btn:SetPoint("LEFT", 0, 0)
    MakeBackdrop(btn, { 0.10, 0.10, 0.10, 0.9 }, C.primaryBorder)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.primaryBright))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(C.primaryBorder))
    end)
    btn:SetScript("OnClick", onClick)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(FONT, 11, "")
    lbl:SetAllPoints()
    lbl:SetJustifyH("CENTER")
    lbl:SetTextColor(unpack(C.primaryBright))
    lbl:SetText(label)

    table.insert(allWidgets, { frame = frame, height = WIDGET_HEIGHT })
end

-- Widget: Checkbox (rendered as a toggle switch on the right)

function addon.customUI.Checkbox(key, label, tooltip, onChange, children)
    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(WIDGET_HEIGHT)

    -- Toggle track (right side)
    local track = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    track:SetSize(TOGGLE_W, TOGGLE_H)
    track:SetPoint("RIGHT", 0, 0)
    MakeBackdrop(track, C.toggleOff, C.primaryDim)

    local knob = track:CreateTexture(nil, "OVERLAY")
    knob:SetSize(KNOB_SIZE, KNOB_SIZE)
    knob:SetColorTexture(unpack(C.text))
    knob.curX = KNOB_OFF_X
    knob:SetPoint("LEFT", knob.curX, 0)

    local function PlaceKnob(x)
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", x, 0)
        knob.curX = x
    end

    local function StartKnobAnim(targetX)
        knob.targetX = targetX
        if math.abs(knob.curX - targetX) < 0.5 then
            PlaceKnob(targetX)
            return
        end
        track:SetScript("OnUpdate", function(self, elapsed)
            local diff = knob.targetX - knob.curX
            if math.abs(diff) < 0.5 then
                PlaceKnob(knob.targetX)
                self:SetScript("OnUpdate", nil)
                return
            end
            PlaceKnob(knob.curX + diff * KNOB_SPEED * elapsed)
        end)
    end

    -- Label (left, anchored to track's left edge)
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "")
    text:SetPoint("TOPLEFT", 0, -2)
    text:SetPoint("RIGHT", track, "LEFT", -12, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(C.text))
    text:SetText(label)

    local desc
    if tooltip then
        desc = frame:CreateFontString(nil, "OVERLAY")
        desc:SetFont(FONT, 10, "")
        desc:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
        desc:SetPoint("RIGHT", track, "LEFT", -12, 0)
        desc:SetJustifyH("LEFT")
        desc:SetTextColor(unpack(C.textGray))
        desc:SetText(tooltip)
        desc:SetWordWrap(true)

        frame:SetScript("OnShow", function()
            local availW = frame:GetWidth() - TOGGLE_W - 12
            if availW <= 0 then return end
            local lines = math.ceil((desc:GetStringWidth() or 0) / availW)
            local extra = 0
            if lines > 1 then extra = (lines - 1) * 12 end
            local h = WIDGET_HEIGHT + extra
            for _, e in ipairs(allWidgets) do
                if e.frame == frame then e.height = h; break end
            end
        end)
    end

    local function Refresh(skipAnim)
        local val = addon.db[key]
        if val then
            track:SetBackdropColor(unpack(C.primary))
        else
            track:SetBackdropColor(unpack(C.toggleOff))
        end
        local targetX = val and KNOB_ON_X or KNOB_OFF_X
        if skipAnim then
            PlaceKnob(targetX)
            knob.targetX = targetX
        else
            StartKnobAnim(targetX)
        end
        if children then UpdateChildVisibility(key, val) end
    end

    local clickOverlay = CreateFrame("Button", nil, frame)
    clickOverlay:SetAllPoints()
    clickOverlay:SetScript("OnClick", function()
        addon.db[key] = not addon.db[key]
        Refresh()
        if onChange then onChange(addon.db[key]) end
    end)
    clickOverlay:SetScript("OnEnter", function()
        track:SetBackdropBorderColor(unpack(C.primaryBright))
    end)
    clickOverlay:SetScript("OnLeave", function()
        track:SetBackdropBorderColor(unpack(C.primaryDim))
    end)

    table.insert(allWidgets, { frame = frame, height = WIDGET_HEIGHT, key = key, refresh = Refresh })

    if children then
        local function MarkChild()
            local childEntry = allWidgets[#allWidgets]
            childEntry.parentKey = key
            childEntry.indent = INDENT
            childEntry.visible = addon.db[key]
        end
        for _, child in ipairs(children) do
            if child.type == "checkbox" then
                addon.customUI.Checkbox(child.key, child.label, child.tooltip, child.onChange)
                MarkChild()
            elseif child.type == "dropdown" then
                addon.customUI.Dropdown(child.key, child.label, child.options, child.tooltip, child.onChange)
                MarkChild()
            elseif child.type == "slider" then
                addon.customUI.Slider(child.key, child.label, child.min, child.max, child.step, child.tooltip, child.onChange)
                MarkChild()
            elseif child.type == "button" then
                addon.customUI.Button(child.label, child.onClick)
                MarkChild()
            elseif child.type == "header" then
                addon.customUI.Header(child.label)
                local n = #allWidgets
                if n >= 2 and allWidgets[n-1].spacer then
                    allWidgets[n-1].parentKey = key
                    allWidgets[n-1].visible   = addon.db[key]
                end
                allWidgets[n].parentKey = key
                allWidgets[n].visible   = addon.db[key]
            end
        end
    end

    Refresh(true)
end

-- Widget: Dropdown

function addon.customUI.Dropdown(key, label, options, tooltip, onChange)
    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(WIDGET_HEIGHT)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "")
    text:SetPoint("LEFT", 0, 0)
    text:SetTextColor(unpack(C.text))
    text:SetText(label)

    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetSize(180, 24)
    btn:SetPoint("RIGHT", 0, 0)
    MakeBackdrop(btn, C.checkBg, C.primaryDim)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(FONT, 11, "")
    btnText:SetPoint("LEFT", 8, 0)
    btnText:SetPoint("RIGHT", -16, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetTextColor(unpack(C.text))

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(FONT, 11, "")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(unpack(C.primaryBright))
    arrow:SetText("v")

    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -2)
    MakeBackdrop(menu, C.bgMain, C.primaryDim)
    menu:Hide()

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
        optText:SetPoint("LEFT", 6, 0)
        optText:SetTextColor(unpack(C.text))
        optText:SetText(opt.text)

        optBtn:SetScript("OnEnter", function() optBg:SetColorTexture(unpack(C.primaryDim)) end)
        optBtn:SetScript("OnLeave", function() optBg:SetColorTexture(0, 0, 0, 0) end)
        optBtn:SetScript("OnClick", function()
            addon.db[key] = opt.value
            Refresh()
            CloseMenu()
            if onChange then onChange(opt.value) end
        end)

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

    btn:SetScript("OnEnter", function() btn:SetBackdropBorderColor(unpack(C.primaryBright)) end)
    btn:SetScript("OnLeave", function() btn:SetBackdropBorderColor(unpack(C.primaryDim)) end)

    if tooltip then
        local desc = frame:CreateFontString(nil, "OVERLAY")
        desc:SetFont(FONT, 10, "")
        desc:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
        desc:SetPoint("RIGHT", btn, "LEFT", -12, 0)
        desc:SetJustifyH("LEFT")
        desc:SetTextColor(unpack(C.textGray))
        desc:SetText(tooltip)
    end

    table.insert(allWidgets, { frame = frame, height = WIDGET_HEIGHT, key = key, refresh = Refresh })
    Refresh()
end

-- Widget: Slider

function addon.customUI.Slider(key, label, minVal, maxVal, step, _, onChange)
    local frame = CreateFrame("Frame", nil, scrollChild)
    frame:SetHeight(WIDGET_HEIGHT + 10)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetTextColor(unpack(C.text))
    text:SetText(label)

    local valText = frame:CreateFontString(nil, "OVERLAY")
    valText:SetFont(FONT, 11, "")
    valText:SetPoint("TOPRIGHT", 0, 0)
    valText:SetTextColor(unpack(C.primaryBright))

    local track = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    track:SetHeight(8)
    track:SetPoint("TOPLEFT", 0, -22)
    track:SetPoint("TOPRIGHT", 0, -22)
    MakeBackdrop(track, C.sliderTrack, C.primaryDim)

    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetHeight(6)
    fill:SetColorTexture(unpack(C.sliderFill))

    local thumb = CreateFrame("Frame", nil, track, "BackdropTemplate")
    thumb:SetSize(12, 14)
    thumb:SetFrameLevel(track:GetFrameLevel() + 2)
    MakeBackdrop(thumb, C.primary, C.black)

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

    -- Defer initial refresh until track has width (one-shot OnUpdate)
    frame:SetScript("OnShow", function(self)
        self:SetScript("OnUpdate", function(self2)
            if track:GetWidth() > 0 then
                self2:SetScript("OnUpdate", nil)
                Refresh()
            end
        end)
    end)

    table.insert(allWidgets, { frame = frame, height = WIDGET_HEIGHT + 10, key = key, refresh = Refresh })
end

function addon.customUI.RegisterCategory(name, buildFunc)
    categoryBuilders[name] = buildFunc
end

local function CreateSidebarEntry(parent, name, index)
    local ENTRY_H = 38
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(ENTRY_H)
    btn:SetPoint("TOPLEFT", 0, -(index - 1) * ENTRY_H)
    btn:SetPoint("TOPRIGHT", 0, -(index - 1) * ENTRY_H)

    -- Glow background (gradient from primary at left → transparent at right)
    local glow = btn:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(BAR_TEX)
    glow:SetAllPoints()
    glow:SetGradient("HORIZONTAL",
        CreateColor(C.primaryGlow[1], C.primaryGlow[2], C.primaryGlow[3], C.primaryGlow[4]),
        CreateColor(0, 0, 0, 0))
    glow:Hide()

    -- Hover backdrop
    local hover = btn:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(C.bgHover))
    hover:Hide()

    -- Accent stripe on the left edge (visible when active)
    local stripe = btn:CreateTexture(nil, "OVERLAY")
    stripe:SetWidth(3)
    stripe:SetPoint("TOPLEFT", 0, 0)
    stripe:SetPoint("BOTTOMLEFT", 0, 0)
    stripe:SetColorTexture(unpack(C.primaryBright))
    stripe:Hide()

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 13, "")
    text:SetPoint("LEFT", 18, 0)
    text:SetTextColor(unpack(C.textGray))
    text:SetText(name)

    btn:SetScript("OnEnter", function()
        if activeTab ~= name then
            hover:Show()
            text:SetTextColor(0.85, 0.85, 0.85, 1)
        end
    end)
    btn:SetScript("OnLeave", function()
        hover:Hide()
        if activeTab ~= name then
            text:SetTextColor(unpack(C.textGray))
        end
    end)

    local function SetActive(active)
        if active then
            stripe:Show()
            glow:Show()
            hover:Hide()
            text:SetTextColor(unpack(C.primaryBright))
            text:SetFont(FONT, 13, "OUTLINE")
        else
            stripe:Hide()
            glow:Hide()
            text:SetTextColor(unpack(C.textGray))
            text:SetFont(FONT, 13, "")
        end
    end

    btn:SetScript("OnClick", function()
        addon.customUI.OpenTab(name)
    end)

    tabButtons[name] = { button = btn, setActive = SetActive }
    return btn
end

function addon.customUI.OpenTab(name)
    if not categoryBuilders[name] then return end

    activeTab = name

    for tabName, info in pairs(tabButtons) do
        info.setActive(tabName == name)
    end

    if headerTitle then headerTitle:SetText(name) end
    if headerDesc then headerDesc:SetText(CATEGORY_DESCRIPTIONS[name] or "") end

    -- Hide all scrollChild children (frames are reused, never orphaned -WoW never GCs frames)
    local children = { scrollChild:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
    end

    if not tabCache[name] then
        allWidgets = {}
        categoryBuilders[name]()
        tabCache[name] = { widgets = allWidgets }
    end

    allWidgets = tabCache[name].widgets

    for _, entry in ipairs(allWidgets) do
        if entry.frame and entry.visible ~= false then
            entry.frame:Show()
        end
    end

    RecalcLayout()

    -- Deferred refresh: sliders need track width > 0; toggles skip animation
    C_Timer.After(0, function()
        for _, entry in ipairs(allWidgets) do
            if entry.refresh then entry.refresh(true) end
        end
    end)

    -- Reset scroll instantly (cancel any in-flight smooth scroll)
    scrollFrame.targetScroll = nil
    scrollFrame:SetVerticalScroll(0)
    if addon._updateScrollbar then addon._updateScrollbar() end
end

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
    MakeBackdrop(mainFrame, C.bgMain, C.primaryBorder)
    mainFrame:SetScale(addon.db.settings_panel_scale or 1.0)
    mainFrame:Hide()

    table.insert(UISpecialFrames, "MysteriousQoL_SettingsFrame")

    -- Top accent bar
    local accent = mainFrame:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(unpack(C.primary))

    -- Sidebar panel (full height, left)
    local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetPoint("TOPLEFT", 1, -3)
    sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    MakeBackdrop(sidebar, C.bgSidebar)

    -- Sidebar / content divider line
    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    divider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
    divider:SetColorTexture(unpack(C.primaryDim))

    -- Sidebar header (addon title + version)
    local sbTitle = sidebar:CreateFontString(nil, "OVERLAY")
    sbTitle:SetFont(FONT, 17, "OUTLINE")
    sbTitle:SetPoint("TOPLEFT", 16, -16)
    sbTitle:SetTextColor(unpack(C.primaryBright))
    sbTitle:SetText("MysteriousQoL")

    local sbVersion = sidebar:CreateFontString(nil, "OVERLAY")
    sbVersion:SetFont(FONT, 10, "")
    sbVersion:SetPoint("TOPLEFT", sbTitle, "BOTTOMLEFT", 1, -2)
    sbVersion:SetTextColor(unpack(C.textDim))
    sbVersion:SetText("v" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"))

    -- Separator under sidebar header
    local sbSep = sidebar:CreateTexture(nil, "ARTWORK")
    sbSep:SetHeight(1)
    sbSep:SetPoint("TOPLEFT", 12, -64)
    sbSep:SetPoint("TOPRIGHT", -12, -64)
    sbSep:SetColorTexture(unpack(C.primaryDim))

    -- Sidebar body (entry container)
    sidebarBody = CreateFrame("Frame", nil, sidebar)
    sidebarBody:SetPoint("TOPLEFT", 0, -76)
    sidebarBody:SetPoint("TOPRIGHT", 0, -76)
    sidebarBody:SetPoint("BOTTOM", 0, 16)

    -- Header banner (above content, right of sidebar)
    local header = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0)
    header:SetPoint("TOPRIGHT", -1, -3)
    MakeBackdrop(header, C.bgHeader)

    -- Header glow stripe along the bottom (gradient: primary fade)
    local headerGlow = header:CreateTexture(nil, "ARTWORK")
    headerGlow:SetTexture(BAR_TEX)
    headerGlow:SetHeight(36)
    headerGlow:SetPoint("BOTTOMLEFT", 0, 1)
    headerGlow:SetPoint("BOTTOMRIGHT", 0, 1)
    headerGlow:SetGradient("VERTICAL",
        CreateColor(0, 0, 0, 0),
        CreateColor(C.primaryGlow[1], C.primaryGlow[2], C.primaryGlow[3], C.primaryGlow[4]))

    -- Header bottom divider
    local headerDivider = header:CreateTexture(nil, "OVERLAY")
    headerDivider:SetHeight(1)
    headerDivider:SetPoint("BOTTOMLEFT", 0, 0)
    headerDivider:SetPoint("BOTTOMRIGHT", 0, 0)
    headerDivider:SetColorTexture(unpack(C.primary))

    headerTitle = header:CreateFontString(nil, "OVERLAY")
    headerTitle:SetFont(FONT, 22, "OUTLINE")
    headerTitle:SetPoint("TOPLEFT", 24, -16)
    headerTitle:SetTextColor(unpack(C.text))
    headerTitle:SetText("")

    headerDesc = header:CreateFontString(nil, "OVERLAY")
    headerDesc:SetFont(FONT, 11, "")
    headerDesc:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 2, -4)
    headerDesc:SetTextColor(unpack(C.textGray))
    headerDesc:SetText("")

    -- Close button (top-right)
    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetFrameLevel(mainFrame:GetFrameLevel() + 2)
    close:SetScript("OnClick", function() mainFrame:Hide() end)

    -- Content area (below header, right of sidebar)
    contentFrame = CreateFrame("Frame", nil, mainFrame)
    contentFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    contentFrame:SetPoint("BOTTOMRIGHT", -1, 1)

    scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame)
    scrollFrame:SetPoint("TOPLEFT", CONTENT_PAD_L, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -(CONTENT_PAD_R + SCROLLBAR_WIDTH + 4), 0)
    scrollFrame:EnableMouseWheel(true)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(FRAME_WIDTH - SIDEBAR_WIDTH - CONTENT_PAD_L - CONTENT_PAD_R - SCROLLBAR_WIDTH - 4 - 2)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Custom scrollbar
    local scrollTrack = CreateFrame("Frame", nil, contentFrame)
    scrollTrack:SetWidth(SCROLLBAR_WIDTH)
    scrollTrack:SetPoint("TOPRIGHT", -3, -6)
    scrollTrack:SetPoint("BOTTOMRIGHT", -3, 20)

    local scrollTrackBg = scrollTrack:CreateTexture(nil, "BACKGROUND")
    scrollTrackBg:SetAllPoints()
    scrollTrackBg:SetColorTexture(0.08, 0.08, 0.08, 0.6)

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack)
    scrollThumb:SetWidth(SCROLLBAR_WIDTH)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)

    local scrollThumbTex = scrollThumb:CreateTexture(nil, "ARTWORK")
    scrollThumbTex:SetAllPoints()
    scrollThumbTex:SetColorTexture(C.primary[1], C.primary[2], C.primary[3], 0.7)

    local function UpdateScrollbar()
        local viewHeight = scrollFrame:GetHeight()
        local contentHeight = scrollChild:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        if contentHeight <= viewHeight or trackHeight <= 0 then
            scrollThumb:Hide()
            return
        end
        scrollThumb:Show()
        local thumbSize = math.max(24, (viewHeight / contentHeight) * trackHeight)
        scrollThumb:SetHeight(thumbSize)
        local scrollRange = contentHeight - viewHeight
        local current = scrollFrame:GetVerticalScroll()
        local pct = current / scrollRange
        local travel = trackHeight - thumbSize
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(pct * travel))
    end

    addon._updateScrollbar = UpdateScrollbar

    -- Smooth scroll: per-frame lerp toward targetScroll; detaches when arrived
    local function StartScrollAnim()
        if scrollFrame:GetScript("OnUpdate") then return end
        scrollFrame:SetScript("OnUpdate", function(self, elapsed)
            local target = self.targetScroll
            if not target then
                self:SetScript("OnUpdate", nil)
                return
            end
            local cur = self:GetVerticalScroll()
            local diff = target - cur
            if math.abs(diff) < 0.5 then
                self:SetVerticalScroll(target)
                self.targetScroll = nil
                UpdateScrollbar()
                self:SetScript("OnUpdate", nil)
                return
            end
            self:SetVerticalScroll(cur + diff * SCROLL_SPEED * elapsed)
            UpdateScrollbar()
        end)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, (scrollChild:GetHeight() or 0) - self:GetHeight())
        local from = self.targetScroll or self:GetVerticalScroll()
        self.targetScroll = math.max(0, math.min(maxScroll, from - delta * 60))
        StartScrollAnim()
    end)

    -- Drag scrollbar thumb (instant, cancels smooth scroll)
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
            scrollFrame.targetScroll = nil
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

    scrollThumb:SetScript("OnEnter", function()
        scrollThumbTex:SetColorTexture(C.primaryBright[1], C.primaryBright[2], C.primaryBright[3], 0.9)
    end)
    scrollThumb:SetScript("OnLeave", function()
        if not thumbDragging then
            scrollThumbTex:SetColorTexture(C.primary[1], C.primary[2], C.primary[3], 0.7)
        end
    end)

    addon._settingsFrame = mainFrame

    -- Resize grip (bottom-right corner) -scales the panel
    local grip = CreateFrame("Frame", nil, mainFrame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:EnableMouse(true)
    local function MakeDot(x, y)
        local t = grip:CreateTexture(nil, "OVERLAY")
        t:SetSize(3, 3); t:SetPoint("BOTTOMRIGHT", x, y)
        t:SetColorTexture(C.primary[1], C.primary[2], C.primary[3], 0.6)
    end
    MakeDot(-1, 1); MakeDot(-5, 1); MakeDot(-1, 5)
    MakeDot(-9, 1); MakeDot(-5, 5); MakeDot(-1, 9)
    grip:SetScript("OnEnter", function()
        for _, tex in ipairs({grip:GetRegions()}) do tex:SetAlpha(1) end
    end)
    grip:SetScript("OnLeave", function()
        for _, tex in ipairs({grip:GetRegions()}) do tex:SetAlpha(0.6) end
    end)
    local gripDragging, gripStartX, gripStartScale = false, 0, 1.0
    grip:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        gripDragging = true
        gripStartX = GetCursorPosition()
        gripStartScale = mainFrame:GetScale()
    end)
    grip:SetScript("OnMouseUp", function()
        if gripDragging then
            local snapped = math.floor(mainFrame:GetScale() / 0.05 + 0.5) * 0.05
            snapped = math.max(0.6, math.min(2.0, snapped))
            addon.db.settings_panel_scale = snapped
            mainFrame:SetScale(snapped)
        end
        gripDragging = false
    end)
    grip:SetScript("OnUpdate", function()
        if not gripDragging then return end
        local cx = GetCursorPosition()
        local newScale = math.max(0.6, math.min(2.0, gripStartScale + (cx - gripStartX) / 500))
        mainFrame:SetScale(newScale)
    end)
end

function addon.MI_SettingsUI_Init()
    BuildMainFrame()
end

function addon.MI_SettingsUI_BuildTabs()
    local order = { "General", "UI", "Reminders", "Fun", "Guild", "Guild Data" }
    local validTabs = {}
    for _, name in ipairs(order) do
        if categoryBuilders[name] then
            table.insert(validTabs, name)
        end
    end

    for i, name in ipairs(validTabs) do
        CreateSidebarEntry(sidebarBody, name, i)
    end

    if validTabs[1] then
        addon.customUI.OpenTab(validTabs[1])
    end
end

function addon.customUI.Toggle()
    if not mainFrame then return end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end
