local _, addon = ...

local FONT    = "Fonts\\FRIZQT__.TTF"
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]

local GOLD_R, GOLD_G, GOLD_B    = 0.90, 0.76, 0.22
local GOLD_BR, GOLD_BG, GOLD_BB = 0.50, 0.40, 0.09

local function MakeBackdrop()
    return { bgFile = BAR_TEX, edgeFile = BAR_TEX, edgeSize = 1,
             insets = { left = 1, right = 1, top = 1, bottom = 1 } }
end

local function StyleButton(btn, r, g, b)
    btn:SetBackdrop(MakeBackdrop())
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
    btn:SetBackdropBorderColor(r, g, b, 0.7)
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(r, g, b, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(r, g, b, 0.7) end)
end

local function StyleGoldButton(btn) StyleButton(btn, GOLD_BR, GOLD_BG, GOLD_BB) end

local function MakeLabel(parent, font, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or FONT, size or 11, "")
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    return fs
end

-- Data helpers

local function GetGuildData()
    local g = addon.MI_Guild_guildName
    if not g or not MysteriousQoLDB or not MysteriousQoLDB.guildData then return nil end
    return MysteriousQoLDB.guildData[g]
end

-- Serialization (regular export / import)
-- Format: JSON, version 1

local function JsonStr(s)
    if not s then return "null" end
    return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function JsonNum(n)
    return (n and n ~= false) and tostring(n) or "null"
end

function addon.MI_Guild_SerializeData()
    local data = GetGuildData()
    if not data or not data.chars then return nil, "No guild data available." end

    local entries = {}
    for charName, c in pairs(data.chars) do
        table.insert(entries, string.format(
            '    {"name":%s,"main":%s,"nick":%s,"joinDate":%s,"lastSeen":%s,"roles":%s,"modified":%s}',
            JsonStr(charName),
            JsonStr(c.main or charName),
            JsonStr(c.nick),
            JsonNum(c.joinDate),
            JsonNum(c.lastSeen),
            JsonStr(c.roles or "000"),
            JsonNum(c.modified)
        ))
    end

    return '{"version":1,"chars":[\n' .. table.concat(entries, ",\n") .. "\n]}"
end

function addon.MI_Guild_DeserializeData(str)
    if not str or str == "" then return false, "Nothing to import." end

    local version = str:match('"version"%s*:%s*(%d+)')
    if not version or tonumber(version) ~= 1 then
        return false, "Unrecognized format. Paste a MQOL export."
    end

    local data = GetGuildData()
    if not data then return false, "Not in a guild or data not initialized." end

    local flat = str:gsub("\r", ""):gsub("\n", " ")
    local chars = {}
    local count = 0

    for objStr in flat:gmatch("{([^}]+)}") do
        local name = objStr:match('"name"%s*:%s*"([^"]+)"')
        if name then
            local mainName = objStr:match('"main"%s*:%s*"([^"]+)"') or name
            local nick     = objStr:match('"nick"%s*:%s*"([^"]+)"')
            local joinDate = objStr:match('"joinDate"%s*:%s*(%d+)')
            local lastSeen = objStr:match('"lastSeen"%s*:%s*(%d+)')
            local roles    = objStr:match('"roles"%s*:%s*"([^"]+)"')
            local modified = objStr:match('"modified"%s*:%s*(%d+)')

            chars[name] = {
                main     = mainName,
                nick     = nick,
                joinDate = joinDate and tonumber(joinDate) or false,
                lastSeen = lastSeen and tonumber(lastSeen) or nil,
                roles    = roles or "000",
                modified = tonumber(modified) or 0,
            }
            count = count + 1
        end
    end

    if count == 0 then return false, "No valid entries found." end
    data.chars = chars
    return true, "Imported " .. count .. " characters."
end

-- Popup UI helpers

local function MakePopupFrame(name, title, w, h)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h); f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetBackdrop(MakeBackdrop())
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    f:SetBackdropBorderColor(0.45, 0.35, 0.08, 0.8)
    f:Hide()

    table.insert(UISpecialFrames, name)

    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(0.75, 0.60, 0.12, 1)

    local titleLbl = MakeLabel(f, FONT, 12, GOLD_R, GOLD_G, GOLD_B)
    titleLbl:SetPoint("TOPLEFT", 10, -8); titleLbl:SetText(title)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    return f
end

local function MakeEditArea(parent, topOffset, bottomOffset)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, topOffset)
    scroll:SetPoint("BOTTOMRIGHT", -30, bottomOffset)

    local editBox = CreateFrame("EditBox", nil, scroll, "BackdropTemplate")
    editBox:SetSize(440, 1200); editBox:SetMultiLine(true); editBox:SetAutoFocus(false)
    editBox:SetFont(FONT, 10, ""); editBox:SetTextColor(0.9, 0.9, 0.9, 1)
    editBox:SetBackdrop(MakeBackdrop())
    editBox:SetBackdropColor(0.04, 0.04, 0.04, 1)
    editBox:SetBackdropBorderColor(0.30, 0.24, 0.06, 0.7)
    editBox:SetScript("OnEscapePressed", function() parent:Hide() end)
    scroll:SetScrollChild(editBox)
    return editBox
end

local function MakeActionButton(parent, label, w, xOffset, yOffset, styleFn)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, 22); btn:SetPoint("BOTTOMRIGHT", xOffset, yOffset)
    styleFn(btn)
    local lbl = MakeLabel(btn, FONT, 11, GOLD_R, GOLD_G, GOLD_B)
    lbl:SetAllPoints(); lbl:SetJustifyH("CENTER"); lbl:SetText(label)
    return btn
end

-- Export popup

local exportPopup = nil

function addon.MI_Guild_ImportExport_ShowExport()
    if not exportPopup then
        exportPopup = MakePopupFrame("MysteriousQoL_ExportPopup", "Export Guild Data", 500, 360)

        local instr = MakeLabel(exportPopup, FONT, 10, 0.7, 0.7, 0.7)
        instr:SetPoint("TOPLEFT", 10, -28); instr:SetWidth(480)
        instr:SetText("Copy the text below to save your guild data (Ctrl+A to select all).")

        local editBox = MakeEditArea(exportPopup, -46, 44)
        exportPopup._editBox = editBox

        local closeBtn2 = CreateFrame("Button", nil, exportPopup, "BackdropTemplate")
        closeBtn2:SetSize(80, 22); closeBtn2:SetPoint("BOTTOMRIGHT", -10, 14)
        StyleGoldButton(closeBtn2)
        local lbl = MakeLabel(closeBtn2, FONT, 11, GOLD_R, GOLD_G, GOLD_B)
        lbl:SetAllPoints(); lbl:SetJustifyH("CENTER"); lbl:SetText("Close")
        closeBtn2:SetScript("OnClick", function() exportPopup:Hide() end)
    end

    local str, err = addon.MI_Guild_SerializeData()
    exportPopup._editBox:SetText(str or ("-- " .. (err or "No data")))
    if exportPopup:IsShown() then
        exportPopup:Hide()
    else
        exportPopup:Show()
        exportPopup._editBox:SetFocus()
        exportPopup._editBox:HighlightText()
    end
end

-- Import popup

local importPopup = nil

function addon.MI_Guild_ImportExport_ShowImport()
    if not importPopup then
        importPopup = MakePopupFrame("MysteriousQoL_ImportGuildPopup", "Import Guild Data", 500, 360)

        local instr = MakeLabel(importPopup, FONT, 10, 0.7, 0.7, 0.7)
        instr:SetPoint("TOPLEFT", 10, -28); instr:SetWidth(480)
        instr:SetText("Paste previously exported guild data below and click Import.")

        local editBox = MakeEditArea(importPopup, -46, 44)
        importPopup._editBox = editBox

        local statusLbl = MakeLabel(importPopup, FONT, 10, 0.7, 0.7, 0.7)
        statusLbl:SetPoint("BOTTOMLEFT", 10, 16); statusLbl:SetWidth(340); statusLbl:SetText("")
        importPopup._statusLbl = statusLbl

        local importBtn = MakeActionButton(importPopup, "Import", 90, -10, 14, StyleGoldButton)
        importBtn:SetScript("OnClick", function()
            local text = importPopup._editBox:GetText()
            local ok, msg = addon.MI_Guild_DeserializeData(text)
            importPopup._statusLbl:SetText(msg)
            if ok and addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
        end)
    end

    if importPopup:IsShown() then
        importPopup:Hide()
    else
        importPopup._editBox:SetText("")
        importPopup._statusLbl:SetText("")
        importPopup:Show()
        importPopup._editBox:SetFocus()
    end
end

