local _, addon = ...

local FONT    = "Fonts\\FRIZQT__.TTF"
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]

local PW, PH      = 680, 540
local LEFT_W      = 292   -- roster pane width
local ROW_H       = 18
local DETAIL_H    = 200   -- fixed height of the character-detail block

local panelFrame  = nil

-- Left pane: guild roster
local rosterScroll, rosterChild
local rosterRows    = {}   -- pooled row frames
local rosterEntries = {}   -- current displayed data
local selectedName  = nil
local filterBox     = nil

-- Right pane top: selected-character detail
local detailNameLabel, detailStatusLabel, detailNoteLabel, detailJoinLabel
local linkedScroll, linkedChild
local linkedRows = {}      -- pooled rows for linked-character list
local detailBtn1, detailBtn2
local detailNickLabel, detailNickBtn

-- Right pane bottom: activity log
local logEdit

-- Filter state
local rosterFilter  = "all"  -- "all", "mains", "alts", "unlinked"
local onlineOnly    = false
local radioAll, radioMains, radioAlts, radioUnlinked, onlineOnlyBtn
local statsLabel    = nil

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function ClassColor(classToken)
    local c = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
    if c then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
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

local function BuildStatsText()
    local numTotal, _, numAccounts = GetNumGuildMembers()
    numTotal = numTotal or 0
    local groups = addon.MI_Guild_GetAllGroups()
    local numMains = #groups
    local numAlts = 0
    for _, group in ipairs(groups) do numAlts = numAlts + #group.alts end
    local s = "|cff777777Members:|r " .. numTotal
    if numAccounts and numAccounts > 0 then
        s = s .. "   |cff777777Accounts:|r " .. numAccounts
    end
    s = s .. "   |cff777777Tracked Mains:|r " .. numMains .. "   |cff777777Tracked Alts:|r " .. numAlts
    return s
end

local function MakeBackdrop()
    return {
        bgFile = BAR_TEX, edgeFile = BAR_TEX, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    }
end

local function StyleButton(btn, r, g, b)
    btn:SetBackdrop(MakeBackdrop())
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
    btn:SetBackdropBorderColor(r, g, b, 0.7)
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(r, g, b, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(r, g, b, 0.7) end)
end

local function MakeLabel(parent, font, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or FONT, size or 11, "")
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    return fs
end

-- ── Input dialog with autocomplete ────────────────────────────────────────────

local inputDialog, inputCallback
local inputNoAC = false
local inputAllowEmpty = false
local acFrame, acRows, suppressAC = nil, {}, false
local MAX_AC = 8
local AC_ROW_H = 20
local DIALOG_BASE_H = 88

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
    if #results > MAX_AC then
        local t = {}
        for i = 1, MAX_AC do t[i] = results[i] end
        return t
    end
    return results
end

local function HideAutocomplete()
    if acFrame then acFrame:Hide() end
    for _, r in ipairs(acRows) do r:Hide() end
    if inputDialog then inputDialog:SetHeight(DIALOG_BASE_H) end
end

local function UpdateAutocomplete(text)
    if inputNoAC then return end
    if not acFrame then return end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then HideAutocomplete(); return end
    local results = GetGuildMemberMatches(text)
    if #results == 0 then HideAutocomplete(); return end
    for i = 1, #results do
        if not acRows[i] then
            local row = CreateFrame("Button", nil, acFrame)
            row:SetHeight(AC_ROW_H)
            row:SetPoint("LEFT", 0, 0); row:SetPoint("RIGHT", 0, 0)
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0); row.bg = bg
            row.nl = MakeLabel(row, FONT, 11)
            row.nl:SetPoint("LEFT", 8, 0); row.nl:SetPoint("RIGHT", -60, 0)
            row.nl:SetJustifyH("LEFT")
            row.rl = MakeLabel(row, FONT, 9, 0.45, 0.45, 0.45)
            row.rl:SetPoint("RIGHT", -4, 0); row.rl:SetJustifyH("RIGHT")
            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.22, 0.18, 0.04, 0.35)
                self.nl:SetTextColor(1, 0.88, 0.3, 1)
            end)
            row:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0, 0, 0, 0)
                self.nl:SetTextColor(1, 1, 1, 1)
            end)
            row:SetScript("OnClick", function(self)
                suppressAC = true
                inputDialog.editBox:SetText(self.memberName)
                suppressAC = false
                HideAutocomplete()
                inputDialog.editBox:SetCursorPosition(#self.memberName)
            end)
            acRows[i] = row
        end
    end
    for i, data in ipairs(results) do
        local row = acRows[i]
        row:SetPoint("TOPLEFT", acFrame, "TOPLEFT", 0, -(i - 1) * AC_ROW_H)
        row.memberName = data.name
        row.nl:SetText(data.name); row.rl:SetText(data.rank); row:Show()
    end
    for i = #results + 1, #acRows do acRows[i]:Hide() end
    local h = #results * AC_ROW_H
    acFrame:SetHeight(h); acFrame:Show()
    inputDialog:SetHeight(DIALOG_BASE_H + h + 2)
end

local function BuildInputDialog()
    if inputDialog then return end
    local parent = panelFrame or UIParent
    inputDialog = CreateFrame("Frame", "MysteriousQoL_GuildInput", parent, "BackdropTemplate")
    inputDialog:SetSize(270, DIALOG_BASE_H)
    inputDialog:SetPoint("CENTER")
    inputDialog:SetFrameLevel(parent:GetFrameLevel() + 20)
    inputDialog:SetBackdrop(MakeBackdrop())
    inputDialog:SetBackdropColor(0.07, 0.07, 0.07, 0.98)
    inputDialog:SetBackdropBorderColor(0.55, 0.44, 0.12, 1)
    inputDialog:Hide()

    inputDialog.titleText = MakeLabel(inputDialog, FONT, 11, 0.9, 0.76, 0.22)
    inputDialog.titleText:SetPoint("TOPLEFT", 8, -8)

    local eb = CreateFrame("EditBox", nil, inputDialog, "BackdropTemplate")
    eb:SetSize(250, 22); eb:SetPoint("TOP", 0, -28)
    eb:SetFont(FONT, 11, ""); eb:SetTextColor(1, 1, 1, 1); eb:SetAutoFocus(true)
    eb:SetBackdrop(MakeBackdrop())
    eb:SetBackdropColor(0.04, 0.04, 0.04, 1)
    eb:SetBackdropBorderColor(0.40, 0.32, 0.08, 0.8)
    eb:SetScript("OnTextChanged", function()
        if suppressAC then return end
        UpdateAutocomplete(eb:GetText())
    end)
    eb:SetScript("OnEnterPressed", function()
        local t = eb:GetText():match("^%s*(.-)%s*$")
        inputDialog:Hide()
        if (t ~= "" or inputAllowEmpty) and inputCallback then inputCallback(t) end
    end)
    eb:SetScript("OnEscapePressed", function() inputDialog:Hide() end)
    inputDialog.editBox = eb

    acFrame = CreateFrame("Frame", nil, inputDialog, "BackdropTemplate")
    acFrame:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, -2)
    acFrame:SetPoint("TOPRIGHT", eb, "BOTTOMRIGHT", 0, -2)
    acFrame:SetHeight(0)
    acFrame:SetFrameLevel(inputDialog:GetFrameLevel() + 5)
    acFrame:SetBackdrop(MakeBackdrop())
    acFrame:SetBackdropColor(0.08, 0.07, 0.03, 0.97)
    acFrame:SetBackdropBorderColor(0.35, 0.28, 0.07, 0.6)
    acFrame:Hide()

    local okBtn = CreateFrame("Button", nil, inputDialog, "BackdropTemplate")
    okBtn:SetSize(70, 20); okBtn:SetPoint("BOTTOMLEFT", 8, 8)
    StyleButton(okBtn, 0.50, 0.40, 0.09)
    local okL = MakeLabel(okBtn, FONT, 10, 0.9, 0.76, 0.22)
    okL:SetAllPoints(); okL:SetJustifyH("CENTER"); okL:SetText("OK")
    okBtn:SetScript("OnClick", function()
        local t = eb:GetText():match("^%s*(.-)%s*$")
        inputDialog:Hide()
        if (t ~= "" or inputAllowEmpty) and inputCallback then inputCallback(t) end
    end)

    local cancelBtn = CreateFrame("Button", nil, inputDialog, "BackdropTemplate")
    cancelBtn:SetSize(70, 20); cancelBtn:SetPoint("BOTTOMRIGHT", -8, 8)
    StyleButton(cancelBtn, 0.5, 0.1, 0.1)
    local cL = MakeLabel(cancelBtn, FONT, 10, 1, 0.4, 0.4)
    cL:SetAllPoints(); cL:SetJustifyH("CENTER"); cL:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() inputDialog:Hide() end)
end

local function ShowInputDialog(title, callback, noAC, prefill, allowEmpty)
    BuildInputDialog()
    inputDialog.titleText:SetText(title)
    inputNoAC = noAC and true or false
    inputAllowEmpty = allowEmpty and true or false
    suppressAC = true; inputDialog.editBox:SetText(prefill or ""); suppressAC = false
    if prefill and prefill ~= "" then inputDialog.editBox:SetCursorPosition(#prefill) end
    HideAutocomplete()
    inputCallback = callback
    if not noAC then C_GuildInfo.GuildRoster() end
    inputDialog:Show()
    inputDialog.editBox:SetFocus()
end

-- ── Roster data helpers ────────────────────────────────────────────────────────

local function BuildRosterEntries(filter)
    local entries = {}
    filter = filter and filter:lower() or ""
    for i = 1, GetNumGuildMembers() do
        local name, rankName, rankIndex, level, _, _, _, _, isOnline, _, classToken = GetGuildRosterInfo(i)
        if name then
            local groupIdx, group, isMain = addon.MI_Guild_GetGroupForChar(name)
            local lf = filter ~= "" and filter or nil
            local matches = not lf
                or name:lower():find(lf, 1, true)
                or (group and group.main:lower():find(lf, 1, true))
                or (group and group.nick and group.nick:lower():find(lf, 1, true))
            if matches
                and (rosterFilter == "all"
                     or (rosterFilter == "mains"    and group and isMain)
                     or (rosterFilter == "alts"     and group and not isMain)
                     or (rosterFilter == "unlinked" and not group))
                and (not onlineOnly or isOnline)
            then
                table.insert(entries, {
                    name       = name,
                    rank       = rankName or "",
                    rankIdx    = rankIndex or 0,
                    groupIdx   = groupIdx,
                    group      = group,
                    isMain     = isMain,
                    level      = level or 0,
                    classToken = classToken or "",
                })
            end
        end
    end
    table.sort(entries, function(a, b)
        local aKey = a.group and (a.group.main .. "\001" .. (a.isMain and "\000" or a.name)) or a.name
        local bKey = b.group and (b.group.main .. "\001" .. (b.isMain and "\000" or b.name)) or b.name
        return aKey < bKey
    end)
    return entries
end

local function StatusText(entry)
    if entry.isMain then
        local n = entry.group and #entry.group.alts or 0
        local alts = n > 0 and (" |cff444444(" .. n .. ")|r") or ""
        return "|cffffcc00Main|r" .. alts
    elseif entry.group then
        return "|cff555555" .. (entry.group.nick or entry.group.main) .. "|r"
    else
        return "|cff2a2a2a-|r"
    end
end

-- ── Right-click context menu ───────────────────────────────────────────────────

local function ShowRosterContextMenu(charName)
    local groupIdx, group = addon.MI_Guild_GetGroupForChar(charName)
    MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
        rootDescription:CreateTitle(charName)
        rootDescription:CreateButton("Set as Main", function()
            addon.MI_Guild_SetAsMain(charName)
            addon.MI_GuildPanel_Refresh()
        end)
        rootDescription:CreateButton("Link as Alt to...", function()
            ShowInputDialog("Link " .. charName .. " as alt of:", function(mainName)
                if mainName and mainName ~= "" then
                    addon.MI_Guild_LinkAltToMain(charName, mainName)
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

-- ── Roster row pool ────────────────────────────────────────────────────────────

local function GetOrCreateRosterRow(i)
    if rosterRows[i] then return rosterRows[i] end
    local row = CreateFrame("Frame", nil, rosterChild)
    row:SetHeight(ROW_H)

    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(); hl:SetColorTexture(0.25, 0.2, 0.05, 0); row.hl = hl

    row.nameLabel = MakeLabel(row, FONT, 11)
    row.nameLabel:SetPoint("LEFT", 6, 0)
    row.nameLabel:SetWidth(LEFT_W - 108)
    row.nameLabel:SetJustifyH("LEFT")

    row.statusLabel = MakeLabel(row, FONT, 10)
    row.statusLabel:SetPoint("RIGHT", -6, 0)
    row.statusLabel:SetWidth(96)
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
        if btn == "RightButton" then
            ShowRosterContextMenu(self.entryName)
            return
        end
        selectedName = self.entryName
        for _, r in ipairs(rosterRows) do
            r.hl:SetColorTexture(0, 0, 0, 0)
        end
        self.hl:SetColorTexture(0.28, 0.22, 0.05, 0.25)
        addon.MI_GuildPanel_UpdateDetail(selectedName)
    end)

    rosterRows[i] = row
    return row
end

-- ── Linked-character row pool (inside detail pane) ────────────────────────────

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
    StyleButton(row.setMainBtn, 0.50, 0.40, 0.09)
    local smL = MakeLabel(row.setMainBtn, FONT, 9, 0.9, 0.76, 0.22)
    smL:SetAllPoints(); smL:SetJustifyH("CENTER"); smL:SetText("Set Main")
    row.setMainBtn:SetScript("OnClick", function()
        if not row.charName then return end
        addon.MI_Guild_SetAsMain(row.charName)
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    end)

    linkedRows[i] = row
    return row
end

local function GetOldestJoinDate(chars)
    local guildName = addon.MI_Guild_guildName
    if not guildName then return nil end
    local data = MysteriousQoLDB.guildData and MysteriousQoLDB.guildData[guildName]
    if not data or not data.members then return nil end
    local oldest = nil
    for _, charName in ipairs(chars) do
        local m = data.members[charName]
        if m and m.joinDate and (not oldest or m.joinDate < oldest) then
            oldest = m.joinDate
        end
    end
    return oldest
end

-- ── Detail pane update ────────────────────────────────────────────────────────

function addon.MI_GuildPanel_UpdateDetail(name)
    for _, row in ipairs(linkedRows) do row:Hide(); row:ClearAllPoints() end
    detailBtn1:Hide(); detailBtn2:Hide()
    detailBtn1:SetScript("OnClick", nil)
    detailBtn2:SetScript("OnClick", nil)

    if not name then
        detailNameLabel:SetText("|cff333333Select a member from the roster|r")
        detailStatusLabel:SetText("")
        detailNoteLabel:SetText("")
        detailJoinLabel:SetText("")
        detailNickLabel:Hide()
        detailNickBtn:Hide()
        linkedChild:SetHeight(20)
        return
    end

    local groupIdx, group, isMain = addon.MI_Guild_GetGroupForChar(name)
    local level, classDisplay, classToken, publicNote, officerNote = GetMemberInfo(name)
    local cc = ClassColor(classToken)
    local infoStr = (level > 0 and classDisplay ~= "") and
        ("|cff888888" .. level .. " " .. classDisplay .. "|r  ") or ""

    detailNameLabel:SetText(cc .. name .. "|r")

    -- Notes
    local noteLines = {}
    if publicNote ~= "" then
        table.insert(noteLines, "|cff888888Note:|r " .. publicNote)
    end
    if officerNote ~= "" then
        table.insert(noteLines, "|cff666666Officer:|r " .. officerNote)
    end
    detailNoteLabel:SetText(table.concat(noteLines, "\n"))

    -- Join date: show oldest across the whole linked group (or solo if unlinked)
    do
        local chars = group and (function()
            local t = { group.main }
            for _, a in ipairs(group.alts) do table.insert(t, a) end
            return t
        end)() or { name }
        local ts = GetOldestJoinDate(chars)
        if ts then
            detailJoinLabel:SetText("|cff666666Joined:|r " .. date("%b %d, %Y", ts))
        else
            detailJoinLabel:SetText("")
        end
    end

    if not group then
        detailNickLabel:Hide()
        detailNickBtn:Hide()
        detailStatusLabel:SetText(infoStr .. "|cff555555Not linked|r")
        linkedChild:SetHeight(20)

        detailBtn1:SetPoint("TOPLEFT", linkedScroll, "BOTTOMLEFT", 0, -6)
        detailBtn1.lbl:SetText("Set as Main")
        StyleButton(detailBtn1, 0.50, 0.40, 0.09)
        detailBtn1:Show()
        detailBtn1:SetScript("OnClick", function()
            addon.MI_Guild_SetAsMain(name)
            addon.MI_GuildPanel_Refresh()
        end)

        detailBtn2:SetPoint("TOPRIGHT", linkedScroll, "BOTTOMRIGHT", 0, -6)
        detailBtn2.lbl:SetText("Link as Alt...")
        StyleButton(detailBtn2, 0.50, 0.40, 0.09)
        detailBtn2:Show()
        detailBtn2:SetScript("OnClick", function()
            ShowInputDialog("Link " .. name .. " as alt of:", function(mainName)
                addon.MI_Guild_LinkAltToMain(name, mainName)
                addon.MI_GuildPanel_Refresh()
            end)
        end)
        return
    end

    -- Nick row
    do
        local nick = group.nick
        detailNickLabel:SetText(nick and ("|cff666666Nick:|r " .. nick) or "|cff333333Nick:|r |cff333333none|r")
        detailNickLabel:Show()
        detailNickBtn.lbl:SetText(nick and "Edit Nick" or "Set Nick")
        detailNickBtn:SetScript("OnClick", function()
            ShowInputDialog("Nickname for " .. group.main .. ":", function(newNick)
                addon.MI_Guild_SetNick(groupIdx, newNick)
                addon.MI_GuildPanel_Refresh()
            end, true, nick or "", true)
        end)
        detailNickBtn:Show()
    end

    if isMain then
        local n = #group.alts
        detailStatusLabel:SetText(infoStr .. "|cffffcc00Main|r" .. (n > 0 and (" - " .. n .. " alt" .. (n == 1 and "" or "s")) or ""))
    else
        detailStatusLabel:SetText(infoStr .. "Alt of |cffffcc00" .. group.main .. "|r")
    end

    -- Build linked character list: main first, then alts
    local members = { group.main }
    for _, a in ipairs(group.alts) do table.insert(members, a) end

    local yOff = 0
    for i, charName in ipairs(members) do
        local row = GetOrCreateLinkedRow(i)
        row:SetPoint("TOPLEFT", linkedChild, "TOPLEFT", 0, -yOff)
        row:SetWidth(linkedChild:GetWidth())
        row.charName = charName
        local isMn = (charName == group.main)
        local isCurrent = (charName == name)

        local cLvl, _, cToken = GetMemberInfo(charName)
        local cColor = ClassColor(cToken)
        local cLvlStr = cLvl > 0 and ("|cff666666" .. cLvl .. "|r ") or ""
        local mainTag = isMn and "|cffffcc00[M]|r " or ""
        row.nameLabel:SetText(mainTag .. cLvlStr .. cColor .. charName .. "|r")
        row.hl:SetColorTexture(0.25, 0.2, 0.05, isCurrent and 0.16 or 0)

        if isMn then
            row.setMainBtn:Hide()
        else
            row.setMainBtn:Show()
        end
        row:Show()
        yOff = yOff + ROW_H
    end
    linkedChild:SetHeight(math.max(yOff, 20))

    detailBtn1:SetPoint("TOPLEFT", linkedScroll, "BOTTOMLEFT", 0, -6)
    detailBtn1.lbl:SetText("Link Alt...")
    StyleButton(detailBtn1, 0.50, 0.40, 0.09)
    detailBtn1:Show()
    detailBtn1:SetScript("OnClick", function()
        ShowInputDialog("Add alt to " .. group.main .. ":", function(altName)
            addon.MI_Guild_LinkAltToMain(altName, group.main)
            addon.MI_GuildPanel_Refresh()
        end)
    end)

    detailBtn2:SetPoint("TOPRIGHT", linkedScroll, "BOTTOMRIGHT", 0, -6)
    if isMain then
        detailBtn2.lbl:SetText("Delete Group")
        StyleButton(detailBtn2, 0.55, 0.1, 0.1)
        detailBtn2:SetScript("OnClick", function()
            addon.MI_Guild_DeleteGroup(groupIdx)
            selectedName = nil
            addon.MI_GuildPanel_Refresh()
        end)
    else
        detailBtn2.lbl:SetText("Unlink Me")
        StyleButton(detailBtn2, 0.55, 0.1, 0.1)
        detailBtn2:SetScript("OnClick", function()
            addon.MI_Guild_UnlinkChar(name)
            addon.MI_GuildPanel_Refresh()
        end)
    end
    detailBtn2:Show()
end

-- ── Roster list builder ────────────────────────────────────────────────────────

local function BuildRosterList()
    local filter = filterBox and filterBox:GetText() or ""
    filter = filter:match("^%s*(.-)%s*$")
    rosterEntries = BuildRosterEntries(filter)

    for _, row in ipairs(rosterRows) do row:Hide(); row:ClearAllPoints(); row.hl:SetColorTexture(0, 0, 0, 0) end

    if not addon.MI_Guild_guildName then
        local row = GetOrCreateRosterRow(1)
        row:SetPoint("TOPLEFT", rosterChild, "TOPLEFT", 0, 0)
        row:SetWidth(LEFT_W - 20)
        row.nameLabel:SetText("|cff555555Not in a guild.|r")
        row.statusLabel:SetText("")
        row.entryName = nil
        row.hl:SetColorTexture(0, 0, 0, 0)
        row:Show()
        rosterChild:SetHeight(ROW_H)
        return
    end

    if #rosterEntries == 0 then
        local row = GetOrCreateRosterRow(1)
        row:SetPoint("TOPLEFT", rosterChild, "TOPLEFT", 0, 0)
        row:SetWidth(LEFT_W - 20)
        row.nameLabel:SetText("|cff444444No members found.|r")
        row.statusLabel:SetText("")
        row.entryName = nil
        row.hl:SetColorTexture(0, 0, 0, 0)
        row:Show()
        rosterChild:SetHeight(ROW_H)
        return
    end

    local prevGroupMain = "@@NONE@@"
    local yOff = 0
    for i, entry in ipairs(rosterEntries) do
        local groupMain = entry.group and entry.group.main
        if groupMain ~= prevGroupMain then
            if i > 1 then yOff = yOff + 3 end
            prevGroupMain = groupMain
        end

        local row = GetOrCreateRosterRow(i)
        row:SetPoint("TOPLEFT", rosterChild, "TOPLEFT", 0, -yOff)
        row:SetWidth(LEFT_W - 20)
        row.entryName = entry.name

        local cc = ClassColor(entry.classToken)
        local lvl = entry.level > 0 and ("|cff666666" .. entry.level .. "|r ") or ""
        if entry.group and not entry.isMain then
            row.nameLabel:SetText("  " .. lvl .. cc .. entry.name .. "|r")
        else
            row.nameLabel:SetText(lvl .. cc .. entry.name .. "|r")
        end
        row.statusLabel:SetText(StatusText(entry))

        if entry.name == selectedName then
            row.hl:SetColorTexture(0.28, 0.22, 0.05, 0.25)
        end
        row:Show()
        yOff = yOff + ROW_H
    end
    rosterChild:SetHeight(math.max(yOff, 100))
end

-- ── Log builder ───────────────────────────────────────────────────────────────

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
        local e = entries[i]
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

-- ── Panel builder ─────────────────────────────────────────────────────────────

local function BuildPanel()
    panelFrame = CreateFrame("Frame", "MysteriousQoL_GuildPanel", UIParent, "BackdropTemplate")
    panelFrame:SetSize(PW, PH)
    panelFrame:SetPoint("CENTER")
    panelFrame:SetFrameStrata("HIGH")
    panelFrame:SetClampedToScreen(true)
    panelFrame:SetMovable(true)
    panelFrame:EnableMouse(true)
    panelFrame:RegisterForDrag("LeftButton")
    panelFrame:SetScript("OnDragStart", panelFrame.StartMoving)
    panelFrame:SetScript("OnDragStop", panelFrame.StopMovingOrSizing)
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

    local title = MakeLabel(panelFrame, FONT, 13, 0.9, 0.76, 0.22)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Guild Manager")

    local closeBtn = CreateFrame("Button", nil, panelFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panelFrame:Hide() end)

    -- ── Toolbar ──────────────────────────────────────────────────────────────

    local function MakeToolbarButton(label, x, onClick)
        local btn = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
        btn:SetSize(88, 22)
        btn:SetPoint("TOPLEFT", x, -26)
        StyleButton(btn, 0.50, 0.40, 0.09)
        local lbl = MakeLabel(btn, FONT, 11, 0.9, 0.76, 0.22)
        lbl:SetAllPoints(); lbl:SetJustifyH("CENTER"); lbl:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    MakeToolbarButton("Sync Now", 8, function()
        addon.MI_GuildSync_Broadcast()
    end)


    -- Search / filter box
    local searchLabel = MakeLabel(panelFrame, FONT, 10, 0.50, 0.42, 0.12)
    searchLabel:SetPoint("TOPRIGHT", -120, -31)
    searchLabel:SetText("FILTER:")

    filterBox = CreateFrame("EditBox", nil, panelFrame, "BackdropTemplate")
    filterBox:SetSize(106, 20)
    filterBox:SetPoint("TOPRIGHT", -8, -26)
    filterBox:SetFont(FONT, 11, "")
    filterBox:SetTextColor(1, 1, 1, 1)
    filterBox:SetAutoFocus(false)
    filterBox:SetBackdrop(MakeBackdrop())
    filterBox:SetBackdropColor(0.04, 0.04, 0.04, 1)
    filterBox:SetBackdropBorderColor(0.40, 0.32, 0.08, 0.7)
    filterBox:SetScript("OnTextChanged", function()
        BuildRosterList()
        rosterScroll:SetVerticalScroll(0)
    end)
    filterBox:SetScript("OnEscapePressed", function()
        filterBox:SetText(""); filterBox:ClearFocus()
    end)

    local toolSep = panelFrame:CreateTexture(nil, "ARTWORK")
    toolSep:SetHeight(1)
    toolSep:SetPoint("TOPLEFT", 1, -50)
    toolSep:SetPoint("TOPRIGHT", -1, -50)
    toolSep:SetColorTexture(0.32, 0.26, 0.06, 0.5)

    -- ── Content area ──────────────────────────────────────────────────────────

    local contentTop = -54  -- Y from panel top

    -- Radio row: All / Mains / Alts / Unlinked (mutually exclusive) + Online Only checkbox
    local function UpdateRosterRadios()
        radioAll:SetChecked(rosterFilter == "all")
        radioMains:SetChecked(rosterFilter == "mains")
        radioAlts:SetChecked(rosterFilter == "alts")
        radioUnlinked:SetChecked(rosterFilter == "unlinked")
        onlineOnlyBtn:SetChecked(onlineOnly)
    end

    local function MakeRadioOption(label, x)
        local btn = CreateFrame("CheckButton", "MIGuildRadio_"..label, panelFrame, "UIRadioButtonTemplate")
        btn:SetPoint("TOPLEFT", x, contentTop + 2)
        local lbl = panelFrame:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT, 10, "")
        lbl:SetTextColor(0.85, 0.75, 0.45)
        lbl:SetPoint("LEFT", btn, "RIGHT", 2, 0)
        lbl:SetText(label)
        btn.myLabel = lbl
        return btn
    end

    radioAll      = MakeRadioOption("All",      4)
    radioMains    = MakeRadioOption("Mains",    46)
    radioAlts     = MakeRadioOption("Alts",     96)
    radioUnlinked = MakeRadioOption("Unlinked", 140)

    onlineOnlyBtn = CreateFrame("CheckButton", "MIGuildOnlineOnly", panelFrame, "UICheckButtonTemplate")
    onlineOnlyBtn:SetSize(18, 18)
    onlineOnlyBtn:SetPoint("TOPLEFT", 212, contentTop + 1)
    local onlineLbl = panelFrame:CreateFontString(nil, "OVERLAY")
    onlineLbl:SetFont(FONT, 10, "")
    onlineLbl:SetTextColor(0.85, 0.75, 0.45)
    onlineLbl:SetPoint("LEFT", onlineOnlyBtn, "RIGHT", 2, 0)
    onlineLbl:SetText("Online Only")

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

    local detailHdr = MakeLabel(panelFrame, FONT, 9, 0.50, 0.42, 0.12)
    detailHdr:SetPoint("TOPLEFT", LEFT_W + 16, contentTop + 2)
    detailHdr:SetText("SELECTED CHARACTER")

    local listTop = contentTop - 22

    -- Vertical divider
    local divider = panelFrame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", LEFT_W + 8, listTop)
    divider:SetPoint("BOTTOMLEFT", LEFT_W + 8, 22)
    divider:SetColorTexture(0.32, 0.26, 0.06, 0.5)

    -- Stats bar
    local statsSep = panelFrame:CreateTexture(nil, "ARTWORK")
    statsSep:SetHeight(1)
    statsSep:SetPoint("BOTTOMLEFT", 1, 20)
    statsSep:SetPoint("BOTTOMRIGHT", -1, 20)
    statsSep:SetColorTexture(0.28, 0.22, 0.05, 0.4)

    statsLabel = MakeLabel(panelFrame, FONT, 9, 0.5, 0.5, 0.5)
    statsLabel:SetPoint("BOTTOMLEFT", 8, 6)
    statsLabel:SetPoint("BOTTOMRIGHT", -8, 6)
    statsLabel:SetJustifyH("LEFT")

    -- Resize grip (bottom-right corner)
    local grip = CreateFrame("Frame", nil, panelFrame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:EnableMouse(true)
    local function MakeDot(x, y)
        local t = grip:CreateTexture(nil, "OVERLAY")
        t:SetSize(3, 3); t:SetPoint("BOTTOMRIGHT", x, y)
        t:SetColorTexture(0.55, 0.44, 0.10, 0.5)
    end
    MakeDot(-1, 1); MakeDot(-5, 1); MakeDot(-1, 5)
    MakeDot(-9, 1); MakeDot(-5, 5); MakeDot(-1, 9)
    grip:SetScript("OnEnter", function()
        for _, tex in ipairs({grip:GetRegions()}) do tex:SetAlpha(1) end
    end)
    grip:SetScript("OnLeave", function()
        for _, tex in ipairs({grip:GetRegions()}) do tex:SetAlpha(0.5) end
    end)
    local gripDragging, gripStartX, gripStartScale = false, 0, 1.0
    grip:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        gripDragging = true
        gripStartX = select(1, GetCursorPosition())
        gripStartScale = panelFrame:GetScale()
    end)
    grip:SetScript("OnMouseUp", function() gripDragging = false end)
    grip:SetScript("OnUpdate", function()
        if not gripDragging then return end
        local cx = select(1, GetCursorPosition())
        local newScale = math.max(0.6, math.min(1.4, gripStartScale + (cx - gripStartX) / 600))
        local snapped = math.floor(newScale / 0.05 + 0.5) * 0.05
        addon.db.guild_panel_scale = snapped
        panelFrame:SetScale(snapped)
    end)

    -- ── Left pane: roster scroll ──────────────────────────────────────────────

    rosterScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildRosterScroll", panelFrame)
    rosterScroll:SetPoint("TOPLEFT", 4, listTop)
    rosterScroll:SetPoint("BOTTOMLEFT", 4, 22)
    rosterScroll:SetWidth(LEFT_W)
    rosterScroll:EnableMouseWheel(true)
    rosterScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_H * 3)))
    end)

    rosterChild = CreateFrame("Frame", nil, rosterScroll)
    rosterChild:SetWidth(LEFT_W - 4)
    rosterChild:SetHeight(100)
    rosterScroll:SetScrollChild(rosterChild)

    -- Minimal scrollbar
    local sbTrack = CreateFrame("Frame", nil, panelFrame)
    sbTrack:SetWidth(5)
    sbTrack:SetPoint("TOPLEFT", rosterScroll, "TOPRIGHT", 1, 0)
    sbTrack:SetPoint("BOTTOMLEFT", rosterScroll, "BOTTOMRIGHT", 1, 0)
    local sbBg = sbTrack:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints(); sbBg:SetColorTexture(0.12, 0.10, 0.03, 0.35)
    local sbThumb = sbTrack:CreateTexture(nil, "OVERLAY")
    sbThumb:SetWidth(4); sbThumb:SetColorTexture(0.55, 0.44, 0.10, 0.75); sbThumb:Hide()
    local function UpdateRosterScrollbar()
        local childH = rosterChild:GetHeight()
        local viewH  = rosterScroll:GetHeight()
        if childH <= viewH then sbThumb:Hide(); return end
        sbThumb:Show()
        local trackH = sbTrack:GetHeight()
        if trackH <= 0 then return end
        local thumbH = math.max(16, trackH * viewH / childH)
        sbThumb:SetHeight(thumbH)
        local maxScroll = rosterScroll:GetVerticalScrollRange()
        local cur       = rosterScroll:GetVerticalScroll()
        local ratio     = maxScroll > 0 and (cur / maxScroll) or 0
        sbThumb:ClearAllPoints()
        sbThumb:SetPoint("TOPLEFT", sbTrack, "TOPLEFT", 0, -ratio * (trackH - thumbH))
    end
    rosterScroll:HookScript("OnVerticalScroll", UpdateRosterScrollbar)
    rosterScroll:HookScript("OnScrollRangeChanged", UpdateRosterScrollbar)

    -- ── Right pane: detail block ──────────────────────────────────────────────

    local rightX = LEFT_W + 14

    -- Name + status
    detailNameLabel = MakeLabel(panelFrame, FONT, 13, 1, 1, 1)
    detailNameLabel:SetPoint("TOPLEFT", rightX, listTop)
    detailNameLabel:SetWidth(PW - LEFT_W - 26)
    detailNameLabel:SetJustifyH("LEFT")
    detailNameLabel:SetText("|cff333333Select a member from the roster|r")

    detailStatusLabel = MakeLabel(panelFrame, FONT, 10, 0.6, 0.6, 0.6)
    detailStatusLabel:SetPoint("TOPLEFT", rightX, listTop - 20)
    detailStatusLabel:SetWidth(PW - LEFT_W - 26)
    detailStatusLabel:SetJustifyH("LEFT")

    -- Nick display (only shown for linked characters)
    detailNickLabel = MakeLabel(panelFrame, FONT, 9, 0.45, 0.45, 0.45)
    detailNickLabel:SetPoint("TOPLEFT", rightX, listTop - 33)
    detailNickLabel:SetWidth(PW - LEFT_W - 26 - 68)
    detailNickLabel:SetJustifyH("LEFT")
    detailNickLabel:Hide()

    detailNickBtn = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
    detailNickBtn:SetSize(62, 14)
    detailNickBtn:SetPoint("TOPRIGHT", -6, listTop - 33)
    StyleButton(detailNickBtn, 0.50, 0.40, 0.09)
    detailNickBtn.lbl = MakeLabel(detailNickBtn, FONT, 8, 0.9, 0.76, 0.22)
    detailNickBtn.lbl:SetAllPoints(); detailNickBtn.lbl:SetJustifyH("CENTER")
    detailNickBtn:Hide()

    -- Public / officer notes (up to 2 lines)
    detailNoteLabel = MakeLabel(panelFrame, FONT, 9, 0.55, 0.55, 0.55)
    detailNoteLabel:SetPoint("TOPLEFT", rightX, listTop - 48)
    detailNoteLabel:SetWidth(PW - LEFT_W - 26)
    detailNoteLabel:SetJustifyH("LEFT")

    -- Join date (oldest across linked characters)
    detailJoinLabel = MakeLabel(panelFrame, FONT, 9, 0.45, 0.45, 0.45)
    detailJoinLabel:SetPoint("TOPLEFT", rightX, listTop - 70)
    detailJoinLabel:SetWidth(PW - LEFT_W - 26)
    detailJoinLabel:SetJustifyH("LEFT")

    local linkedHdr = MakeLabel(panelFrame, FONT, 9, 0.50, 0.42, 0.12)
    linkedHdr:SetPoint("TOPLEFT", rightX, listTop - 90)
    linkedHdr:SetText("LINKED CHARACTERS")

    local linkedSep = panelFrame:CreateTexture(nil, "ARTWORK")
    linkedSep:SetHeight(1)
    linkedSep:SetPoint("TOPLEFT", rightX, listTop - 101)
    linkedSep:SetPoint("TOPRIGHT", -6, listTop - 101)
    linkedSep:SetColorTexture(0.30, 0.24, 0.06, 0.45)

    -- Mini scroll for linked characters
    linkedScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildLinkedScroll", panelFrame)
    linkedScroll:SetPoint("TOPLEFT", rightX, listTop - 105)
    linkedScroll:SetWidth(PW - LEFT_W - 26)
    linkedScroll:SetHeight(ROW_H * 4)
    linkedScroll:EnableMouseWheel(true)
    linkedScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_H * 3)))
    end)

    linkedChild = CreateFrame("Frame", nil, linkedScroll)
    linkedChild:SetWidth(PW - LEFT_W - 36)
    linkedChild:SetHeight(20)
    linkedScroll:SetScrollChild(linkedChild)

    -- Minimal scrollbar for linked list
    local lsbTrack = CreateFrame("Frame", nil, panelFrame)
    lsbTrack:SetWidth(5)
    lsbTrack:SetPoint("TOPLEFT", linkedScroll, "TOPRIGHT", 1, 0)
    lsbTrack:SetPoint("BOTTOMLEFT", linkedScroll, "BOTTOMRIGHT", 1, 0)
    local lsbBg = lsbTrack:CreateTexture(nil, "BACKGROUND")
    lsbBg:SetAllPoints(); lsbBg:SetColorTexture(0.12, 0.10, 0.03, 0.35)
    local lsbThumb = lsbTrack:CreateTexture(nil, "OVERLAY")
    lsbThumb:SetWidth(4); lsbThumb:SetColorTexture(0.55, 0.44, 0.10, 0.75); lsbThumb:Hide()
    local function UpdateLinkedScrollbar()
        local childH = linkedChild:GetHeight()
        local viewH  = linkedScroll:GetHeight()
        if childH <= viewH then lsbThumb:Hide(); return end
        lsbThumb:Show()
        local trackH = lsbTrack:GetHeight()
        if trackH <= 0 then return end
        local thumbH = math.max(12, trackH * viewH / childH)
        lsbThumb:SetHeight(thumbH)
        local maxScroll = linkedScroll:GetVerticalScrollRange()
        local cur       = linkedScroll:GetVerticalScroll()
        local ratio     = maxScroll > 0 and (cur / maxScroll) or 0
        lsbThumb:ClearAllPoints()
        lsbThumb:SetPoint("TOPLEFT", lsbTrack, "TOPLEFT", 0, -ratio * (trackH - thumbH))
    end
    linkedScroll:HookScript("OnVerticalScroll", UpdateLinkedScrollbar)
    linkedScroll:HookScript("OnScrollRangeChanged", UpdateLinkedScrollbar)

    -- Action buttons (anchored below linkedChild — repositioned at update time)
    detailBtn1 = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
    detailBtn1:SetSize(PW - LEFT_W - 26 - 96 - 8, 20)
    StyleButton(detailBtn1, 0.50, 0.40, 0.09)
    detailBtn1.lbl = MakeLabel(detailBtn1, FONT, 10, 0.9, 0.76, 0.22)
    detailBtn1.lbl:SetAllPoints(); detailBtn1.lbl:SetJustifyH("CENTER")
    detailBtn1:Hide()

    detailBtn2 = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
    detailBtn2:SetSize(90, 20)
    StyleButton(detailBtn2, 0.55, 0.1, 0.1)
    detailBtn2.lbl = MakeLabel(detailBtn2, FONT, 10, 1, 0.4, 0.4)
    detailBtn2.lbl:SetAllPoints(); detailBtn2.lbl:SetJustifyH("CENTER")
    detailBtn2:Hide()

    -- ── Right pane: horizontal separator between detail and log ───────────────

    local midSepY = listTop - DETAIL_H
    local midSep = panelFrame:CreateTexture(nil, "ARTWORK")
    midSep:SetHeight(1)
    midSep:SetPoint("TOPLEFT", rightX - 4, midSepY)
    midSep:SetPoint("TOPRIGHT", -6, midSepY)
    midSep:SetColorTexture(0.30, 0.24, 0.06, 0.45)

    local logHdr = MakeLabel(panelFrame, FONT, 9, 0.50, 0.42, 0.12)
    logHdr:SetPoint("TOPLEFT", rightX, midSepY - 4)
    logHdr:SetText("ACTIVITY LOG")

    -- Log scroll
    local logScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildLogScroll", panelFrame)
    logScroll:SetPoint("TOPLEFT", rightX, midSepY - 18)
    logScroll:SetPoint("BOTTOMRIGHT", -4, 22)
    logScroll:EnableMouseWheel(true)
    logScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    logEdit = CreateFrame("EditBox", nil, logScroll)
    logEdit:SetMultiLine(true)
    logEdit:SetAutoFocus(false)
    logEdit:SetFont(FONT, 10, "")
    logEdit:SetTextColor(1, 1, 1, 1)
    logEdit:SetWidth(PW - LEFT_W - 26)
    logEdit:SetScript("OnEscapePressed", function() panelFrame:Hide() end)
    logScroll:SetScrollChild(logEdit)
end

-- ── Public API ────────────────────────────────────────────────────────────────

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
    logEdit:SetText(BuildLogText())
    if statsLabel then statsLabel:SetText(BuildStatsText()) end
    C_Timer.After(0, function()
        local logScroll = logEdit:GetParent()
        if logScroll and logScroll.SetVerticalScroll then
            logScroll:SetVerticalScroll(0)
        end
    end)
end
