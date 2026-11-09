local addonName, addon = ...

-- Welcome popup (once per account) and a step-by-step setup helper that
-- offers a few popular options per section. /mqol setup reopens the helper.
-- Also a What's New popup once after each update. All use the settings
-- panel's look (addon.customUI.Style).

local LOGO = "Interface\\AddOns\\" .. addonName .. "\\MysteriousQoL"
local ROW_H = 30

local SECTIONS = {
    { name = "General",   icon = "Interface\\Icons\\Trade_Engineering",
      desc = "Quests, loot, bags and vendor." },
    { name = "UI",        icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
      desc = "Camera, chat and hiding things." },
    { name = "Reminders", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
      desc = "Buffs, reagents and repairs." },
    { name = "Fun",       icon = "Interface\\Icons\\INV_Misc_Ticket_Darkmoon_01",
      desc = "Sounds and MystGems." },
}

-- Reminders depend on game version and class.
local function reminderKeys()
    local keys = {}
    if addon.FOREVER then
        if select(2, UnitClass("player")) == "PALADIN" then keys[#keys + 1] = "combat_sealReminder_enabled" end
        if addon.MI_ClassBuffs_List then
            for _, buff in ipairs(addon.MI_ClassBuffs_List()) do keys[#keys + 1] = buff.key end
        end
        keys[#keys + 1] = "forever_reagents_enabled"
    else
        keys[#keys + 1] = "combat_buffReminder_enabled"
        keys[#keys + 1] = "combat_mailReminder_enabled"
    end
    keys[#keys + 1] = "combat_repairReminder_enabled"
    return keys
end

local STEPS = {
    { section = 1, keys = { "general_autoQuestAccept", "general_autoQuestTurnIn", "general_fasterLoot",
                            "vendor_autoRepair", "vendor_autoSell" } },
    { section = 2, keys = { "general_maxCameraDistance", "ui_chatCopy_enabled", "ui_hideErrors_enabled",
                            "ui_questXP_enabled" } },
    { section = 3, keys = reminderKeys },
    { section = 4, keys = { "fun_mystGems_enabled", "fun_owenWilson_enabled", "fun_batman_enabled",
                            "fun_vendorSound_enabled" } },
    { done = true },
}

local S -- addon.customUI.Style, set on first use

-- A window in the panel's style: rounded background, accent edge, banner
-- with an emblem, title and subtitle. Escape closes it.
local function makeWindow(name, width)
    S.LoadAccent()
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, 200)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, name)

    S.Rounded(f, "BACKGROUND", S.Colors.bg)
    local edge = S.Rounded(f, "BORDER", nil, "Ring")
    S.OnAccent(function()
        local A = S.Accent()
        edge:SetVertexColor(A.dim[1], A.dim[2], A.dim[3], 0.9)
    end)

    local banner = CreateFrame("Frame", nil, f)
    banner:SetPoint("TOPLEFT", 2, -2)
    banner:SetPoint("TOPRIGHT", -2, -2)
    banner:SetHeight(58)
    local glow = banner:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(S.White)
    glow:SetAllPoints()
    S.OnAccent(function()
        local A = S.Accent()
        glow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(A.deep[1], A.deep[2], A.deep[3], 0.9))
    end)

    f.emblem = S.Emblem(banner, 40, LOGO)
    f.emblem.icon:SetTexCoord(0, 1, 0, 1)
    f.emblem:SetPoint("LEFT", 12, 0)
    f.title = S.Text(banner, 16, nil, "OUTLINE")
    f.title:SetPoint("TOPLEFT", f.emblem, "TOPRIGHT", 10, -3)
    S.OnAccent(function() f.title:SetTextColor(unpack(S.Accent().accent)) end)
    f.sub = S.Text(banner, 11, S.Colors.dim)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.body = CreateFrame("Frame", nil, f)
    -- Anchored top and bottom so it has a height; without one the game
    -- cannot place it and draws nothing inside it.
    f.body:SetPoint("TOPLEFT", 14, -68)
    f.body:SetPoint("BOTTOMRIGHT", -14, 44)
    f:Hide()
    return f
end

-- Setup helper

local helper, stepIndex = nil, 1
local rows = {}

local function optionsFor(step)
    local keys = type(step.keys) == "function" and step.keys() or step.keys or {}
    local list = {}
    for _, key in ipairs(keys) do
        local def = addon.customUI.FindOption(key)
        if def and def.kind == "checkbox" then list[#list + 1] = def end
    end
    return list
end

local function getRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, helper.card)
    row:SetHeight(ROW_H)
    row.switch = S.Switch(row)
    row.switch:SetPoint("LEFT", 8, 0)
    row.label = S.Text(row, 13, S.Colors.text)
    row.label:SetPoint("LEFT", row.switch, "RIGHT", 10, 0)
    local function toggle()
        local def = row.def
        addon.db[def.key] = not addon.db[def.key]
        row.switch:SetOn(addon.db[def.key])
        if def.onChange then def.onChange(addon.db[def.key]) end
        addon.customUI.RefreshOpenPage()
    end
    row:SetScript("OnClick", toggle)
    row.switch:SetScript("OnClick", toggle)
    row:SetScript("OnEnter", function(self)
        if not self.def.tooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.def.label, 1, 1, 1)
        GameTooltip:AddLine(self.def.tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = row
    return row
end

local function drawStep()
    local step = STEPS[stepIndex]
    for _, row in ipairs(rows) do row:Hide() end

    -- The top left always shows the logo, like the settings panel.
    local section = step.section and SECTIONS[step.section]
    if section then
        helper.title:SetText("Setup: " .. section.name)
        helper.sub:SetText(section.desc)
    else
        helper.title:SetText("All set")
        helper.sub:SetText("Change anything later with /mqol.")
    end

    local options = section and optionsFor(step) or {}
    helper.note:SetText(section and "Popular picks. Everything else is in settings." or
        "Open settings to see every option.")
    for i, def in ipairs(options) do
        local row = getRow(i)
        row.def = def
        row.label:SetText(def.label)
        row.switch:SetOn(addon.db[def.key])
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", -4, 0)
        row:Show()
    end
    helper.card:SetHeight(math.max(1, #options) * ROW_H + 8)
    helper.card:SetShown(#options > 0)

    for i, dot in ipairs(helper.dots) do
        dot:SetVertexColor(unpack(i == stepIndex and S.Accent().accent or S.Colors.trackOff))
    end
    helper.back:SetShown(stepIndex > 1)
    helper.skip:SetShown(not step.done)
    helper.next.label:SetText(step.done and "Open Settings" or "Next")

    local cardH = #options > 0 and (helper.card:GetHeight() + 8) or 0
    helper:SetHeight(68 + 22 + cardH + 48)
end

local function createHelper()
    helper = makeWindow("MysteriousQoL_SetupHelper", 440)
    helper.note = S.Text(helper.body, 11, S.Colors.dim)
    helper.note:SetPoint("TOPLEFT", 0, 0)
    helper.card = CreateFrame("Frame", nil, helper.body)
    helper.card:SetPoint("TOPLEFT", 0, -22)
    helper.card:SetPoint("TOPRIGHT", 0, -22)
    S.Rounded(helper.card, "BACKGROUND", S.Colors.card)
    S.Rounded(helper.card, "BORDER", S.Colors.cardEdge, "Ring")

    helper.dots = {}
    for i = 1, #STEPS do
        local dot = helper:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(S.Media .. "Knob")
        dot:SetSize(8, 8)
        dot:SetPoint("TOPRIGHT", -14 - (#STEPS - i) * 14, -26)
        helper.dots[i] = dot
    end

    helper.next = S.Button(helper, "Next", 110, 24)
    helper.next:SetPoint("BOTTOMRIGHT", -14, 12)
    helper.next:SetScript("OnClick", function()
        if STEPS[stepIndex].done then
            helper:Hide()
            addon.customUI.Toggle()
            return
        end
        stepIndex = stepIndex + 1
        drawStep()
    end)
    helper.skip = S.Button(helper, "Skip Setup", 90, 24)
    helper.skip:SetPoint("RIGHT", helper.next, "LEFT", -8, 0)
    helper.skip:SetScript("OnClick", function() helper:Hide() end)
    helper.back = S.Button(helper, "Back", 70, 24)
    helper.back:SetPoint("BOTTOMLEFT", 14, 12)
    helper.back:SetScript("OnClick", function()
        stepIndex = math.max(1, stepIndex - 1)
        drawStep()
    end)
end

function addon.MI_Setup_Open()
    S = S or addon.customUI.Style
    if not helper then createHelper() end
    if addon.MI_Welcome_Hide then addon.MI_Welcome_Hide() end
    stepIndex = 1
    drawStep()
    helper:Show()
end

-- Welcome popup

local welcome

local function createWelcome()
    welcome = makeWindow("MysteriousQoL_Welcome", 400)
    welcome.title:SetText("Welcome to MysteriousQoL")
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
    welcome.sub:SetText("Version " .. (version or "?"))

    local intro = S.Text(welcome.body, 13, S.Colors.text)
    intro:SetPoint("TOPLEFT", 0, 0)
    intro:SetPoint("RIGHT", 0, 0)
    intro:SetWordWrap(true)
    S.OnAccent(function()
        local hex = CreateColor(unpack(S.Accent().accent)):GenerateHexColor()
        intro:SetText("Almost everything is |c" .. hex .. "off by default|r, so nothing changes until you pick what you want.")
    end)

    local card = CreateFrame("Frame", nil, welcome.body)
    card:SetPoint("TOPLEFT", 0, -40)
    card:SetPoint("TOPRIGHT", 0, -40)
    card:SetHeight(#SECTIONS * 28 + 8)
    S.Rounded(card, "BACKGROUND", S.Colors.card)
    S.Rounded(card, "BORDER", S.Colors.cardEdge, "Ring")
    -- Text only; the logo in the banner is the only image.
    for i, section in ipairs(SECTIONS) do
        local name = S.Text(card, 13, S.Colors.text)
        name:SetPoint("TOPLEFT", 12, -12 - (i - 1) * 28)
        name:SetText(section.name)
        local desc = S.Text(card, 11, S.Colors.dim)
        desc:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        desc:SetPoint("BOTTOM", name, "BOTTOM", 0, 0)
        desc:SetJustifyH("RIGHT")
        desc:SetText(section.desc)
    end

    local open = S.Button(welcome, "Open Settings", 110, 24)
    open:SetPoint("BOTTOMRIGHT", -14, 30)
    open:SetScript("OnClick", function()
        welcome:Hide()
        addon.customUI.Toggle()
    end)
    local guided = S.Button(welcome, "Guided Setup", 104, 24)
    guided:SetPoint("RIGHT", open, "LEFT", -8, 0)
    guided:SetScript("OnClick", addon.MI_Setup_Open)
    local close = S.Button(welcome, "Close", 70, 24)
    close:SetPoint("RIGHT", guided, "LEFT", -8, 0)
    close:SetScript("OnClick", function() welcome:Hide() end)

    local foot = S.Text(welcome, 10, S.Colors.faint)
    foot:SetPoint("BOTTOMRIGHT", -14, 12)
    foot:SetText("Shows once. Type /mqol any time.")

    welcome:SetHeight(68 + 40 + card:GetHeight() + 74)
end

function addon.MI_Welcome_Hide()
    if welcome then welcome:Hide() end
end

function addon.MI_Welcome_Show()
    S = S or addon.customUI.Style
    if not welcome then createWelcome() end
    welcome:Show()
end

-- What's New popup, once after each update

local whatsNew

-- "1.5.3" -> { 1, 5, 3 }
local function versionParts(v)
    local parts = {}
    for n in tostring(v):gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
    return parts
end

local function isNewer(a, b)
    local pa, pb = versionParts(a), versionParts(b)
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

-- Notes newer than the last version seen. If we don't know it, just this one.
local function newNotes(lastSeen, current)
    local list = {}
    for _, note in ipairs(addon.RELEASE_NOTES or {}) do
        if note.version then
            if lastSeen == "" then
                if note.version == current then list[#list + 1] = note end
            elseif isNewer(note.version, lastSeen) and not isNewer(note.version, current) then
                list[#list + 1] = note
            end
        end
    end
    return list
end

local function createWhatsNew()
    whatsNew = makeWindow("MysteriousQoL_WhatsNew", 420)
    whatsNew.title:SetText("What's new in MysteriousQoL")

    whatsNew.text = S.Text(whatsNew.body, 13, S.Colors.text)
    whatsNew.text:SetPoint("TOPLEFT", 0, 0)
    whatsNew.text:SetWidth(420 - 28)
    whatsNew.text:SetJustifyH("LEFT")
    whatsNew.text:SetWordWrap(true)

    local done = S.Button(whatsNew, "Got it", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -14, 12)
    done:SetScript("OnClick", function() whatsNew:Hide() end)
    local full = S.Button(whatsNew, "Full changelog", 110, 24)
    full:SetPoint("RIGHT", done, "LEFT", -8, 0)
    full:SetScript("OnClick", function()
        whatsNew:Hide()
        if addon.MI_Changelog_Toggle then addon.MI_Changelog_Toggle() end
    end)
end

local function showWhatsNew(notes, current)
    S = S or addon.customUI.Style
    if not whatsNew then createWhatsNew() end
    whatsNew.sub:SetText("Updated to version " .. current)
    local hex = CreateColor(unpack(S.Accent().accent)):GenerateHexColor()
    local parts = {}
    for _, note in ipairs(notes) do
        parts[#parts + 1] = "|c" .. hex .. "Version " .. note.version .. "|r\n" .. note.text
    end
    whatsNew.text:SetText(table.concat(parts, "\n\n"))
    whatsNew:SetHeight(68 + whatsNew.text:GetStringHeight() + 56)
    whatsNew:Show()
end

-- A few seconds after login: the welcome popup once per account, otherwise
-- What's New once per update.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    if not addon.db then return end
    local current = C_AddOns.GetAddOnMetadata(addonName, "Version")
    if not current then return end
    C_Timer.After(4, function()
        if InCombatLockdown() then return end
        local db = addon.db
        if not db.ui_welcomeShown then
            db.ui_welcomeShown = true
            db.ui_lastSeenVersion = current
            addon.MI_Welcome_Show()
            return
        end
        if db.ui_lastSeenVersion == current then return end
        local notes = newNotes(db.ui_lastSeenVersion, current)
        db.ui_lastSeenVersion = current
        if #notes > 0 then showWhatsNew(notes, current) end
    end)
end)
