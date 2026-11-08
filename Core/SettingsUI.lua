local addonName, addon = ...

-- Settings panel: rounded panels, accent colour (teal, red or gold), pill
-- switches, an icon sidebar, section cards and search.
--
-- Feature files register a category with a build function that calls Header,
-- Checkbox, Dropdown, Slider and Button (see MysteriousQoL.lua). Those calls
-- only note down what to show; the panel draws the notes when a category is
-- first opened.

addon.customUI = {}
local UI = addon.customUI

local categoryBuilders = {}
local recording = nil

function UI.RegisterCategory(name, buildFunc)
    categoryBuilders[name] = buildFunc
end

function UI.Header(label)
    if not recording then return end
    recording[#recording + 1] = { kind = "header", label = label }
end

function UI.Checkbox(key, label, tooltip, onChange, children)
    if not recording then return end
    recording[#recording + 1] = { kind = "checkbox", key = key, label = label, tooltip = tooltip,
                                  onChange = onChange, children = children }
end

function UI.Dropdown(key, label, options, tooltip, onChange)
    if not recording then return end
    recording[#recording + 1] = { kind = "dropdown", key = key, label = label, options = options,
                                  tooltip = tooltip, onChange = onChange }
end

function UI.Slider(key, label, min, max, step, tooltip, onChange)
    if not recording then return end
    recording[#recording + 1] = { kind = "slider", key = key, label = label, min = min, max = max,
                                  step = step, tooltip = tooltip, onChange = onChange }
end

function UI.Button(label, onClick)
    if not recording then return end
    recording[#recording + 1] = { kind = "button", label = label, onClick = onClick }
end

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Assets\\UI\\"
local FONT  = "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local WIDTH, HEIGHT = 940, 620
local SIDEBAR_W     = 214
local BANNER_H      = 76
local PAGE_HEAD_H   = 70
local SCROLL_STEP   = 48

local ACCENTS = {
    teal = { accent = { 0.10, 0.72, 0.82 }, dim = { 0.008, 0.486, 0.565 }, deep = { 0.02, 0.16, 0.19 } },
    red  = { accent = { 0.92, 0.36, 0.33 }, dim = { 0.64, 0.20, 0.18 }, deep = { 0.25, 0.07, 0.06 } },
    gold = { accent = { 0.90, 0.74, 0.42 }, dim = { 0.62, 0.49, 0.27 }, deep = { 0.24, 0.18, 0.09 } },
}

-- Order the accent button cycles through. Teal is the default.
local ACCENT_ORDER = { "teal", "red", "gold" }
local ACCENT_LABELS = { teal = "Teal", red = "Red", gold = "Gold" }

local C = {
    bg       = { 0.055, 0.058, 0.07, 0.97 },
    sidebar  = { 0.04, 0.042, 0.05, 1 },
    card     = { 0.085, 0.09, 0.105, 1 },
    cardEdge = { 0.17, 0.17, 0.19, 1 },
    hover    = { 1, 1, 1, 0.04 },
    text     = { 1, 1, 1, 1 },
    dim      = { 0.62, 0.62, 0.64, 1 },
    faint    = { 0.42, 0.42, 0.44, 1 },
    trackOff = { 0.23, 0.23, 0.25, 1 },
    knobOff  = { 0.55, 0.56, 0.58, 1 },
    knobOn   = { 0.95, 0.92, 0.85, 1 },
}

local CATEGORIES = {
    { name = "General",   icon = "Interface\\Icons\\Trade_Engineering",
      desc = "Quests, automation, loot, bags and vendor." },
    { name = "UI",        icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
      desc = "Interface customization and frame visibility." },
    { name = "Reminders", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
      desc = "Don't miss the things that matter." },
    { name = "Fun",       icon = "Interface\\Icons\\INV_Misc_Ticket_Darkmoon_01",
      desc = "Sounds and silly things." },
    -- Opened from the small button above Changelog, not the sidebar list.
    { name = "Settings",  icon = "Interface\\Icons\\INV_Misc_Gear_01",
      desc = "Addon options.", footer = true },
}

local accentName = "teal"
local A = ACCENTS.teal
local painters = {}

-- Runs fn now and again whenever the accent changes.
local function onAccent(fn)
    painters[#painters + 1] = fn
    fn()
end

local function setAccent(name)
    if not ACCENTS[name] then name = "teal" end
    accentName = name
    A = ACCENTS[name]
    addon.db.settings_accent = name
    for _, fn in ipairs(painters) do fn() end
end

local function nextAccent()
    for i, name in ipairs(ACCENT_ORDER) do
        if name == accentName then
            return ACCENT_ORDER[i % #ACCENT_ORDER + 1]
        end
    end
    return ACCENT_ORDER[1]
end

-- Texture helpers

local function sliced(tex, file, margin)
    tex:SetTexture(MEDIA .. file)
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(margin, margin, margin, margin)
        tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
end

local function rounded(frame, layer, color, file)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
    sliced(tex, file or "Rounded", 10)
    tex:SetAllPoints()
    if color then tex:SetVertexColor(unpack(color)) end
    return tex
end

local function text(parent, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, flags or "")
    fs:SetJustifyH("LEFT")
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

local function firstSentence(tip)
    if not tip then return nil end
    return tip:match("^(.-[%.!?])%s") or tip
end

-- Round icon in a ring.
local function emblem(parent, size, icon)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetTexture(icon)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = f:CreateMaskTexture()
    mask:SetTexture(MEDIA .. "CircleMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    local ring = f:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(MEDIA .. "CircleRing")
    ring:SetAllPoints()
    onAccent(function() ring:SetVertexColor(unpack(A.accent)) end)
    f.icon = tex
    return f
end

-- Rounded button with an accent ring.
local function button(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local bg = rounded(b, "BACKGROUND", C.card)
    local ring = rounded(b, "BORDER", nil, "Ring")
    local hl = rounded(b, "HIGHLIGHT", C.hover)
    hl:SetBlendMode("ADD")
    b.label = text(b, 11)
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label)
    onAccent(function()
        ring:SetVertexColor(unpack(A.dim))
        b.label:SetTextColor(unpack(A.accent))
    end)
    b.bg = bg
    return b
end

-- Pill switch
local function switch(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(34, 18)
    local track = b:CreateTexture(nil, "ARTWORK")
    track:SetAllPoints()
    sliced(track, "Pill", 8)
    local knob = b:CreateTexture(nil, "OVERLAY")
    knob:SetSize(14, 14)
    knob:SetTexture(MEDIA .. "Knob")
    function b:Paint()
        track:SetVertexColor(unpack(self.on and A.dim or C.trackOff))
        knob:SetVertexColor(unpack(self.on and C.knobOn or C.knobOff))
        knob:ClearAllPoints()
        if self.on then knob:SetPoint("RIGHT", -2, 0) else knob:SetPoint("LEFT", 2, 0) end
    end
    function b:SetOn(on)
        self.on = on and true or false
        self:Paint()
    end
    onAccent(function() b:Paint() end)
    return b
end

-- One shared drop-down menu.
local menu
local function openMenu(anchor, options, current, onPick)
    if not menu then
        menu = CreateFrame("Frame", nil, UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        rounded(menu, "BACKGROUND", { 0.07, 0.075, 0.09, 0.98 })
        menu.ring = rounded(menu, "BORDER", nil, "Ring")
        menu.items = {}
        menu:SetScript("OnUpdate", function(self)
            if IsMouseButtonDown("LeftButton") and not self:IsMouseOver()
                and not (self.anchor and self.anchor:IsMouseOver()) then
                self:Hide()
            end
        end)
    end
    menu.ring:SetVertexColor(unpack(A.dim))
    menu.anchor = anchor
    for _, item in ipairs(menu.items) do item:Hide() end
    for i, opt in ipairs(options) do
        local item = menu.items[i]
        if not item then
            item = CreateFrame("Button", nil, menu)
            item:SetHeight(20)
            local hl = item:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)
            item.label = text(item, 11)
            item.label:SetPoint("LEFT", 10, 0)
            menu.items[i] = item
        end
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
        item:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * 20)
        item.label:SetText(opt.text)
        item.label:SetTextColor(unpack(opt.value == current and A.accent or C.text))
        item:SetScript("OnClick", function()
            menu:Hide()
            onPick(opt.value)
        end)
        item:Show()
    end
    menu:SetSize(anchor:GetWidth(), #options * 20 + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu:Show()
end

-- Recording a category's settings

local function record(builder)
    recording = {}
    local ok, err = pcall(builder)
    local defs = recording
    recording = nil
    if not ok then geterrorhandler()(err) end
    return defs
end

-- Turns a child table from a Checkbox call into the same shape as a recorded def.
local function childDef(child)
    local kind = child.type == "header" and "header" or child.type
    return {
        kind = kind, key = child.key, label = child.label, tooltip = child.tooltip,
        onChange = child.onChange, options = child.options, min = child.min,
        max = child.max, step = child.step, onClick = child.onClick,
        zeroText = child.zeroText,
    }
end

-- Rows

local function rowBase(card, def, indent)
    local row = CreateFrame("Button", nil, card)
    local desc = firstSentence(def.tooltip)
    row:SetHeight(desc and 42 or 30)
    local hl = rounded(row, "HIGHLIGHT", C.hover)
    hl:SetBlendMode("ADD")

    row.label = text(row, 13, C.text)
    row.label:SetText(def.label or "")
    if desc then
        row.label:SetPoint("TOPLEFT", 54 + indent, -7)
        row.desc = text(row, 11, C.dim)
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
        row.desc:SetPoint("RIGHT", row, "RIGHT", -200, 0)
        row.desc:SetWordWrap(false)
        row.desc:SetText(desc)
    else
        row.label:SetPoint("LEFT", 54 + indent, 0)
    end

    row.searchText = ((def.label or "") .. " " .. (def.tooltip or "")):lower()
    if def.tooltip then
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 54 + indent, 2)
            GameTooltip:SetText(def.label or "", A.accent[1], A.accent[2], A.accent[3])
            GameTooltip:AddLine(def.tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end
    return row
end

local function checkboxRow(page, card, def, indent)
    local row = rowBase(card, def, indent)
    local sw = switch(row)
    sw:SetPoint("LEFT", 10 + indent, 0)
    local function toggle()
        addon.db[def.key] = not addon.db[def.key]
        sw:SetOn(addon.db[def.key])
        if def.onChange then def.onChange(addon.db[def.key]) end
        page:Layout()
    end
    row:SetScript("OnClick", toggle)
    sw:SetScript("OnClick", toggle)
    row.refresh = function() sw:SetOn(addon.db[def.key]) end
    return row
end

local function dropdownRow(page, card, def, indent)
    local row = rowBase(card, def, indent)
    local b = button(row, "", 180, 22)
    b:SetPoint("RIGHT", -12, 0)
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", 10, 0)
    local arrow = text(b, 11, C.dim)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    local function current()
        for _, opt in ipairs(def.options or {}) do
            if opt.value == addon.db[def.key] then return opt.text end
        end
        return tostring(addon.db[def.key])
    end
    row.refresh = function() b.label:SetText(current()) end
    b:SetScript("OnClick", function()
        if menu and menu:IsShown() and menu.anchor == b then menu:Hide() return end
        openMenu(b, def.options or {}, addon.db[def.key], function(value)
            addon.db[def.key] = value
            row.refresh()
            if def.onChange then def.onChange(value) end
        end)
    end)
    return row
end

local function sliderRow(page, card, def, indent)
    local row = rowBase(card, def, indent)
    local value = text(row, 12, nil)
    value:SetPoint("RIGHT", -12, 0)
    value:SetWidth(def.zeroText and 56 or 40)
    value:SetJustifyH("RIGHT")
    onAccent(function() value:SetTextColor(unpack(A.accent)) end)

    local s = CreateFrame("Slider", nil, row)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(140, 16)
    s:SetPoint("RIGHT", value, "LEFT", -10, 0)
    local track = s:CreateTexture(nil, "BACKGROUND")
    sliced(track, "Pill", 8)
    track:SetHeight(6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetVertexColor(unpack(C.trackOff))
    s:SetThumbTexture(MEDIA .. "Knob")
    local thumb = s:GetThumbTexture()
    thumb:SetSize(14, 14)
    onAccent(function() thumb:SetVertexColor(unpack(A.accent)) end)
    s:SetMinMaxValues(def.min or 0, def.max or 1)
    s:SetValueStep(def.step or 1)
    s:SetObeyStepOnDrag(true)

    local updating = false
    local function show(v)
        local step = def.step or 1
        if def.zeroText and v == 0 then
            value:SetText(def.zeroText)
            return
        end
        value:SetText(step < 1 and string.format("%.1f", v) or tostring(math.floor(v + 0.5)))
    end
    s:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        local step = def.step or 1
        v = math.floor(v / step + 0.5) * step
        addon.db[def.key] = v
        show(v)
        if def.onChange then def.onChange(v) end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta * (def.step or 1))
    end)
    row.refresh = function()
        updating = true
        s:SetValue(addon.db[def.key] or def.min or 0)
        updating = false
        show(addon.db[def.key] or def.min or 0)
    end
    return row
end

local function buttonRow(page, card, def, indent)
    local row = CreateFrame("Frame", nil, card)
    row:SetHeight(34)
    local b = button(row, def.label, 180, 24)
    b:SetPoint("LEFT", 10 + indent, 0)
    b:SetScript("OnClick", function() if def.onClick then def.onClick() end end)
    row.searchText = (def.label or ""):lower()
    return row
end

local function subHeaderRow(page, card, def, indent)
    local row = CreateFrame("Frame", nil, card)
    row:SetHeight(24)
    local fs = text(row, 11, C.faint, "OUTLINE")
    fs:SetPoint("LEFT", 10 + indent, 0)
    fs:SetText((def.label or ""):upper())
    row.searchText = (def.label or ""):lower()
    return row
end

local ROW_BUILDERS = {
    checkbox = checkboxRow, dropdown = dropdownRow, slider = sliderRow,
    button = buttonRow, header = subHeaderRow,
}

-- Pages

local frame, scroll, scrollThumb, searchBox, settingsButton
local applyScale
local pageHead = {}
local pages = {}
local activePage, activeCat
local navButtons = {}

local function newSection(page, title)
    local section = { rows = {} }
    if title then
        section.title = text(page.child, 12, nil, "OUTLINE")
        section.title:SetText(title:upper())
        onAccent(function() section.title:SetTextColor(unpack(A.accent)) end)
    end
    section.card = CreateFrame("Frame", nil, page.child)
    rounded(section.card, "BACKGROUND", C.card)
    rounded(section.card, "BORDER", C.cardEdge, "Ring")
    page.sections[#page.sections + 1] = section
    return section
end

-- Sorts headings alphabetically, and options alphabetically within each
-- heading. Sub-options stay under their option in their own order; buttons go
-- last. Options above the first heading stay at the top.
local function sortName(def)
    return (def.label or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
end

local function sortDefs(defs)
    local sections = { { items = {} } }
    for _, def in ipairs(defs) do
        if def.kind == "header" then
            sections[#sections + 1] = { header = def, items = {} }
        else
            local items = sections[#sections].items
            items[#items + 1] = def
        end
    end

    local untitled = table.remove(sections, 1)
    table.sort(sections, function(a, b) return sortName(a.header) < sortName(b.header) end)
    table.insert(sections, 1, untitled)

    local out = {}
    for _, section in ipairs(sections) do
        table.sort(section.items, function(a, b)
            local aButton, bButton = a.kind == "button", b.kind == "button"
            if aButton ~= bButton then return bButton end
            return sortName(a) < sortName(b)
        end)
        if section.header then out[#out + 1] = section.header end
        for _, def in ipairs(section.items) do out[#out + 1] = def end
    end
    return out
end

local function buildPage(cat)
    local page = { sections = {}, rows = {} }
    page.child = CreateFrame("Frame", nil, scroll)
    page.child:SetSize(scroll:GetWidth(), 10)

    local defs = sortDefs(record(categoryBuilders[cat.name]))
    local section
    local function addRow(def, indent, parentKey)
        section = section or newSection(page, nil)
        local make = ROW_BUILDERS[def.kind]
        if not make then return end
        local row = make(page, section.card, def, indent)
        row.parentKey = parentKey
        section.rows[#section.rows + 1] = row
        page.rows[#page.rows + 1] = row
    end

    for _, def in ipairs(defs) do
        if def.kind == "header" then
            section = newSection(page, def.label)
        else
            addRow(def, 0, nil)
            if def.kind == "checkbox" and def.children then
                for _, child in ipairs(def.children) do
                    addRow(childDef(child), 26, def.key)
                end
            end
        end
    end

    function page:Layout()
        local filter = searchBox and searchBox:GetText():lower() or ""
        filter = filter:gsub("^%s+", ""):gsub("%s+$", "")
        local y = -6
        for _, sec in ipairs(self.sections) do
            local rowY, shown = -6, 0
            for _, row in ipairs(sec.rows) do
                local visible
                if filter ~= "" then
                    visible = row.searchText and row.searchText:find(filter, 1, true) ~= nil
                else
                    visible = not row.parentKey or addon.db[row.parentKey]
                end
                if visible then
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", sec.card, "TOPLEFT", 6, rowY)
                    row:SetPoint("RIGHT", sec.card, "RIGHT", -6, 0)
                    row:Show()
                    rowY = rowY - row:GetHeight() - 2
                    shown = shown + 1
                else
                    row:Hide()
                end
            end
            if shown == 0 then
                sec.card:Hide()
                if sec.title then sec.title:Hide() end
            else
                if sec.title then
                    sec.title:ClearAllPoints()
                    sec.title:SetPoint("TOPLEFT", self.child, "TOPLEFT", 6, y)
                    sec.title:Show()
                    y = y - 20
                end
                local h = -rowY + 4
                sec.card:ClearAllPoints()
                sec.card:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, y)
                sec.card:SetPoint("RIGHT", self.child, "RIGHT", 0, 0)
                sec.card:SetHeight(h)
                sec.card:Show()
                y = y - h - 16
            end
        end
        self.child:SetHeight(-y + 10)
        scroll:UpdateScrollChildRect()
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
        scroll:UpdateThumb()
    end

    function page:Refresh()
        for _, row in ipairs(self.rows) do
            if row.refresh then row.refresh() end
        end
        self:Layout()
    end

    return page
end

local function openPage(cat)
    activeCat = cat
    if activePage then activePage.child:Hide() end
    pages[cat.name] = pages[cat.name] or buildPage(cat)
    activePage = pages[cat.name]
    activePage.child:Show()
    scroll:SetScrollChild(activePage.child)
    scroll:SetVerticalScroll(0)

    pageHead.icon.icon:SetTexture(cat.icon)
    pageHead.title:SetText(cat.name)
    pageHead.desc:SetText(cat.desc)
    for _, nav in ipairs(navButtons) do nav:SetActive(nav.cat == cat) end
    if settingsButton then settingsButton:SetActive(cat.footer) end
    activePage:Refresh()
end

local function navButton(parent, cat, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(48)
    b:SetPoint("TOPLEFT", 12, -12 - (index - 1) * 54)
    b:SetPoint("TOPRIGHT", -12, -12 - (index - 1) * 54)
    local fill = rounded(b, "BACKGROUND")
    local ring = rounded(b, "BORDER", nil, "Ring")
    local hl = rounded(b, "HIGHLIGHT", C.hover)
    hl:SetBlendMode("ADD")
    local icon = emblem(b, 36, cat.icon)
    icon:SetPoint("LEFT", 6, 0)
    local name = text(b, 13)
    name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    name:SetText(cat.name)
    b.cat = cat
    function b:SetActive(on)
        self.active = on
        fill:SetShown(on)
        ring:SetShown(on)
        fill:SetVertexColor(unpack(A.deep))
        ring:SetVertexColor(unpack(A.dim))
        name:SetTextColor(unpack(on and A.accent or C.dim))
    end
    onAccent(function() b:SetActive(b.active) end)
    b:SetScript("OnClick", function() openPage(cat) end)
    return b
end

local SCALE_MIN, SCALE_MAX, EDGE_PAD = 0.6, 2.0, 24

local function maxScale()
    local w, h = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
    if w <= 0 or h <= 0 then return SCALE_MAX end
    local fit = math.min((w - EDGE_PAD * 2) / WIDTH, (h - EDGE_PAD * 2) / HEIGHT)
    return math.max(0.1, math.min(SCALE_MAX, fit))
end

applyScale = function(value, persist)
    local top = maxScale()
    local scale = math.max(math.min(SCALE_MIN, top), math.min(top, tonumber(value) or 1))
    if frame then frame:SetScale(scale) end
    if persist then addon.db.settings_panel_scale = scale end
    return scale
end

local function createFrame()
    -- Start in the accent picked last time.
    local saved = addon.db.settings_accent
    if ACCENTS[saved] then
        accentName = saved
        A = ACCENTS[saved]
    end

    frame = CreateFrame("Frame", "MysteriousQoL_SettingsFrame", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    tinsert(UISpecialFrames, frame:GetName())
    rounded(frame, "BACKGROUND", C.bg)
    local edge = rounded(frame, "BORDER", nil, "Ring")
    onAccent(function() edge:SetVertexColor(A.dim[1], A.dim[2], A.dim[3], 0.8) end)

    -- Banner
    local banner = CreateFrame("Frame", nil, frame)
    banner:SetPoint("TOPLEFT", 2, -2)
    banner:SetPoint("TOPRIGHT", -2, -2)
    banner:SetHeight(BANNER_H)
    banner:EnableMouse(true)
    banner:RegisterForDrag("LeftButton")
    banner:SetScript("OnDragStart", function() frame:StartMoving() end)
    banner:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local glow = banner:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(WHITE)
    glow:SetAllPoints()
    onAccent(function()
        glow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0),
            CreateColor(A.deep[1], A.deep[2], A.deep[3], 0.9))
    end)
    local line = banner:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 12, 0)
    line:SetPoint("BOTTOMRIGHT", -12, 0)
    line:SetTexture(WHITE)
    onAccent(function()
        line:SetGradient("HORIZONTAL", CreateColor(A.dim[1], A.dim[2], A.dim[3], 0),
            CreateColor(A.dim[1], A.dim[2], A.dim[3], 1))
    end)

    local logo = emblem(banner, 54, "Interface\\AddOns\\" .. addonName .. "\\MysteriousQoL")
    logo.icon:SetTexCoord(0, 1, 0, 1)
    logo:SetPoint("LEFT", 16, 0)
    logo:EnableMouse(true)
    logo:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("Created for <Mysterious Intent> on Tichondrius & Forever: RP",
            A.accent[1], A.accent[2], A.accent[3])
        GameTooltip:Show()
    end)
    logo:SetScript("OnLeave", GameTooltip_Hide)
    -- Dragging from the logo still moves the panel.
    logo:RegisterForDrag("LeftButton")
    logo:SetScript("OnDragStart", function() frame:StartMoving() end)
    logo:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = text(banner, 22, nil, "OUTLINE")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -6)
    title:SetText("MysteriousQoL")
    onAccent(function() title:SetTextColor(unpack(A.accent)) end)
    local sub = text(banner, 11, C.dim)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Mysterious Quality of Life improvements")

    local close = button(banner, "", 24, 24)
    close:SetPoint("TOPRIGHT", -10, -10)
    -- The X is a symmetric texture filling the button, so it stays centered
    -- (a font glyph or rotated lines drift by a pixel).
    local cross = close:CreateTexture(nil, "OVERLAY")
    cross:SetTexture(MEDIA .. "Close")
    cross:SetPoint("TOPLEFT", 4, -4)
    cross:SetPoint("BOTTOMRIGHT", -4, 4)
    onAccent(function() cross:SetVertexColor(unpack(A.accent)) end)
    close:SetScript("OnClick", function() frame:Hide() end)
    local accentBtn = button(banner, "", 90, 24)
    accentBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
    local function accentLabel() accentBtn.label:SetText("Accent: " .. ACCENT_LABELS[accentName]) end
    accentLabel()
    accentBtn:SetScript("OnClick", function()
        setAccent(nextAccent())
        accentLabel()
    end)

    -- Sidebar
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", 8, -(BANNER_H + 8))
    sidebar:SetPoint("BOTTOMLEFT", 8, 8)
    sidebar:SetWidth(SIDEBAR_W)
    rounded(sidebar, "BACKGROUND", C.sidebar)
    local index = 0
    for _, cat in ipairs(CATEGORIES) do
        if categoryBuilders[cat.name] and not cat.footer then
            index = index + 1
            navButtons[#navButtons + 1] = navButton(sidebar, cat, index)
        end
    end

    -- Small Settings button above Changelog for the addon's own options.
    for _, cat in ipairs(CATEGORIES) do
        if cat.footer and categoryBuilders[cat.name] then
            settingsButton = button(sidebar, cat.name, SIDEBAR_W - 24, 24)
            settingsButton:SetPoint("BOTTOM", 0, 74)
            settingsButton:SetScript("OnClick", function() openPage(cat) end)
            function settingsButton:SetActive(on)
                self.active = on and true or false
                self.bg:SetVertexColor(unpack(self.active and A.deep or C.card))
            end
            onAccent(function() settingsButton:SetActive(settingsButton.active) end)
        end
    end

    local changelog = button(sidebar, "Changelog", SIDEBAR_W - 24, 24)
    changelog:SetPoint("BOTTOM", 0, 44)
    changelog:SetScript("OnClick", function()
        if addon.MI_Changelog_Toggle then addon.MI_Changelog_Toggle() end
    end)
    local version = text(sidebar, 10, C.faint)
    version:SetPoint("BOTTOM", 0, 24)
    local v = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
    version:SetText("Version " .. (v or "?"))
    local author = text(sidebar, 9, C.faint)
    author:SetPoint("TOP", version, "BOTTOM", 0, -3)
    author:SetText("Author: UmbraChimera#1824")

    -- Page header: emblem, title, description, search
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 16, 0)
    content:SetPoint("BOTTOMRIGHT", -16, 8)
    pageHead.icon = emblem(content, 48, CATEGORIES[1].icon)
    pageHead.icon:SetPoint("TOPLEFT", 0, -6)
    pageHead.title = text(content, 20, nil, "OUTLINE")
    pageHead.title:SetPoint("TOPLEFT", pageHead.icon, "TOPRIGHT", 12, -4)
    onAccent(function() pageHead.title:SetTextColor(unpack(A.accent)) end)
    pageHead.desc = text(content, 12, C.dim)
    pageHead.desc:SetPoint("TOPLEFT", pageHead.title, "BOTTOMLEFT", 0, -5)

    local searchFrame = CreateFrame("Frame", nil, content)
    searchFrame:SetSize(200, 26)
    searchFrame:SetPoint("TOPRIGHT", 0, -16)
    rounded(searchFrame, "BACKGROUND", C.card)
    local searchRing = rounded(searchFrame, "BORDER", C.cardEdge, "Ring")
    searchBox = CreateFrame("EditBox", nil, searchFrame)
    searchBox:SetPoint("TOPLEFT", 10, 0)
    searchBox:SetPoint("BOTTOMRIGHT", -10, 0)
    searchBox:SetFont(FONT, 12, "")
    searchBox:SetTextColor(unpack(C.text))
    searchBox:SetAutoFocus(false)
    local hint = text(searchFrame, 12, C.faint)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText("Search")
    searchBox:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        if activePage then activePage:Layout() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEditFocusGained", function() searchRing:SetVertexColor(unpack(A.dim)) end)
    searchBox:SetScript("OnEditFocusLost", function() searchRing:SetVertexColor(unpack(C.cardEdge)) end)

    -- Scroll area
    scroll = CreateFrame("ScrollFrame", nil, content)
    scroll:SetPoint("TOPLEFT", 0, -PAGE_HEAD_H)
    scroll:SetPoint("BOTTOMRIGHT", -12, 0)
    scroll:EnableMouseWheel(true)
    scrollThumb = content:CreateTexture(nil, "OVERLAY")
    scrollThumb:SetTexture(WHITE)
    scrollThumb:SetWidth(3)
    onAccent(function() scrollThumb:SetVertexColor(A.dim[1], A.dim[2], A.dim[3], 0.9) end)

    function scroll:UpdateThumb()
        local range = self:GetVerticalScrollRange()
        local h = self:GetHeight()
        if range <= 0 or h <= 0 then
            scrollThumb:Hide()
            return
        end
        local thumbH = math.max(30, h * h / (h + range))
        local offset = (h - thumbH) * (self:GetVerticalScroll() / range)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 10, -offset)
        scrollThumb:SetHeight(thumbH)
        scrollThumb:Show()
    end

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * SCROLL_STEP
        target = math.max(0, math.min(self:GetVerticalScrollRange(), target))
        self:SetVerticalScroll(target)
        self:UpdateThumb()
    end)
    scroll:SetScript("OnSizeChanged", function(self, w)
        for _, page in pairs(pages) do page.child:SetWidth(w) end
        if activePage then activePage:Layout() end
    end)

    -- Resize grip: drag right to grow, left to shrink. Snaps to 5% steps.
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    for _, pos in ipairs({ { -1, 1 }, { -5, 1 }, { -1, 5 }, { -9, 1 }, { -5, 5 }, { -1, 9 } }) do
        local dot = grip:CreateTexture(nil, "OVERLAY")
        dot:SetSize(2, 2)
        dot:SetPoint("BOTTOMRIGHT", pos[1], pos[2])
        dot:SetTexture(WHITE)
        onAccent(function() dot:SetVertexColor(A.dim[1], A.dim[2], A.dim[3], 0.9) end)
    end
    local dragging, startX, startScale = false, 0, 1
    local function onDrag()
        applyScale(startScale + (GetCursorPosition() - startX) / 500, false)
    end
    grip:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        dragging = true
        startX = GetCursorPosition()
        startScale = frame:GetScale()
        grip:SetScript("OnUpdate", onDrag)
    end)
    grip:SetScript("OnMouseUp", function()
        if dragging then
            applyScale(math.floor(frame:GetScale() / 0.05 + 0.5) * 0.05, true)
        end
        dragging = false
        grip:SetScript("OnUpdate", nil)
    end)

    -- Keep the saved scale, but shrink to fit a smaller window or UI scale.
    UIParent:HookScript("OnSizeChanged", function()
        applyScale(addon.db.settings_panel_scale, false)
    end)
    applyScale(addon.db.settings_panel_scale, false)

    frame:SetScript("OnShow", function()
        applyScale(addon.db.settings_panel_scale, false)
        if activePage then activePage:Refresh() end
    end)
    frame:SetScript("OnHide", function()
        if menu then menu:Hide() end
    end)

    if navButtons[1] then openPage(navButtons[1].cat) end
end

-- Shared look for other windows (welcome popup, setup helper).
local function loadSavedAccent()
    local saved = addon.db and addon.db.settings_accent
    if ACCENTS[saved] then
        accentName = saved
        A = ACCENTS[saved]
    end
end

UI.Style = {
    Rounded = rounded, Text = text, Emblem = emblem, Button = button, Switch = switch,
    OnAccent = onAccent, Colors = C, LoadAccent = loadSavedAccent,
    Accent = function() return A end,
    Media = MEDIA, Font = FONT, White = WHITE,
}

-- Finds an option by its setting key in any category, for the setup helper.
-- Includes sub-options. nil when this game version or class does not have it.
local optionIndex
function UI.FindOption(key)
    if not optionIndex then
        optionIndex = {}
        for _, cat in ipairs(CATEGORIES) do
            local builder = categoryBuilders[cat.name]
            if builder then
                for _, def in ipairs(record(builder)) do
                    if def.key then optionIndex[def.key] = def end
                    for _, child in ipairs(def.children or {}) do
                        if child.key then optionIndex[child.key] = childDef(child) end
                    end
                end
            end
        end
    end
    return optionIndex[key]
end

-- Built on first open, once every category has registered.
function UI.Toggle()
    if not frame then
        createFrame()
        frame:Show()
        return
    end
    frame:SetShown(not frame:IsShown())
end

-- Refreshes switches after another window (the setup helper) changed settings.
function UI.RefreshOpenPage()
    if activePage and frame and frame:IsShown() then activePage:Refresh() end
end

-- Rebuilds every page, e.g. after the debug option changes which options show.
-- Old page frames are hidden and dropped (WoW never frees frames, but this is rare).
function UI.Rebuild()
    optionIndex = nil
    if not frame then return end
    for _, page in pairs(pages) do page.child:Hide() end
    pages = {}
    activePage = nil
    if activeCat then openPage(activeCat) end
end

function UI.OpenTab(name)
    if not frame then createFrame() end
    for _, cat in ipairs(CATEGORIES) do
        if cat.name == name and categoryBuilders[name] then openPage(cat) end
    end
    frame:Show()
end

-- "Reset Settings Panel": back to 100% and the middle of the screen.
function addon.MI_SettingsUI_ResetLayout()
    addon.db.settings_panel_scale = 1.0
    if not frame then return end
    applyScale(1.0, true)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end
