local _, addon = ...

local GU = addon.GuildUI

-- Shared state accessible by all GuildPanel_*.lua submodules.
local P = {
    -- Layout constants
    PW = 680, PH = 540, LEFT_W = 292, ROW_H = 18, DETAIL_H = 244,

    -- Panel state
    frame        = nil,
    rosterScroll = nil, rosterChild  = nil,
    linkedScroll = nil, linkedChild  = nil,
    filterBox    = nil,
    logEdit      = nil,
    syncPopup    = nil,

    -- Selection / filter / sort state
    selectedName  = nil,
    rosterFilter  = "all",
    onlineOnly    = false,
    sortKey       = "name",
    sortAsc       = true,
    collapsedMains = {},
    sortHeaders    = {},
    rosterEntries  = {},

    -- Detail pane widget refs (populated by GuildPanel_Detail.lua)
    detail = {},
}
addon.GuildPanel = P

-- Shared helpers (used by Roster, Detail, and Sync submodules)

function P.ClassColor(classToken)
    local c = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
    if c then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
end

function P.ClassColorRGB(classToken)
    local c = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
    if c then return c.r, c.g, c.b end
    return 0.65, 0.65, 0.65
end

function P.GetMemberInfo(charName)
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, classDisplay, _, publicNote, officerNote, _, _, classToken = GetGuildRosterInfo(i)
        if name and (name == charName or (not charName:find("-", 1, true) and name:match("^([^%-]+)") == charName)) then
            return level or 0, classDisplay or "", classToken or "", publicNote or "", officerNote or ""
        end
    end
    return 0, "", "", "", ""
end

function P.GetCharData(charName)
    if not addon.MI_Guild_guildName or not MysteriousQoLGuildDB then return nil end
    local data = MysteriousQoLGuildDB[addon.MI_Guild_guildName]
    if not data or not data.chars then return nil end
    return data.chars[charName]
end

function P.IsInactive(lastSeen, group)
    local threshold = (addon.db.guild_inactive_days or 120) * 86400
    local now = time()
    local function seenRecently(ts) return ts and (now - ts) <= threshold end
    if group then
        if seenRecently(lastSeen) then return false end
        local mainData = P.GetCharData(group.main)
        if seenRecently(mainData and mainData.lastSeen) then return false end
        for _, altName in ipairs(group.alts) do
            local altData = P.GetCharData(altName)
            if seenRecently(altData and altData.lastSeen) then return false end
        end
        return true
    end
    return not seenRecently(lastSeen)
end

function P.GetOldestJoinDate(charNames)
    if not addon.MI_Guild_guildName then return nil end
    local data = MysteriousQoLGuildDB and MysteriousQoLGuildDB[addon.MI_Guild_guildName]
    if not data or not data.chars then return nil end
    local oldest = nil
    for _, charName in ipairs(charNames) do
        local c = data.chars[charName]
        if c and c.joinDate and c.joinDate ~= false then
            if not oldest or c.joinDate < oldest then oldest = c.joinDate end
        end
    end
    return oldest
end

function P.FormatDate(ts)
    if not ts or ts == false then return "Unknown" end
    return date("%b %d, %Y", ts)
end

function P.FormatDaysAgo(ts)
    if not ts then return nil end
    local days = math.floor((time() - ts) / 86400)
    if days == 0 then return "Today"
    elseif days == 1 then return "1 day ago"
    else return days .. " days ago" end
end

function P.ParseDateInput(s)
    if not s then return nil end
    s = s:match("^%s*(.-)%s*$")
    if s == "" or s:lower() == "unknown" then return false end
    local y, m, d = s:match("^(%d%d%d%d)-(%d%d?)-(%d%d?)$")
    if y then return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }) end
    m, d, y = s:match("^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
    if m then return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }) end
    local n = tonumber(s)
    if n and n > 0 then return n end
    return nil
end

-- Activity log text builder

local TYPE_COLOR = {
    JOIN    = "|cff55dd55",
    LEAVE   = "|cffdd5555",
    PROMOTE = "|cff55aaff",
    DEMOTE  = "|cffff9944",
}

local function BuildLogText()
    local entries = addon.MI_GuildLog_GetEntries()
    if #entries == 0 then return "|cff444444(No activity logged yet)|r" end
    local lines = {}
    for i = #entries, 1, -1 do
        local e   = entries[i]
        local ts  = date("|cff444444[%m/%d %H:%M]|r", e.t)
        local col = TYPE_COLOR[e.type] or ""
        local text
        if e.type == "JOIN" then
            text = ts .. " " .. col .. e.name .. " joined|r"
        elseif e.type == "LEAVE" then
            text = ts .. " " .. col .. e.name .. " left|r"
        elseif e.type == "PROMOTE" then
            text = ts .. " " .. col .. e.name .. " promoted to " .. (e.to or "?") .. "|r"
        elseif e.type == "DEMOTE" then
            text = ts .. " " .. col .. e.name .. " demoted to " .. (e.to or "?") .. "|r"
        else
            text = ts .. " " .. (e.name or "?")
        end
        table.insert(lines, text)
    end
    return table.concat(lines, "\n")
end

-- Main panel frame construction

local function BuildPanel()
    P.frame = CreateFrame("Frame", "MysteriousQoL_GuildPanel", UIParent, "BackdropTemplate")
    P.frame:SetSize(P.PW, P.PH); P.frame:SetPoint("CENTER")
    P.frame:SetFrameStrata("HIGH"); P.frame:SetClampedToScreen(true)
    P.frame:SetMovable(true); P.frame:EnableMouse(true)
    P.frame:RegisterForDrag("LeftButton")
    P.frame:SetScript("OnDragStart", P.frame.StartMoving)
    P.frame:SetScript("OnDragStop",  P.frame.StopMovingOrSizing)
    P.frame:SetBackdrop(GU.MakeBackdrop())
    P.frame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    P.frame:SetBackdropBorderColor(0.45, 0.35, 0.08, 0.8)
    P.frame:SetScale(addon.db.guild_panel_scale or 1.0)
    P.frame:Hide()

    table.insert(UISpecialFrames, "MysteriousQoL_GuildPanel")

    local accent = P.frame:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(0.75, 0.60, 0.12, 1)

    local title = GU.MakeLabel(P.frame, GU.FONT, 13, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    title:SetPoint("TOPLEFT", 10, -8); title:SetText("Guild Manager")

    local closeBtn = CreateFrame("Button", nil, P.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() P.frame:Hide() end)

    local function MakeToolbarButton(label, x, onClick)
        local btn = CreateFrame("Button", nil, P.frame, "BackdropTemplate")
        btn:SetSize(88, 22); btn:SetPoint("TOPLEFT", x, -26)
        GU.StyleGoldButton(btn)
        local lbl = GU.MakeLabel(btn, GU.FONT, 11, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
        lbl:SetAllPoints(); lbl:SetJustifyH("CENTER"); lbl:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    MakeToolbarButton("Sync...", 8, function()
        P.BuildSyncPopup()
        if P.syncPopup:IsShown() then
            P.syncPopup:Hide()
        else
            if addon.MI_GuildSync_BroadcastHello then addon.MI_GuildSync_BroadcastHello() end
            P.syncPopup:Show(); P.RefreshSyncPopup()
        end
    end)

    local searchLabel = GU.MakeLabel(P.frame, GU.FONT, 10, 0.50, 0.42, 0.12)
    searchLabel:SetPoint("TOPRIGHT", -120, -31); searchLabel:SetText("FILTER:")

    P.filterBox = CreateFrame("EditBox", nil, P.frame, "BackdropTemplate")
    P.filterBox:SetSize(106, 20); P.filterBox:SetPoint("TOPRIGHT", -8, -26)
    P.filterBox:SetFont(GU.FONT, 11, ""); P.filterBox:SetTextColor(1, 1, 1, 1)
    P.filterBox:SetAutoFocus(false)
    P.filterBox:SetBackdrop(GU.MakeBackdrop())
    P.filterBox:SetBackdropColor(0.04, 0.04, 0.04, 1)
    P.filterBox:SetBackdropBorderColor(0.40, 0.32, 0.08, 0.7)
    P.filterBox:SetScript("OnTextChanged", function()
        P.BuildRosterList(); P.rosterScroll:SetVerticalScroll(0)
    end)
    P.filterBox:SetScript("OnEscapePressed", function()
        P.filterBox:SetText(""); P.filterBox:ClearFocus()
    end)

    local toolSep = P.frame:CreateTexture(nil, "ARTWORK")
    toolSep:SetHeight(1); toolSep:SetPoint("TOPLEFT", 1, -50); toolSep:SetPoint("TOPRIGHT", -1, -50)
    toolSep:SetColorTexture(0.32, 0.26, 0.06, 0.5)

    local contentTop = -54
    local hdrY       = contentTop - 22
    local listTop    = hdrY - 14
    local rightX     = P.LEFT_W + 14

    P.BuildRosterSection(P.frame, contentTop, hdrY, listTop)

    local detailHdr = GU.MakeLabel(P.frame, GU.FONT, 9, 0.50, 0.42, 0.12)
    detailHdr:SetPoint("TOPLEFT", P.LEFT_W + 16, contentTop + 2)
    detailHdr:SetText("SELECTED CHARACTER")

    local divider = P.frame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT",    P.LEFT_W + 8, listTop)
    divider:SetPoint("BOTTOMLEFT", P.LEFT_W + 8, 2)
    divider:SetColorTexture(0.32, 0.26, 0.06, 0.5)

    P.BuildDetailSection(P.frame, rightX, listTop)

    -- Activity log section
    local midSepY = listTop - P.DETAIL_H

    local midSep = P.frame:CreateTexture(nil, "ARTWORK")
    midSep:SetHeight(1)
    midSep:SetPoint("TOPLEFT",  rightX - 4, midSepY)
    midSep:SetPoint("TOPRIGHT", -6,         midSepY)
    midSep:SetColorTexture(0.30, 0.24, 0.06, 0.45)

    local logHdr = GU.MakeLabel(P.frame, GU.FONT, 9, 0.50, 0.42, 0.12)
    logHdr:SetPoint("TOPLEFT", rightX, midSepY - 4); logHdr:SetText("ACTIVITY LOG")

    local clearLogBtn = CreateFrame("Button", nil, P.frame, "BackdropTemplate")
    clearLogBtn:SetSize(44, 14)
    clearLogBtn:SetPoint("TOPLEFT", rightX + 76, midSepY - 3)
    GU.StyleGoldButton(clearLogBtn)
    local clearLogLbl = GU.MakeLabel(clearLogBtn, GU.FONT, 9, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    clearLogLbl:SetAllPoints(); clearLogLbl:SetJustifyH("CENTER"); clearLogLbl:SetText("Clear")
    clearLogBtn:SetScript("OnClick", function()
        addon.MI_GuildLog_Clear()
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    end)

    local logScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildLogScroll", P.frame)
    logScroll:SetPoint("TOPLEFT",     rightX, midSepY - 18)
    logScroll:SetPoint("BOTTOMRIGHT", -4,     22)
    logScroll:EnableMouseWheel(true)
    logScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll(); local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    P.logEdit = CreateFrame("EditBox", nil, logScroll)
    P.logEdit:SetMultiLine(true); P.logEdit:SetAutoFocus(false)
    P.logEdit:SetFont(GU.FONT, 10, ""); P.logEdit:SetTextColor(1, 1, 1, 1)
    P.logEdit:SetWidth(P.PW - P.LEFT_W - 26); P.logEdit:SetEnabled(false)
    logScroll:SetScrollChild(P.logEdit)

    -- Scale grip
    local grip = CreateFrame("Frame", nil, P.frame)
    grip:SetSize(14, 14); grip:SetPoint("BOTTOMRIGHT", -2, 2); grip:EnableMouse(true)
    local function MakeDot(x, y)
        local t = grip:CreateTexture(nil, "OVERLAY")
        t:SetSize(3, 3); t:SetPoint("BOTTOMRIGHT", x, y); t:SetColorTexture(0.55, 0.44, 0.10, 0.5)
    end
    MakeDot(-1,1); MakeDot(-5,1); MakeDot(-1,5); MakeDot(-9,1); MakeDot(-5,5); MakeDot(-1,9)
    grip:SetScript("OnEnter", function() for _, t in ipairs({grip:GetRegions()}) do t:SetAlpha(1) end end)
    grip:SetScript("OnLeave", function() for _, t in ipairs({grip:GetRegions()}) do t:SetAlpha(0.5) end end)
    local gripDragging, gripStartX, gripStartScale = false, 0, 1.0
    grip:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        gripDragging = true; gripStartX = GetCursorPosition(); gripStartScale = P.frame:GetScale()
    end)
    grip:SetScript("OnMouseUp", function() gripDragging = false end)
    grip:SetScript("OnUpdate", function()
        if not gripDragging then return end
        local cx = GetCursorPosition()
        local newScale = math.max(0.6, math.min(1.4, gripStartScale + (cx - gripStartX) / 600))
        local snapped  = math.floor(newScale / 0.05 + 0.5) * 0.05
        addon.db.guild_panel_scale = snapped; P.frame:SetScale(snapped)
    end)
end

-- Public API

function addon.MI_GuildPanel_Init()
    -- Panel built lazily on first toggle.
end

function addon.MI_GuildPanel_Toggle()
    if not addon.db.guild_alts_enabled then return end
    if not P.frame then BuildPanel() end
    if P.frame:IsShown() then
        P.frame:Hide()
    else
        C_GuildInfo.GuildRoster()
        addon.MI_GuildPanel_Refresh()
        P.frame:Show()
    end
end

function addon.MI_GuildPanel_Refresh()
    if not P.frame then return end
    P.BuildRosterList()
    P.UpdateDetail(P.selectedName)
    P.RefreshSyncPopup()
    P.logEdit:SetText(BuildLogText())
    C_Timer.After(0, function()
        local logScroll = P.logEdit:GetParent()
        if logScroll and logScroll.SetVerticalScroll then logScroll:SetVerticalScroll(0) end
    end)
end

function addon.MI_GuildPanel_UpdateDetail(name)
    P.selectedName = name
    P.UpdateDetail(name)
end
