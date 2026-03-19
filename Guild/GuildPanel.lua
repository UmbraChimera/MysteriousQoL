local _, addon = ...

local FONT      = "Fonts\\FRIZQT__.TTF"
local FONT_HDR  = "Interface\\AddOns\\MysteriousQoL\\Fonts\\DejaVuLGCSans.ttf"
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]

local PW, PH   = 680, 540
local LEFT_W   = 292
local ROW_H    = 18
local DETAIL_H = 244

local GOLD_R, GOLD_G, GOLD_B    = 0.90, 0.76, 0.22
local GOLD_BR, GOLD_BG, GOLD_BB = 0.50, 0.40, 0.09
local RED_BR,  RED_BG,  RED_BB  = 0.55, 0.10, 0.10
local RED_R,   RED_G,   RED_B   = 1.00, 0.40, 0.40

local panelFrame = nil

local rosterScroll, rosterChild
local rosterRows    = {}
local rosterEntries = {}
local selectedName  = nil
local filterBox     = nil

local detailNameLabel, detailStatusLabel, detailNoteLabel
local detailLastSeenLabel, detailJoinLabel, detailJoinEditBtn
local detailInactiveLabel
local detailRoleTankCB, detailRoleHealCB, detailRoleDpsCB
local linkedScroll, linkedChild
local linkedRows = {}
local detailActionBtn, detailDestructBtn
local detailNickLabel, detailNickBtn
local detailRolesHdr

local logEdit

local rosterFilter = "all"
local onlineOnly   = false
local radioAll, radioMains, radioAlts, radioUnlinked, onlineOnlyBtn

local syncPopup     = nil
local syncPopupRows = {}
local syncPopupNoPeers   = nil
local syncPopupLeaderLbl = nil
local syncPopupAllBtn    = nil

local collapsedMains = {}
local sortKey = "name"
local sortAsc = true
local sortHeaders = {}

-- ---------------------------------------------------------------------------------

local function ClassColor(classToken)
    local c = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
    if c then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
end

local function ClassColorRGB(classToken)
    local c = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
    if c then return c.r, c.g, c.b end
    return 0.65, 0.65, 0.65
end

local function GetMemberInfo(charName)
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, classDisplay, _, publicNote, officerNote, _, _, classToken = GetGuildRosterInfo(i)
        if name and (name == charName or (not charName:find("-", 1, true) and name:match("^([^%-]+)") == charName)) then
            return level or 0, classDisplay or "", classToken or "", publicNote or "", officerNote or ""
        end
    end
    return 0, "", "", "", ""
end

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
local function StyleRedButton(btn)  StyleButton(btn, RED_BR,  RED_BG,  RED_BB)  end

local function MakeLabel(parent, font, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or FONT, size or 11, "")
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    return fs
end

local function FormatDate(ts)
    if not ts or ts == false then return "Unknown" end
    return date("%b %d, %Y", ts)
end

local function FormatDaysAgo(ts)
    if not ts then return nil end
    local days = math.floor((time() - ts) / 86400)
    if days == 0 then return "Today"
    elseif days == 1 then return "1 day ago"
    else return days .. " days ago" end
end

local function GetCharData(charName)
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return nil end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return nil end
    return data.chars[charName]
end

local function IsInactive(lastSeen, group)
    local threshold = (addon.db.guild_inactive_days or 120) * 86400
    local now = time()
    local function seenRecently(ts)
        return ts and (now - ts) <= threshold
    end
    if group then
        if seenRecently(lastSeen) then return false end
        local mainData = GetCharData(group.main)
        if seenRecently(mainData and mainData.lastSeen) then return false end
        for _, altName in ipairs(group.alts) do
            local altData = GetCharData(altName)
            if seenRecently(altData and altData.lastSeen) then return false end
        end
        return true
    end
    return not seenRecently(lastSeen)
end

local function GetOldestJoinDate(charNames)
    if not addon.MI_Guild_guildName then return nil end
    local data = MysteriousQoLDB.guildData and MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
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

local function ParseDateInput(s)
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

-- ---------------------------------------------------------------------------------
-- Custom scrollbar (draggable thumb)

local function MakeScrollbar(scrollFrame, scrollChild, thumbMinH)
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
        local maxS = scrollFrame:GetVerticalScrollRange()
        local cur  = scrollFrame:GetVerticalScroll()
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

-- ---------------------------------------------------------------------------------
-- Input dialog with autocomplete

local inputDialog, inputCallback
local inputSkipAutocomplete = false
local inputAllowEmpty       = false
local autocompleteFrame, autocompleteRows, suppressAutocomplete = nil, {}, false
local MAX_AUTOCOMPLETE   = 8
local AUTOCOMPLETE_ROW_H = 20
local INPUT_DIALOG_H     = 88

local function GetGuildMemberMatches(filter)
    local results = {}
    filter = filter:lower()
    for i = 1, GetNumGuildMembers() do
        local name, rankName = GetGuildRosterInfo(i)
        if name and name:lower():find(filter, 1, true) then
            table.insert(results, { name = name, rank = rankName or "" })
        end
    end
    table.sort(results, function(a, b) return a.name < b.name end)
    if #results > MAX_AUTOCOMPLETE then
        local t = {}; for i = 1, MAX_AUTOCOMPLETE do t[i] = results[i] end; return t
    end
    return results
end

local function HideAutocomplete()
    if autocompleteFrame then autocompleteFrame:Hide() end
    for _, r in ipairs(autocompleteRows) do r:Hide() end
    if inputDialog then inputDialog:SetHeight(INPUT_DIALOG_H) end
end

local function UpdateAutocomplete(text)
    if inputSkipAutocomplete then return end
    if not autocompleteFrame then return end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then HideAutocomplete(); return end
    local results = GetGuildMemberMatches(text)
    if #results == 0 then HideAutocomplete(); return end
    for i = 1, #results do
        if not autocompleteRows[i] then
            local row = CreateFrame("Button", nil, autocompleteFrame)
            row:SetHeight(AUTOCOMPLETE_ROW_H)
            row:SetPoint("LEFT", 0, 0); row:SetPoint("RIGHT", 0, 0)
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0); row.bg = bg
            row.nameLabel = MakeLabel(row, FONT, 11)
            row.nameLabel:SetPoint("LEFT", 8, 0); row.nameLabel:SetPoint("RIGHT", -60, 0)
            row.nameLabel:SetJustifyH("LEFT")
            row.rankLabel = MakeLabel(row, FONT, 9, 0.45, 0.45, 0.45)
            row.rankLabel:SetPoint("RIGHT", -4, 0); row.rankLabel:SetJustifyH("RIGHT")
            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.22, 0.18, 0.04, 0.35)
                self.nameLabel:SetTextColor(1, 0.88, 0.3, 1)
            end)
            row:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0, 0, 0, 0)
                self.nameLabel:SetTextColor(1, 1, 1, 1)
            end)
            row:SetScript("OnClick", function(self)
                suppressAutocomplete = true
                inputDialog.editBox:SetText(self.memberName)
                suppressAutocomplete = false
                HideAutocomplete()
                inputDialog.editBox:SetCursorPosition(#self.memberName)
            end)
            autocompleteRows[i] = row
        end
    end
    for i, data in ipairs(results) do
        local row = autocompleteRows[i]
        row:SetPoint("TOPLEFT", autocompleteFrame, "TOPLEFT", 0, -(i - 1) * AUTOCOMPLETE_ROW_H)
        row.memberName = data.name
        row.nameLabel:SetText(data.name); row.rankLabel:SetText(data.rank); row:Show()
    end
    for i = #results + 1, #autocompleteRows do autocompleteRows[i]:Hide() end
    local h = #results * AUTOCOMPLETE_ROW_H
    autocompleteFrame:SetHeight(h); autocompleteFrame:Show()
    inputDialog:SetHeight(INPUT_DIALOG_H + h + 2)
end

local function BuildInputDialog()
    if inputDialog then return end
    local parent = panelFrame or UIParent
    inputDialog = CreateFrame("Frame", "MysteriousQoL_GuildInput", parent, "BackdropTemplate")
    inputDialog:SetSize(270, INPUT_DIALOG_H)
    inputDialog:SetPoint("CENTER")
    inputDialog:SetFrameLevel(parent:GetFrameLevel() + 20)
    inputDialog:SetBackdrop(MakeBackdrop())
    inputDialog:SetBackdropColor(0.07, 0.07, 0.07, 0.98)
    inputDialog:SetBackdropBorderColor(0.55, 0.44, 0.12, 1)
    inputDialog:Hide()

    inputDialog.titleText = MakeLabel(inputDialog, FONT, 11, GOLD_R, GOLD_G, GOLD_B)
    inputDialog.titleText:SetPoint("TOPLEFT", 8, -8)

    local editBox = CreateFrame("EditBox", nil, inputDialog, "BackdropTemplate")
    editBox:SetSize(250, 22); editBox:SetPoint("TOP", 0, -28)
    editBox:SetFont(FONT, 11, ""); editBox:SetTextColor(1, 1, 1, 1); editBox:SetAutoFocus(true)
    editBox:SetBackdrop(MakeBackdrop())
    editBox:SetBackdropColor(0.04, 0.04, 0.04, 1)
    editBox:SetBackdropBorderColor(0.40, 0.32, 0.08, 0.8)
    editBox:SetScript("OnTextChanged", function()
        if suppressAutocomplete then return end
        UpdateAutocomplete(editBox:GetText())
    end)
    editBox:SetScript("OnEnterPressed", function()
        local t = editBox:GetText():match("^%s*(.-)%s*$")
        inputDialog:Hide()
        if (t ~= "" or inputAllowEmpty) and inputCallback then inputCallback(t) end
    end)
    editBox:SetScript("OnEscapePressed", function() inputDialog:Hide() end)
    inputDialog.editBox = editBox

    autocompleteFrame = CreateFrame("Frame", nil, inputDialog, "BackdropTemplate")
    autocompleteFrame:SetPoint("TOPLEFT",  editBox, "BOTTOMLEFT",  0, -2)
    autocompleteFrame:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 0, -2)
    autocompleteFrame:SetHeight(0)
    autocompleteFrame:SetFrameLevel(inputDialog:GetFrameLevel() + 5)
    autocompleteFrame:SetBackdrop(MakeBackdrop())
    autocompleteFrame:SetBackdropColor(0.08, 0.07, 0.03, 0.97)
    autocompleteFrame:SetBackdropBorderColor(0.35, 0.28, 0.07, 0.6)
    autocompleteFrame:Hide()

    local okBtn = CreateFrame("Button", nil, inputDialog, "BackdropTemplate")
    okBtn:SetSize(70, 20); okBtn:SetPoint("BOTTOMLEFT", 8, 8)
    StyleGoldButton(okBtn)
    local okLabel = MakeLabel(okBtn, FONT, 10, GOLD_R, GOLD_G, GOLD_B)
    okLabel:SetAllPoints(); okLabel:SetJustifyH("CENTER"); okLabel:SetText("OK")
    okBtn:SetScript("OnClick", function()
        local t = editBox:GetText():match("^%s*(.-)%s*$")
        inputDialog:Hide()
        if (t ~= "" or inputAllowEmpty) and inputCallback then inputCallback(t) end
    end)

    local cancelBtn = CreateFrame("Button", nil, inputDialog, "BackdropTemplate")
    cancelBtn:SetSize(70, 20); cancelBtn:SetPoint("BOTTOMRIGHT", -8, 8)
    StyleRedButton(cancelBtn)
    local cancelLabel = MakeLabel(cancelBtn, FONT, 10, RED_R, RED_G, RED_B)
    cancelLabel:SetAllPoints(); cancelLabel:SetJustifyH("CENTER"); cancelLabel:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() inputDialog:Hide() end)
end

local function ShowInputDialog(title, callback, noAC, prefill, allowEmpty)
    BuildInputDialog()
    inputDialog.titleText:SetText(title)
    inputSkipAutocomplete = noAC and true or false
    inputAllowEmpty = allowEmpty and true or false
    suppressAutocomplete = true; inputDialog.editBox:SetText(prefill or ""); suppressAutocomplete = false
    if prefill and prefill ~= "" then inputDialog.editBox:SetCursorPosition(#prefill) end
    HideAutocomplete()
    inputCallback = callback
    if not noAC then C_GuildInfo.GuildRoster() end
    inputDialog:Show()
    inputDialog.editBox:SetFocus()
end

-- ---------------------------------------------------------------------------------
-- Roster entries: build + sort

local function BuildRosterEntries(filter)
    local entries  = {}
    local lowerF   = filter and filter:lower() or ""
    for i = 1, GetNumGuildMembers() do
        local name, rankName, rankIndex, level, _, _, _, _, isOnline, _, classToken = GetGuildRosterInfo(i)
        if name then
            local _, group, isMain = addon.MI_Guild_GetGroupForChar(name)
            local charData = GetCharData(name)
            local matches = lowerF == ""
                or name:lower():find(lowerF, 1, true)
                or (group and group.main:lower():find(lowerF, 1, true))
                or (group and group.nick and group.nick:lower():find(lowerF, 1, true))
            if matches
                and (rosterFilter == "all"
                     or (rosterFilter == "mains"    and group and isMain and #group.alts > 0)
                     or (rosterFilter == "alts"     and group and not isMain)
                     or (rosterFilter == "unlinked" and not group))
                and (not onlineOnly or isOnline)
            then
                table.insert(entries, {
                    name       = name,
                    rank       = rankName or "",
                    rankIdx    = rankIndex or 0,
                    mainName   = mainName,
                    group      = group,
                    isMain     = isMain,
                    level      = level or 0,
                    classToken = classToken or "",
                    isOnline   = isOnline,
                    lastSeen   = charData and charData.lastSeen,
                    joinDate   = charData and charData.joinDate,
                    roles      = charData and charData.roles or "000",
                })
            end
        end
    end

    table.sort(entries, function(entryA, entryB)
        if sortKey == "level" then
            local levelA = entryA.level or 0
            local levelB = entryB.level or 0
            if levelA ~= levelB then
                if sortAsc then return levelA < levelB else return levelA > levelB end
            end
        end
        local nameKeyA = entryA.group and (entryA.group.main .. "\001" .. (entryA.isMain and "\000" or entryA.name)) or entryA.name
        local nameKeyB = entryB.group and (entryB.group.main .. "\001" .. (entryB.isMain and "\000" or entryB.name)) or entryB.name
        if sortAsc then return nameKeyA < nameKeyB else return nameKeyA > nameKeyB end
    end)
    return entries
end

-- ---------------------------------------------------------------------------------

local function ShowRosterContextMenu(charName)
    local _, group = addon.MI_Guild_GetGroupForChar(charName)
    MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
        rootDescription:CreateTitle(charName)
        rootDescription:CreateButton("Set as Main", function()
            addon.MI_Guild_SetAsMain(charName)
            addon.MI_GuildPanel_Refresh()
        end)
        rootDescription:CreateButton("Link as Alt to...", function()
            ShowInputDialog("Link " .. charName .. " as alt of:", function(main)
                if main and main ~= "" then
                    addon.MI_Guild_LinkAltToMain(charName, main)
                    addon.MI_GuildPanel_Refresh()
                end
            end)
        end)
        if group then
            rootDescription:CreateButton("Unlink", function()
                addon.MI_Guild_UnlinkChar(charName)
                addon.MI_GuildPanel_Refresh()
            end)
        end
    end)
end

-- ---------------------------------------------------------------------------------
-- Roster rows (pooled)

local function GetOrCreateRosterRow(i)
    if rosterRows[i] then return rosterRows[i] end

    local row = CreateFrame("Frame", nil, rosterChild)
    row:SetHeight(ROW_H)

    local colorBar = row:CreateTexture(nil, "ARTWORK")
    colorBar:SetWidth(3)
    colorBar:SetPoint("TOPLEFT", 0, 0); colorBar:SetPoint("BOTTOMLEFT", 0, 0)
    colorBar:SetColorTexture(0.65, 0.65, 0.65, 0.5)
    row.colorBar = colorBar

    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(); hl:SetColorTexture(0.25, 0.2, 0.05, 0); row.hl = hl

    -- Level column (after color bar)
    row.levelLabel = MakeLabel(row, FONT, 9, 0.55, 0.55, 0.55)
    row.levelLabel:SetPoint("LEFT", 4, 0)
    row.levelLabel:SetWidth(22)
    row.levelLabel:SetJustifyH("RIGHT")

    -- Collapse toggle for mains with alts
    local collapseBtn = CreateFrame("Button", nil, row)
    collapseBtn:SetSize(13, ROW_H)
    collapseBtn:SetPoint("LEFT", 27, 0)
    collapseBtn:Hide()
    local collapseLbl = collapseBtn:CreateFontString(nil, "OVERLAY")
    collapseLbl:SetFont(FONT, 9, "")
    collapseLbl:SetTextColor(0.7, 0.6, 0.3, 1)
    collapseLbl:SetAllPoints()
    collapseLbl:SetJustifyH("CENTER")
    collapseBtn.lbl = collapseLbl
    row.collapseBtn = collapseBtn

    row.nameLabel = MakeLabel(row, FONT, 11)
    row.nameLabel:SetPoint("LEFT", 41, 0)
    row.nameLabel:SetPoint("RIGHT", -110, 0)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetWordWrap(false)

    -- Role icons: tank, healer, dps
    local function MakeRoleIcon(xOff)
        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetSize(12, 12); tex:Hide()
        tex:SetPoint("RIGHT", row, "RIGHT", xOff, 0)
        return tex
    end
    row.roleIconTank = MakeRoleIcon(-94)
    row.roleIconHeal = MakeRoleIcon(-80)
    row.roleIconDps  = MakeRoleIcon(-66)

    -- Inactive indicator
    row.inactiveMark = MakeLabel(row, FONT_HDR, 9, 1, 0.5, 0, 1)
    row.inactiveMark:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    row.inactiveMark:SetWidth(14)
    row.inactiveMark:SetJustifyH("CENTER")
    row.inactiveMark:Hide()

    -- Status label (M = main, main name = alt)
    row.statusLabel = MakeLabel(row, FONT, 9)
    row.statusLabel:SetPoint("RIGHT", -4, 0)
    row.statusLabel:SetWidth(64)
    row.statusLabel:SetJustifyH("RIGHT")

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self.entryName ~= selectedName then
            self.hl:SetColorTexture(0.22, 0.18, 0.04, 0.12)
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.entryName ~= selectedName then
            self.hl:SetColorTexture(0, 0, 0, 0)
        end
    end)
    row:SetScript("OnMouseUp", function(self, btn)
        if not self.entryName then return end
        if btn == "RightButton" then ShowRosterContextMenu(self.entryName); return end
        selectedName = self.entryName
        for _, r in ipairs(rosterRows) do r.hl:SetColorTexture(0, 0, 0, 0) end
        self.hl:SetColorTexture(0.28, 0.22, 0.05, 0.25)
        addon.MI_GuildPanel_UpdateDetail(selectedName)
    end)

    rosterRows[i] = row
    return row
end

-- ---------------------------------------------------------------------------------
-- Linked-char rows in detail pane (pooled)

local function GetOrCreateLinkedRow(i)
    if linkedRows[i] then return linkedRows[i] end
    local row = CreateFrame("Frame", nil, linkedChild)
    row:SetHeight(ROW_H)

    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(); hl:SetColorTexture(0.25, 0.2, 0.05, 0); row.hl = hl

    row.nameLabel = MakeLabel(row, FONT, 11)
    row.nameLabel:SetPoint("LEFT", 4, 0)
    row.nameLabel:SetPoint("RIGHT", -68, 0)
    row.nameLabel:SetJustifyH("LEFT")

    row.setMainBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.setMainBtn:SetSize(60, 15)
    row.setMainBtn:SetPoint("RIGHT", -3, 0)
    StyleGoldButton(row.setMainBtn)
    local setMainLabel = MakeLabel(row.setMainBtn, FONT, 9, GOLD_R, GOLD_G, GOLD_B)
    setMainLabel:SetAllPoints(); setMainLabel:SetJustifyH("CENTER"); setMainLabel:SetText("Set Main")
    row.setMainBtn:SetScript("OnClick", function()
        if not row.charName then return end
        addon.MI_Guild_SetAsMain(row.charName)
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    end)

    linkedRows[i] = row
    return row
end

-- ---------------------------------------------------------------------------------
-- Detail pane

function addon.MI_GuildPanel_UpdateDetail(name)
    for _, row in ipairs(linkedRows) do row:Hide(); row:ClearAllPoints() end
    detailActionBtn:Hide(); detailDestructBtn:Hide()
    detailActionBtn:SetScript("OnClick", nil); detailDestructBtn:SetScript("OnClick", nil)
    detailRoleTankCB:SetScript("OnClick", nil)
    detailRoleHealCB:SetScript("OnClick", nil)
    detailRoleDpsCB:SetScript("OnClick", nil)

    if not name then
        detailNameLabel:SetText("|cff333333Select a member from the roster|r")
        detailStatusLabel:SetText(""); detailNoteLabel:SetText("")
        detailJoinLabel:SetText(""); detailLastSeenLabel:SetText("")
        detailInactiveLabel:Hide(); detailJoinEditBtn:Hide()
        detailNickLabel:Hide(); detailNickBtn:Hide()
        detailRoleTankCB:Hide(); detailRoleTankCB.roleLbl:Hide()
        detailRoleHealCB:Hide(); detailRoleHealCB.roleLbl:Hide()
        detailRoleDpsCB:Hide();  detailRoleDpsCB.roleLbl:Hide()
        if detailRolesHdr then detailRolesHdr:Hide() end
        linkedChild:SetHeight(20)
        return
    end

    local _, group, isMain = addon.MI_Guild_GetGroupForChar(name)
    local charData = GetCharData(name)
    local level, classDisplay, classToken, publicNote, officerNote = GetMemberInfo(name)
    local cc     = ClassColor(classToken)
    local infoStr = (level > 0 and classDisplay ~= "") and ("|cff888888" .. level .. " " .. classDisplay .. "|r  ") or ""

    detailNameLabel:SetText(cc .. name .. "|r")

    -- Notes
    local noteLines = {}
    if publicNote  ~= "" then table.insert(noteLines, "|cff888888Note:|r " .. publicNote) end
    if officerNote ~= "" then table.insert(noteLines, "|cff666666Officer:|r " .. officerNote) end
    detailNoteLabel:SetText(table.concat(noteLines, "\n"))

    -- Last seen
    local lastSeen = charData and charData.lastSeen
    if lastSeen then
        detailLastSeenLabel:SetText("|cff666666Last seen:|r " .. FormatDaysAgo(lastSeen))
    else
        detailLastSeenLabel:SetText("|cff444444Last seen:|r |cff444444Unknown|r")
    end

    -- Join date (oldest across linked group)
    local charNames = { group and group.main or name }
    if group then for _, a in ipairs(group.alts) do table.insert(charNames, a) end end
    local joinTs = GetOldestJoinDate(charNames)
    if joinTs then
        detailJoinLabel:SetText("|cff666666Joined:|r " .. FormatDate(joinTs))
    else
        detailJoinLabel:SetText("|cff444444Joined:|r |cff444444Unknown|r")
    end
    detailJoinEditBtn:Show()
    detailJoinEditBtn:SetScript("OnClick", function()
        local curStr = joinTs and FormatDate(joinTs) or ""
        ShowInputDialog("Join date (YYYY-MM-DD or Unknown):", function(input)
            local ts = ParseDateInput(input)
            if ts ~= nil then
                addon.MI_Guild_SetJoinDate(name, ts)
                addon.MI_GuildPanel_Refresh()
            end
        end, true, curStr, true)
    end)

    -- Inactivity warning
    if IsInactive(lastSeen, group) then
        detailInactiveLabel:SetText("|cffff8800⚠ Inactive|r")
        detailInactiveLabel:Show()
    else
        detailInactiveLabel:Hide()
    end

    -- Roles
    if detailRolesHdr then detailRolesHdr:Show() end
    local roles = charData and charData.roles or "000"
    detailRoleTankCB:SetChecked(roles:sub(1,1) == "1"); detailRoleTankCB:Show(); detailRoleTankCB.roleLbl:Show()
    detailRoleHealCB:SetChecked(roles:sub(2,2) == "1"); detailRoleHealCB:Show(); detailRoleHealCB.roleLbl:Show()
    detailRoleDpsCB:SetChecked(roles:sub(3,3) == "1");  detailRoleDpsCB:Show();  detailRoleDpsCB.roleLbl:Show()

    local function OnRoleClick()
        local t = detailRoleTankCB:GetChecked() and "1" or "0"
        local h = detailRoleHealCB:GetChecked() and "1" or "0"
        local d = detailRoleDpsCB:GetChecked() and "1" or "0"
        addon.MI_Guild_SetRoles(name, t .. h .. d)
    end
    detailRoleTankCB:SetScript("OnClick", OnRoleClick)
    detailRoleHealCB:SetScript("OnClick", OnRoleClick)
    detailRoleDpsCB:SetScript("OnClick", OnRoleClick)

    if not group then
        detailNickLabel:Hide(); detailNickBtn:Hide()
        detailStatusLabel:SetText(infoStr .. "|cff555555Not linked|r")
        linkedChild:SetHeight(20)

        detailActionBtn:SetPoint("TOPLEFT", linkedScroll, "BOTTOMLEFT", 0, -6)
        detailActionBtn.lbl:SetText("Set as Main"); StyleGoldButton(detailActionBtn); detailActionBtn:Show()
        detailActionBtn:SetScript("OnClick", function()
            addon.MI_Guild_SetAsMain(name); addon.MI_GuildPanel_Refresh()
        end)

        detailDestructBtn:SetPoint("TOPRIGHT", linkedScroll, "BOTTOMRIGHT", 0, -6)
        detailDestructBtn.lbl:SetText("Link as Alt..."); StyleGoldButton(detailDestructBtn); detailDestructBtn:Show()
        detailDestructBtn:SetScript("OnClick", function()
            ShowInputDialog("Link " .. name .. " as alt of:", function(mn)
                addon.MI_Guild_LinkAltToMain(name, mn); addon.MI_GuildPanel_Refresh()
            end)
        end)
        return
    end

    -- Nick row
    local nick = group.nick
    detailNickLabel:SetText(nick and ("|cff666666Nick:|r " .. nick) or "|cff333333Nick: none|r")
    detailNickLabel:Show()
    detailNickBtn.lbl:SetText(nick and "Edit Nick" or "Set Nick")
    detailNickBtn:SetScript("OnClick", function()
        ShowInputDialog("Nickname for " .. group.main .. ":", function(newNick)
            addon.MI_Guild_SetNick(group.main, newNick); addon.MI_GuildPanel_Refresh()
        end, true, nick or "", true)
    end)
    detailNickBtn:Show()

    if isMain then
        detailStatusLabel:SetText(infoStr .. "|cffffcc00Main|r")
    else
        detailStatusLabel:SetText(infoStr .. "Alt of |cffffcc00" .. group.main .. "|r")
    end

    -- Linked characters
    local members = { group.main }
    for _, a in ipairs(group.alts) do table.insert(members, a) end
    local yOff = 0
    for i, charName in ipairs(members) do
        local row = GetOrCreateLinkedRow(i)
        row:SetPoint("TOPLEFT", linkedChild, "TOPLEFT", 0, -yOff)
        row:SetWidth(linkedChild:GetWidth())
        row.charName = charName
        local isThisMain = (charName == group.main)
        local isCurrent  = (charName == name)
        local cLvl, _, cToken = GetMemberInfo(charName)
        local cColor  = ClassColor(cToken)
        local cLvlStr = cLvl > 0 and ("|cff666666" .. cLvl .. "|r ") or ""
        local mainTag = isThisMain and "|cffffcc00[M]|r " or ""
        row.nameLabel:SetText(mainTag .. cLvlStr .. cColor .. charName .. "|r")
        row.hl:SetColorTexture(0.25, 0.2, 0.05, isCurrent and 0.16 or 0)
        if isThisMain then row.setMainBtn:Hide() else row.setMainBtn:Show() end
        row:Show(); yOff = yOff + ROW_H
    end
    linkedChild:SetHeight(math.max(yOff, 20))

    detailActionBtn:SetPoint("TOPLEFT", linkedScroll, "BOTTOMLEFT", 0, -6)
    detailActionBtn.lbl:SetText("Link Alt..."); StyleGoldButton(detailActionBtn); detailActionBtn:Show()
    detailActionBtn:SetScript("OnClick", function()
        ShowInputDialog("Add alt to " .. group.main .. ":", function(altName)
            addon.MI_Guild_LinkAltToMain(altName, group.main); addon.MI_GuildPanel_Refresh()
        end)
    end)

    detailDestructBtn:SetPoint("TOPRIGHT", linkedScroll, "BOTTOMRIGHT", 0, -6)
    if isMain then
        detailDestructBtn.lbl:SetText("Delete Group"); StyleRedButton(detailDestructBtn)
        detailDestructBtn:SetScript("OnClick", function()
            addon.MI_Guild_DeleteGroup(group.main); selectedName = nil; addon.MI_GuildPanel_Refresh()
        end)
    else
        detailDestructBtn.lbl:SetText("Unlink Me"); StyleRedButton(detailDestructBtn)
        detailDestructBtn:SetScript("OnClick", function()
            addon.MI_Guild_UnlinkChar(name); addon.MI_GuildPanel_Refresh()
        end)
    end
    detailDestructBtn:Show()
end

-- ---------------------------------------------------------------------------------
-- Roster list builder

local function BuildRosterList()
    local filter = filterBox and filterBox:GetText() or ""
    filter = filter:match("^%s*(.-)%s*$")
    rosterEntries = BuildRosterEntries(filter)

    for _, row in ipairs(rosterRows) do
        row:Hide(); row:ClearAllPoints(); row.hl:SetColorTexture(0, 0, 0, 0)
    end

    if not addon.MI_Guild_guildName then
        local row = GetOrCreateRosterRow(1)
        row:SetPoint("TOPLEFT", rosterChild, "TOPLEFT", 0, 0); row:SetWidth(LEFT_W - 20)
        row.nameLabel:SetText("|cff555555Not in a guild.|r"); row.statusLabel:SetText("")
        row.entryName = nil; row.collapseBtn:Hide(); row.inactiveMark:Hide()
        row.roleIconTank:Hide(); row.roleIconHeal:Hide(); row.roleIconDps:Hide()
        row:Show(); rosterChild:SetHeight(ROW_H)
        return
    end

    if #rosterEntries == 0 then
        local row = GetOrCreateRosterRow(1)
        row:SetPoint("TOPLEFT", rosterChild, "TOPLEFT", 0, 0); row:SetWidth(LEFT_W - 20)
        row.nameLabel:SetText("|cff444444No members found.|r"); row.statusLabel:SetText("")
        row.entryName = nil; row.collapseBtn:Hide(); row.inactiveMark:Hide()
        row.roleIconTank:Hide(); row.roleIconHeal:Hide(); row.roleIconDps:Hide()
        row:Show(); rosterChild:SetHeight(ROW_H)
        return
    end

    local yOff = 0
    local rowIdx = 0
    local prevGroupMain = nil

    for _, entry in ipairs(rosterEntries) do
        local groupMain = entry.group and entry.group.main

        -- Skip alts whose main is collapsed (only when name-sorted so groups are contiguous)
        local skip = sortKey == "name" and entry.group and not entry.isMain and collapsedMains[entry.group.main]
        if not skip then
            -- Visual gap between groups
            if groupMain ~= prevGroupMain then
                if rowIdx > 0 then yOff = yOff + 3 end
                prevGroupMain = groupMain
            end

            rowIdx = rowIdx + 1
            local row = GetOrCreateRosterRow(rowIdx)
            row:SetPoint("TOPLEFT", rosterChild, "TOPLEFT", 0, -yOff)
            row:SetWidth(LEFT_W - 20)
            row.entryName = entry.name
            row.mainName  = groupMain

            -- Class color bar
            local cr, cg, cb = ClassColorRGB(entry.classToken)
            row.colorBar:SetColorTexture(cr, cg, cb, 0.7)

            -- Level column
            row.levelLabel:SetText(entry.level > 0 and tostring(entry.level) or "")

            -- Name (indented for alts)
            local cc     = ClassColor(entry.classToken)
            local indent = (entry.group and not entry.isMain) and "  " or ""
            row.nameLabel:SetText(indent .. cc .. entry.name .. "|r")

            -- Collapse toggle (only for mains with alts, only when name-sorted)
            local hasAlts = entry.group and #entry.group.alts > 0
            if sortKey == "name" and entry.isMain and hasAlts then
                row.collapseBtn:Show()
                row.collapseBtn.lbl:SetText(collapsedMains[entry.name] and "[+]" or "[-]")
                row.collapseBtn:SetScript("OnClick", function()
                    collapsedMains[entry.name] = not collapsedMains[entry.name]
                    BuildRosterList()
                end)
            else
                row.collapseBtn:Hide()
            end

            -- Role icons
            local roles = entry.roles or "000"
            if roles:sub(1,1) == "1" then
                row.roleIconTank:SetAtlas("roleicon-tiny-tank", false); row.roleIconTank:Show()
            else row.roleIconTank:Hide() end
            if roles:sub(2,2) == "1" then
                row.roleIconHeal:SetAtlas("roleicon-tiny-healer", false); row.roleIconHeal:Show()
            else row.roleIconHeal:Hide() end
            if roles:sub(3,3) == "1" then
                row.roleIconDps:SetAtlas("roleicon-tiny-dps", false); row.roleIconDps:Show()
            else row.roleIconDps:Hide() end

            -- Inactive mark
            if IsInactive(entry.lastSeen, entry.group) then
                row.inactiveMark:SetText("⚠"); row.inactiveMark:Show()
            else
                row.inactiveMark:Hide()
            end

            -- Status: M for mains with alts, main name for alts, blank for unlinked
            if entry.isMain and hasAlts then
                row.statusLabel:SetText("|cffffcc00M|r")
            elseif not entry.isMain and entry.group then
                local displayMain = (entry.group.nick and entry.group.nick ~= "")
                    and entry.group.nick
                    or (entry.group.main:match("^([^%-]+)") or entry.group.main)
                row.statusLabel:SetText("|cff888888" .. displayMain .. "|r")
            else
                row.statusLabel:SetText("")
            end

            -- Selection highlight
            if entry.name == selectedName then
                row.hl:SetColorTexture(0.28, 0.22, 0.05, 0.25)
            end

            row:Show()
            yOff = yOff + ROW_H
        end
    end
    rosterChild:SetHeight(math.max(yOff, 100))
end

-- ---------------------------------------------------------------------------------
-- Activity log

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


-- ---------------------------------------------------------------------------------
-- Sync popup (new design)

local function RefreshSyncPopup()
    if not syncPopup or not syncPopup:IsShown() then return end

    local peers    = addon.MI_GuildSync_GetPeerStatuses and addon.MI_GuildSync_GetPeerStatuses() or {}
    local isLeader = addon.MI_GuildSync_IsLeader and addon.MI_GuildSync_IsLeader() or false
    local leader   = addon.MI_GuildSync_GetLeader and addon.MI_GuildSync_GetLeader() or nil

    -- Leader line
    if isLeader then
        syncPopupLeaderLbl:SetText("|cff44aa44You are the sync leader|r")
    elseif leader then
        syncPopupLeaderLbl:SetText("Leader: |cffffcc00" .. leader .. "|r")
    else
        syncPopupLeaderLbl:SetText("|cff666666No leader elected|r")
    end

    -- Find min stale modified for Sync All
    local hasStale, minStaleModified = false, math.huge
    for _, p in ipairs(peers) do
        if p.status == "stale" then
            hasStale = true
            if (p.maxModified or 0) < minStaleModified then minStaleModified = p.maxModified or 0 end
        end
    end

    if syncPopupAllBtn then
        if isLeader and hasStale then
            syncPopupAllBtn:Show()
            syncPopupAllBtn:SetScript("OnClick", function()
                addon.MI_GuildSync_BroadcastDelta(minStaleModified, nil)
            end)
        else
            syncPopupAllBtn:Hide()
        end
    end

    local N = #peers
    local ROW_H_P = 20

    for i = 1, N do
        if not syncPopupRows[i] then
            local row = CreateFrame("Frame", nil, syncPopup)
            row:SetHeight(ROW_H_P)

            local sep = row:CreateTexture(nil, "BACKGROUND")
            sep:SetHeight(1); sep:SetPoint("TOPLEFT", 4, 0); sep:SetPoint("TOPRIGHT", -4, 0)
            sep:SetColorTexture(0.22, 0.18, 0.04, 0.3)

            row.nameLbl = MakeLabel(row, FONT, 10)
            row.nameLbl:SetPoint("LEFT", 8, -1)
            row.nameLbl:SetPoint("RIGHT", -82, -1)
            row.nameLbl:SetJustifyH("LEFT")

            row.statusLbl = MakeLabel(row, FONT, 9)
            row.statusLbl:SetPoint("RIGHT", -4, -1)
            row.statusLbl:SetWidth(74)
            row.statusLbl:SetJustifyH("RIGHT")

            local syncBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
            syncBtn:SetSize(58, 15); syncBtn:SetPoint("RIGHT", -4, -1)
            StyleGoldButton(syncBtn)
            local syncLbl = MakeLabel(syncBtn, FONT, 9, GOLD_R, GOLD_G, GOLD_B)
            syncLbl:SetAllPoints(); syncLbl:SetJustifyH("CENTER"); syncLbl:SetText("Sync →")
            row.syncBtn = syncBtn
            syncPopupRows[i] = row
        end

        local row  = syncPopupRows[i]
        local peer = peers[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  syncPopup, "TOPLEFT",  0, -(56 + (i - 1) * ROW_H_P))
        row:SetPoint("TOPRIGHT", syncPopup, "TOPRIGHT", 0, -(56 + (i - 1) * ROW_H_P))

        local rankSuffix = peer.rankName ~= "" and (" |cff777777" .. peer.rankName .. "|r") or ""
        row.nameLbl:SetText(peer.name .. rankSuffix)

        if peer.status == "synced" then
            row.statusLbl:SetText("|cff44aa44✓ Synced|r")
            row.syncBtn:Hide()
        elseif peer.status == "stale" then
            row.statusLbl:SetText("|cffcc8833⚠ Stale|r")
            if isLeader then
                row.syncBtn:Show()
                row.statusLbl:Hide()
                local peerMaxMod = peer.maxModified or 0
                local peerName   = peer.name
                row.syncBtn:SetScript("OnClick", function()
                    addon.MI_GuildSync_BroadcastDelta(peerMaxMod, peerName)
                end)
            else
                row.syncBtn:Hide()
                row.statusLbl:Show()
            end
        else
            row.statusLbl:SetText("|cff666666? Unknown|r")
            row.statusLbl:Show(); row.syncBtn:Hide()
        end

        row:Show()
    end
    for i = N + 1, #syncPopupRows do syncPopupRows[i]:Hide() end

    if N == 0 then syncPopupNoPeers:Show() else syncPopupNoPeers:Hide() end

    local peerH = math.max(N, 1) * ROW_H_P
    local totalH = 56 + peerH + (isLeader and hasStale and 34 or 8)
    syncPopup:SetHeight(totalH)
    if syncPopupAllBtn then
        syncPopupAllBtn:ClearAllPoints()
        syncPopupAllBtn:SetPoint("BOTTOM", syncPopup, "BOTTOM", 0, 8)
    end
end

local function BuildSyncPopup()
    if syncPopup then return end

    syncPopup = CreateFrame("Frame", "MysteriousQoL_SyncPopup", UIParent, "BackdropTemplate")
    syncPopup:SetWidth(300)
    syncPopup:SetPoint("TOPLEFT", panelFrame, "TOPRIGHT", 4, 0)
    syncPopup:SetFrameStrata("HIGH")
    syncPopup:SetFrameLevel(panelFrame:GetFrameLevel() + 5)
    syncPopup:SetBackdrop(MakeBackdrop())
    syncPopup:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    syncPopup:SetBackdropBorderColor(0.45, 0.35, 0.08, 0.8)
    syncPopup:Hide()

    table.insert(UISpecialFrames, "MysteriousQoL_SyncPopup")

    local accent = syncPopup:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(0.75, 0.60, 0.12, 1)

    local titleLbl = MakeLabel(syncPopup, FONT, 11, GOLD_R, GOLD_G, GOLD_B)
    titleLbl:SetPoint("TOPLEFT", 8, -8)
    titleLbl:SetText("Guild Sync")

    local closeBtn = CreateFrame("Button", nil, syncPopup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() syncPopup:Hide() end)

    syncPopupLeaderLbl = MakeLabel(syncPopup, FONT, 10, 0.65, 0.65, 0.65)
    syncPopupLeaderLbl:SetPoint("TOPLEFT", 8, -26)

    local sectionHdr = MakeLabel(syncPopup, FONT, 9, 0.50, 0.42, 0.12)
    sectionHdr:SetPoint("TOPLEFT", 8, -42)
    sectionHdr:SetText("PEERS")

    syncPopupNoPeers = MakeLabel(syncPopup, FONT, 10, 0.4, 0.4, 0.4)
    syncPopupNoPeers:SetPoint("TOPLEFT", 12, -58)
    syncPopupNoPeers:SetText("No peers online")
    syncPopupNoPeers:Hide()

    syncPopupAllBtn = CreateFrame("Button", nil, syncPopup, "BackdropTemplate")
    syncPopupAllBtn:SetSize(130, 22)
    StyleGoldButton(syncPopupAllBtn)
    local allLbl = MakeLabel(syncPopupAllBtn, FONT, 10, GOLD_R, GOLD_G, GOLD_B)
    allLbl:SetAllPoints(); allLbl:SetJustifyH("CENTER"); allLbl:SetText("Sync All Stale")
    syncPopupAllBtn:Hide()
end

-- ---------------------------------------------------------------------------------
-- GRM import popup

local importPopup = nil

local MONTH_NUM = {Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
local DAYS_IN_MONTH = {31,28,31,30,31,30,31,31,30,31,30,31}

local function GRMDateToTimestamp(s)
    local day, mon, yr = s:match("(%d+)%s+(%a+)%s+'(%d+)")
    if not day then return nil end
    local m = MONTH_NUM[mon]; if not m then return nil end
    day, yr = tonumber(day), tonumber(yr) + 2000
    local days = 0
    for y = 1970, yr - 1 do
        days = days + (((y%4==0 and y%100~=0) or y%400==0) and 366 or 365)
    end
    local dim = {table.unpack(DAYS_IN_MONTH)}
    if (yr%4==0 and yr%100~=0) or yr%400==0 then dim[2] = 29 end
    for i = 1, m - 1 do days = days + dim[i] end
    return (days + day - 1) * 86400 + 43200
end

local function ParseGRMLog(text)
    local dates = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local edate, rest = line:match("^%d+%)%s+(%d+%s+%a+%s+'%d+)%s+%d+:%d+[ap]m%s*:%s*(.+)")
        if edate and rest then
            local char, orig
            local reinvited = rest:match("%S+%s+has%s+REINVITED%s+(%S+)%s+to%s+the%s+guild")
            local rejoined  = rest:match("^(%S+)%s+has%s+REJOINED%s+the%s+guild")
            local joined    = rest:match("^(%S+)%s+has%s+JOINED%s+the%s+guild")
            if reinvited or rejoined then
                char = reinvited or rejoined
                orig = line:match("Date Originally Joined:%s+(%d+%s+%a+%s+'%d+)") or edate
            elseif joined then
                char, orig = joined, edate
            end
            if char and orig then
                local ts = GRMDateToTimestamp(orig)
                if ts and (not dates[char] or ts < dates[char]) then dates[char] = ts end
            end
        end
    end
    return dates
end

local function BuildImportPopup()
    if importPopup then return end
    importPopup = CreateFrame("Frame", "MysteriousQoL_ImportPopup", UIParent, "BackdropTemplate")
    importPopup:SetSize(500, 380); importPopup:SetPoint("CENTER")
    importPopup:SetFrameStrata("DIALOG"); importPopup:SetMovable(true); importPopup:EnableMouse(true)
    importPopup:RegisterForDrag("LeftButton")
    importPopup:SetScript("OnDragStart", importPopup.StartMoving)
    importPopup:SetScript("OnDragStop",  importPopup.StopMovingOrSizing)
    importPopup:SetBackdrop(MakeBackdrop())
    importPopup:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    importPopup:SetBackdropBorderColor(0.45, 0.35, 0.08, 0.8)
    importPopup:Hide()

    local title = MakeLabel(importPopup, FONT, 12, GOLD_R, GOLD_G, GOLD_B)
    title:SetPoint("TOPLEFT", 10, -8); title:SetText("Import Join Dates from GRM Log")

    local closeBtn = CreateFrame("Button", nil, importPopup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() importPopup:Hide() end)

    local instr = MakeLabel(importPopup, FONT, 10, 0.7, 0.7, 0.7)
    instr:SetPoint("TOPLEFT", 10, -28); instr:SetWidth(480)
    instr:SetText("Paste your GRM log export below and click Import.")

    local scroll = CreateFrame("ScrollFrame", nil, importPopup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -48); scroll:SetPoint("BOTTOMRIGHT", -30, 50)

    local editBox = CreateFrame("EditBox", nil, scroll, "BackdropTemplate")
    editBox:SetSize(450, 1000); editBox:SetMultiLine(true); editBox:SetAutoFocus(false)
    editBox:SetFont(FONT, 10, ""); editBox:SetTextColor(0.9, 0.9, 0.9, 1)
    editBox:SetBackdrop(MakeBackdrop())
    editBox:SetBackdropColor(0.04, 0.04, 0.04, 1)
    editBox:SetBackdropBorderColor(0.30, 0.24, 0.06, 0.7)
    editBox:SetScript("OnEscapePressed", function() importPopup:Hide() end)
    scroll:SetScrollChild(editBox)

    local statusLbl = MakeLabel(importPopup, FONT, 10, 0.7, 0.7, 0.7)
    statusLbl:SetPoint("BOTTOMLEFT", 10, 16); statusLbl:SetWidth(300); statusLbl:SetText("")

    local importBtn = CreateFrame("Button", nil, importPopup, "BackdropTemplate")
    importBtn:SetSize(88, 22); importBtn:SetPoint("BOTTOMRIGHT", -10, 14)
    StyleGoldButton(importBtn)
    local btnLbl = MakeLabel(importBtn, FONT, 11, GOLD_R, GOLD_G, GOLD_B)
    btnLbl:SetAllPoints(); btnLbl:SetJustifyH("CENTER"); btnLbl:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local text = editBox:GetText()
        if not text or text == "" then statusLbl:SetText("Nothing to import."); return end
        local dates = ParseGRMLog(text)
        local count, total = 0, 0
        for name, ts in pairs(dates) do
            total = total + 1
            local existing = GetCharData(name)
            if not existing or not existing.joinDate or ts < existing.joinDate then
                addon.MI_Guild_SetJoinDate(name, ts)
                count = count + 1
            end
        end
        statusLbl:SetText("Imported " .. count .. " dates from " .. total .. " parsed.")
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    end)
end

-- ---------------------------------------------------------------------------------
-- Main panel construction

local function BuildPanel()
    panelFrame = CreateFrame("Frame", "MysteriousQoL_GuildPanel", UIParent, "BackdropTemplate")
    panelFrame:SetSize(PW, PH); panelFrame:SetPoint("CENTER")
    panelFrame:SetFrameStrata("HIGH"); panelFrame:SetClampedToScreen(true)
    panelFrame:SetMovable(true); panelFrame:EnableMouse(true)
    panelFrame:RegisterForDrag("LeftButton")
    panelFrame:SetScript("OnDragStart", panelFrame.StartMoving)
    panelFrame:SetScript("OnDragStop",  panelFrame.StopMovingOrSizing)
    panelFrame:SetBackdrop(MakeBackdrop())
    panelFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    panelFrame:SetBackdropBorderColor(0.45, 0.35, 0.08, 0.8)
    panelFrame:SetScale(addon.db.guild_panel_scale or 1.0)
    panelFrame:Hide()

    table.insert(UISpecialFrames, "MysteriousQoL_GuildPanel")

    local accent = panelFrame:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(0.75, 0.60, 0.12, 1)

    local title = MakeLabel(panelFrame, FONT, 13, GOLD_R, GOLD_G, GOLD_B)
    title:SetPoint("TOPLEFT", 10, -8); title:SetText("Guild Manager")

    local closeBtn = CreateFrame("Button", nil, panelFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panelFrame:Hide() end)

    local function MakeToolbarButton(label, x, onClick)
        local btn = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
        btn:SetSize(88, 22); btn:SetPoint("TOPLEFT", x, -26)
        StyleGoldButton(btn)
        local lbl = MakeLabel(btn, FONT, 11, GOLD_R, GOLD_G, GOLD_B)
        lbl:SetAllPoints(); lbl:SetJustifyH("CENTER"); lbl:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    MakeToolbarButton("Sync...", 8, function()
        BuildSyncPopup()
        if syncPopup:IsShown() then
            syncPopup:Hide()
        else
            if addon.MI_GuildSync_BroadcastHello then addon.MI_GuildSync_BroadcastHello() end
            RefreshSyncPopup(); syncPopup:Show()
        end
    end)

    MakeToolbarButton("Import...", 100, function()
        BuildImportPopup()
        if importPopup:IsShown() then importPopup:Hide() else importPopup:Show() end
    end)

    -- Filter search box (top right)
    local searchLabel = MakeLabel(panelFrame, FONT, 10, 0.50, 0.42, 0.12)
    searchLabel:SetPoint("TOPRIGHT", -120, -31); searchLabel:SetText("FILTER:")

    filterBox = CreateFrame("EditBox", nil, panelFrame, "BackdropTemplate")
    filterBox:SetSize(106, 20); filterBox:SetPoint("TOPRIGHT", -8, -26)
    filterBox:SetFont(FONT, 11, ""); filterBox:SetTextColor(1, 1, 1, 1); filterBox:SetAutoFocus(false)
    filterBox:SetBackdrop(MakeBackdrop())
    filterBox:SetBackdropColor(0.04, 0.04, 0.04, 1)
    filterBox:SetBackdropBorderColor(0.40, 0.32, 0.08, 0.7)
    filterBox:SetScript("OnTextChanged", function() BuildRosterList(); rosterScroll:SetVerticalScroll(0) end)
    filterBox:SetScript("OnEscapePressed", function() filterBox:SetText(""); filterBox:ClearFocus() end)

    -- Toolbar separator
    local toolSep = panelFrame:CreateTexture(nil, "ARTWORK")
    toolSep:SetHeight(1); toolSep:SetPoint("TOPLEFT", 1, -50); toolSep:SetPoint("TOPRIGHT", -1, -50)
    toolSep:SetColorTexture(0.32, 0.26, 0.06, 0.5)

    local contentTop = -54  -- just below toolbar separator

    -- Radio row: All / Mains / Alts / Unlinked + Online Only
    local function UpdateRosterRadios()
        radioAll:SetChecked(rosterFilter == "all");     radioMains:SetChecked(rosterFilter == "mains")
        radioAlts:SetChecked(rosterFilter == "alts");   radioUnlinked:SetChecked(rosterFilter == "unlinked")
        onlineOnlyBtn:SetChecked(onlineOnly)
    end

    local function MakeRadioOption(label, x)
        local btn = CreateFrame("CheckButton", "MIGuildRadio_" .. label, panelFrame, "UIRadioButtonTemplate")
        btn:SetPoint("TOPLEFT", x, contentTop + 2)
        local lbl = panelFrame:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT, 10, ""); lbl:SetTextColor(0.85, 0.75, 0.45)
        lbl:SetPoint("LEFT", btn, "RIGHT", 2, 0); lbl:SetText(label)
        return btn
    end

    radioAll      = MakeRadioOption("All",      4)
    radioMains    = MakeRadioOption("Mains",    46)
    radioAlts     = MakeRadioOption("Alts",     96)
    radioUnlinked = MakeRadioOption("Unlinked", 140)

    onlineOnlyBtn = CreateFrame("CheckButton", "MIGuildOnlineOnly", panelFrame, "UICheckButtonTemplate")
    onlineOnlyBtn:SetSize(18, 18); onlineOnlyBtn:SetPoint("TOPLEFT", 212, contentTop + 1)
    local onlineLbl = panelFrame:CreateFontString(nil, "OVERLAY")
    onlineLbl:SetFont(FONT, 10, ""); onlineLbl:SetTextColor(0.85, 0.75, 0.45)
    onlineLbl:SetPoint("LEFT", onlineOnlyBtn, "RIGHT", 2, 0); onlineLbl:SetText("Online Only")

    radioAll:SetScript("OnClick", function()
        rosterFilter = "all"; UpdateRosterRadios(); BuildRosterList()
    end)
    radioMains:SetScript("OnClick", function()
        rosterFilter = "mains"; UpdateRosterRadios(); BuildRosterList()
    end)
    radioAlts:SetScript("OnClick", function()
        rosterFilter = "alts"; UpdateRosterRadios(); BuildRosterList()
    end)
    radioUnlinked:SetScript("OnClick", function()
        rosterFilter = "unlinked"; UpdateRosterRadios(); BuildRosterList()
    end)
    onlineOnlyBtn:SetScript("OnClick", function()
        onlineOnly = onlineOnlyBtn:GetChecked(); BuildRosterList()
    end)
    UpdateRosterRadios()

    -- Column headers (clickable, sit directly above roster scroll)
    local hdrY    = contentTop - 22
    local listTop = hdrY - 14

    local colDefs = {
        { key = "level", label = "Lvl",  x = 4,  w = 36, defaultAsc = false },
        { key = "name",  label = "Name", x = 41, w = 88, defaultAsc = true  },
    }

    local function UpdateSortHeaders()
        for _, def in ipairs(colDefs) do
            local btn = sortHeaders[def.key]
            if btn then
                local arrow = (sortKey == def.key) and (sortAsc and " ▲" or " ▼") or ""
                if sortKey == def.key then
                    btn.lbl:SetText("|cffffcc00" .. def.label .. arrow .. "|r")
                else
                    btn.lbl:SetText("|cff555555" .. def.label .. "|r")
                end
            end
        end
    end

    for _, def in ipairs(colDefs) do
        local btn = CreateFrame("Button", nil, panelFrame)
        btn:SetSize(def.w, 14)
        btn:SetPoint("TOPLEFT", def.x, hdrY)
        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT_HDR, 9, "")
        lbl:SetAllPoints()
        lbl:SetJustifyH("LEFT")
        btn.lbl = lbl
        btn:SetScript("OnClick", function()
            if sortKey == def.key then
                sortAsc = not sortAsc
            else
                sortKey = def.key
                sortAsc = def.defaultAsc
            end
            UpdateSortHeaders(); BuildRosterList(); rosterScroll:SetVerticalScroll(0)
        end)
        sortHeaders[def.key] = btn
    end
    UpdateSortHeaders()

    -- Vertical divider
    local detailHdr = MakeLabel(panelFrame, FONT, 9, 0.50, 0.42, 0.12)
    detailHdr:SetPoint("TOPLEFT", LEFT_W + 16, contentTop + 2)
    detailHdr:SetText("SELECTED CHARACTER")

    local divider = panelFrame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT",    LEFT_W + 8, listTop)
    divider:SetPoint("BOTTOMLEFT", LEFT_W + 8, 2)
    divider:SetColorTexture(0.32, 0.26, 0.06, 0.5)

    -- Scale grip
    local grip = CreateFrame("Frame", nil, panelFrame)
    grip:SetSize(14, 14); grip:SetPoint("BOTTOMRIGHT", -2, 2); grip:EnableMouse(true)
    local function MakeDot(x, y)
        local t = grip:CreateTexture(nil, "OVERLAY")
        t:SetSize(3, 3); t:SetPoint("BOTTOMRIGHT", x, y); t:SetColorTexture(0.55, 0.44, 0.10, 0.5)
    end
    MakeDot(-1, 1); MakeDot(-5, 1); MakeDot(-1, 5); MakeDot(-9, 1); MakeDot(-5, 5); MakeDot(-1, 9)
    grip:SetScript("OnEnter", function() for _, t in ipairs({grip:GetRegions()}) do t:SetAlpha(1) end end)
    grip:SetScript("OnLeave", function() for _, t in ipairs({grip:GetRegions()}) do t:SetAlpha(0.5) end end)
    local gripDragging, gripStartX, gripStartScale = false, 0, 1.0
    grip:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        gripDragging = true; gripStartX = GetCursorPosition(); gripStartScale = panelFrame:GetScale()
    end)
    grip:SetScript("OnMouseUp", function() gripDragging = false end)
    grip:SetScript("OnUpdate", function()
        if not gripDragging then return end
        local cx = GetCursorPosition()
        local newScale = math.max(0.6, math.min(1.4, gripStartScale + (cx - gripStartX) / 600))
        local snapped  = math.floor(newScale / 0.05 + 0.5) * 0.05
        addon.db.guild_panel_scale = snapped; panelFrame:SetScale(snapped)
    end)

    -- Left pane: roster scroll
    rosterScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildRosterScroll", panelFrame)
    rosterScroll:SetPoint("TOPLEFT",    4, listTop)
    rosterScroll:SetPoint("BOTTOMLEFT", 4, 2)
    rosterScroll:SetWidth(LEFT_W)
    rosterScroll:EnableMouseWheel(true)
    rosterScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll(); local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_H * 3)))
    end)

    rosterChild = CreateFrame("Frame", nil, rosterScroll)
    rosterChild:SetWidth(LEFT_W - 4); rosterChild:SetHeight(100)
    rosterScroll:SetScrollChild(rosterChild)
    MakeScrollbar(rosterScroll, rosterChild, 16)

    -- Right pane
    local rightX = LEFT_W + 14

    detailNameLabel = MakeLabel(panelFrame, FONT, 13, 1, 1, 1)
    detailNameLabel:SetPoint("TOPLEFT", rightX, listTop)
    detailNameLabel:SetWidth(PW - LEFT_W - 26); detailNameLabel:SetJustifyH("LEFT")
    detailNameLabel:SetText("|cff333333Select a member from the roster|r")

    detailStatusLabel = MakeLabel(panelFrame, FONT, 10, 0.6, 0.6, 0.6)
    detailStatusLabel:SetPoint("TOPLEFT", rightX, listTop - 18)
    detailStatusLabel:SetWidth(PW - LEFT_W - 26); detailStatusLabel:SetJustifyH("LEFT")

    detailNickLabel = MakeLabel(panelFrame, FONT, 9, 0.45, 0.45, 0.45)
    detailNickLabel:SetPoint("TOPLEFT", rightX, listTop - 32)
    detailNickLabel:SetWidth(PW - LEFT_W - 26 - 68); detailNickLabel:SetJustifyH("LEFT")
    detailNickLabel:Hide()

    detailNickBtn = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
    detailNickBtn:SetSize(62, 14); detailNickBtn:SetPoint("TOPRIGHT", -6, listTop - 32)
    StyleGoldButton(detailNickBtn)
    detailNickBtn.lbl = MakeLabel(detailNickBtn, FONT, 8, GOLD_R, GOLD_G, GOLD_B)
    detailNickBtn.lbl:SetAllPoints(); detailNickBtn.lbl:SetJustifyH("CENTER")
    detailNickBtn:Hide()

    detailNoteLabel = MakeLabel(panelFrame, FONT, 9, 0.55, 0.55, 0.55)
    detailNoteLabel:SetPoint("TOPLEFT", rightX, listTop - 46)
    detailNoteLabel:SetWidth(PW - LEFT_W - 26); detailNoteLabel:SetJustifyH("LEFT")

    detailLastSeenLabel = MakeLabel(panelFrame, FONT, 9, 0.45, 0.45, 0.45)
    detailLastSeenLabel:SetPoint("TOPLEFT", rightX, listTop - 66)
    detailLastSeenLabel:SetWidth(PW - LEFT_W - 26); detailLastSeenLabel:SetJustifyH("LEFT")

    -- Join date row with edit button
    detailJoinLabel = MakeLabel(panelFrame, FONT, 9, 0.45, 0.45, 0.45)
    detailJoinLabel:SetPoint("TOPLEFT", rightX, listTop - 80)
    detailJoinLabel:SetWidth(PW - LEFT_W - 26 - 68); detailJoinLabel:SetJustifyH("LEFT")

    detailJoinEditBtn = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
    detailJoinEditBtn:SetSize(62, 14); detailJoinEditBtn:SetPoint("TOPRIGHT", -6, listTop - 80)
    StyleGoldButton(detailJoinEditBtn)
    detailJoinEditBtn.lbl = MakeLabel(detailJoinEditBtn, FONT, 8, GOLD_R, GOLD_G, GOLD_B)
    detailJoinEditBtn.lbl:SetAllPoints(); detailJoinEditBtn.lbl:SetJustifyH("CENTER")
    detailJoinEditBtn.lbl:SetText("Edit Date")
    detailJoinEditBtn:Hide()

    -- Role checkboxes
    detailRolesHdr = MakeLabel(panelFrame, FONT, 9, 0.40, 0.33, 0.10)
    detailRolesHdr:SetPoint("TOPLEFT", rightX, listTop - 96)
    detailRolesHdr:SetText("ROLES:")
    detailRolesHdr:Hide()

    local function MakeRoleCB(parent, label, xOffset)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(16, 16); cb:SetPoint("TOPLEFT", rightX + xOffset, listTop - 96)
        cb:Hide()
        local lbl = parent:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT, 10, ""); lbl:SetTextColor(0.7, 0.7, 0.7, 1)
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0); lbl:SetText(label)
        cb.roleLbl = lbl
        return cb
    end

    detailRoleTankCB = MakeRoleCB(panelFrame, "Tank",   46)
    detailRoleHealCB = MakeRoleCB(panelFrame, "Healer", 104)
    detailRoleDpsCB  = MakeRoleCB(panelFrame, "DPS",    170)

    -- Inactivity warning
    detailInactiveLabel = MakeLabel(panelFrame, FONT_HDR, 10, 1, 0.5, 0, 1)
    detailInactiveLabel:SetPoint("TOPRIGHT", panelFrame, "TOPRIGHT", -6, listTop)
    detailInactiveLabel:SetWidth(80)
    detailInactiveLabel:SetJustifyH("RIGHT")
    detailInactiveLabel:Hide()

    -- Linked characters section
    local linkedHdr = MakeLabel(panelFrame, FONT, 9, 0.50, 0.42, 0.12)
    linkedHdr:SetPoint("TOPLEFT", rightX, listTop - 128)
    linkedHdr:SetText("LINKED CHARACTERS")

    local linkedSep = panelFrame:CreateTexture(nil, "ARTWORK")
    linkedSep:SetHeight(1)
    linkedSep:SetPoint("TOPLEFT",  rightX, listTop - 139)
    linkedSep:SetPoint("TOPRIGHT", -6,     listTop - 139)
    linkedSep:SetColorTexture(0.30, 0.24, 0.06, 0.45)

    linkedScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildLinkedScroll", panelFrame)
    linkedScroll:SetPoint("TOPLEFT", rightX, listTop - 143)
    linkedScroll:SetWidth(PW - LEFT_W - 26)
    linkedScroll:SetHeight(ROW_H * 4)
    linkedScroll:EnableMouseWheel(true)
    linkedScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll(); local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_H * 3)))
    end)

    linkedChild = CreateFrame("Frame", nil, linkedScroll)
    linkedChild:SetWidth(PW - LEFT_W - 36); linkedChild:SetHeight(20)
    linkedScroll:SetScrollChild(linkedChild)
    MakeScrollbar(linkedScroll, linkedChild, 12)

    detailActionBtn = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
    detailActionBtn:SetSize(PW - LEFT_W - 26 - 96 - 8, 20)
    StyleGoldButton(detailActionBtn)
    detailActionBtn.lbl = MakeLabel(detailActionBtn, FONT, 10, GOLD_R, GOLD_G, GOLD_B)
    detailActionBtn.lbl:SetAllPoints(); detailActionBtn.lbl:SetJustifyH("CENTER")
    detailActionBtn:Hide()

    detailDestructBtn = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
    detailDestructBtn:SetSize(90, 20)
    StyleRedButton(detailDestructBtn)
    detailDestructBtn.lbl = MakeLabel(detailDestructBtn, FONT, 10, RED_R, RED_G, RED_B)
    detailDestructBtn.lbl:SetAllPoints(); detailDestructBtn.lbl:SetJustifyH("CENTER")
    detailDestructBtn:Hide()

    -- Log section
    local midSepY = listTop - DETAIL_H

    local midSep = panelFrame:CreateTexture(nil, "ARTWORK")
    midSep:SetHeight(1)
    midSep:SetPoint("TOPLEFT",  rightX - 4, midSepY)
    midSep:SetPoint("TOPRIGHT", -6,         midSepY)
    midSep:SetColorTexture(0.30, 0.24, 0.06, 0.45)

    local logHdr = MakeLabel(panelFrame, FONT, 9, 0.50, 0.42, 0.12)
    logHdr:SetPoint("TOPLEFT", rightX, midSepY - 4); logHdr:SetText("ACTIVITY LOG")

    local logScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildLogScroll", panelFrame)
    logScroll:SetPoint("TOPLEFT",     rightX, midSepY - 18)
    logScroll:SetPoint("BOTTOMRIGHT", -4,     22)
    logScroll:EnableMouseWheel(true)
    logScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll(); local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    logEdit = CreateFrame("EditBox", nil, logScroll)
    logEdit:SetMultiLine(true); logEdit:SetAutoFocus(false)
    logEdit:SetFont(FONT, 10, ""); logEdit:SetTextColor(1, 1, 1, 1)
    logEdit:SetWidth(PW - LEFT_W - 26); logEdit:SetEnabled(false)
    logScroll:SetScrollChild(logEdit)
end

-- ---------------------------------------------------------------------------------
-- Public API

function addon.MI_GuildPanel_Init()
    -- Panel built lazily on first use.
end

function addon.MI_GuildPanel_Toggle()
    if not panelFrame then BuildPanel() end
    if panelFrame:IsShown() then
        panelFrame:Hide()
    else
        C_GuildInfo.GuildRoster()
        addon.MI_GuildPanel_Refresh()
        panelFrame:Show()
    end
end

function addon.MI_GuildPanel_Refresh()
    if not panelFrame then return end
    BuildRosterList()
    addon.MI_GuildPanel_UpdateDetail(selectedName)
    RefreshSyncPopup()
    logEdit:SetText(BuildLogText())
    C_Timer.After(0, function()
        local logScroll = logEdit:GetParent()
        if logScroll and logScroll.SetVerticalScroll then logScroll:SetVerticalScroll(0) end
    end)
end
