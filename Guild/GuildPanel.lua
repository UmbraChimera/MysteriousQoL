local _, addon = ...

local FONT    = "Fonts\\FRIZQT__.TTF"
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]

-- Panel and layout sizes
local PW, PH   = 680, 540  -- panel width, height
local LEFT_W   = 292        -- roster pane width
local ROW_H    = 18         -- height of each roster / linked row
local DETAIL_H = 200        -- fixed height of the character-detail block

-- Theme colors: gold for primary actions, red for destructive ones.
-- Defined once here so they're easy to find and change.
local GOLD_R, GOLD_G, GOLD_B     = 0.90, 0.76, 0.22  -- gold label text
local GOLD_BR, GOLD_BG, GOLD_BB  = 0.50, 0.40, 0.09  -- gold button border (darker)
local RED_BR,  RED_BG,  RED_BB   = 0.55, 0.10, 0.10  -- red button border (destructive)
local RED_R,   RED_G,   RED_B    = 1.00, 0.40, 0.40  -- red button label text

local panelFrame = nil

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
local detailActionBtn, detailDestructBtn
local detailNickLabel, detailNickBtn

-- Right pane bottom: activity log
local logEdit

-- Filter state
local rosterFilter  = "all"  -- "all", "mains", "alts", "unlinked"
local onlineOnly    = false
local radioAll, radioMains, radioAlts, radioUnlinked, onlineOnlyBtn
local statsLabel    = nil
local syncStatus     = nil
local syncIdle       = true

local syncPopup          = nil
local syncPopupRows      = {}
local syncPopupStatusLbl = nil
local syncPopupBtnLbl    = nil
local syncPopupNoPeers   = nil

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

-- Shortcuts for the two button styles used throughout this panel
local function StyleGoldButton(btn) StyleButton(btn, GOLD_BR, GOLD_BG, GOLD_BB) end
local function StyleRedButton(btn)  StyleButton(btn, RED_BR,  RED_BG,  RED_BB)  end

local function MakeLabel(parent, font, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or FONT, size or 11, "")
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    return fs
end

-- Creates a thin custom scrollbar that tracks a scroll frame.
-- scrollChild is the inner content frame; thumbMinH is the minimum thumb height in pixels.
local function MakeScrollbar(scrollFrame, scrollChild, thumbMinH)
    thumbMinH = thumbMinH or 16
    local track = CreateFrame("Frame", nil, scrollFrame:GetParent())
    track:SetWidth(5)
    track:SetPoint("TOPLEFT",    scrollFrame, "TOPRIGHT",    1, 0)
    track:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 1, 0)
    track:EnableMouse(true)

    local bg = track:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.10, 0.03, 0.35)

    -- Thumb is a Frame (not a Texture) so it can receive mouse events.
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(4)
    thumb:Hide()
    thumb:EnableMouse(true)
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.55, 0.44, 0.10, 0.75)

    local function UpdateThumb()
        local childH = scrollChild:GetHeight()
        local viewH  = scrollFrame:GetHeight()
        if childH <= viewH then thumb:Hide(); return end
        thumb:Show()
        local trackH = track:GetHeight()
        if trackH <= 0 then return end
        local thumbH    = math.max(thumbMinH, trackH * viewH / childH)
        thumb:SetHeight(thumbH)
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local cur       = scrollFrame:GetVerticalScroll()
        local ratio     = maxScroll > 0 and (cur / maxScroll) or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -ratio * (trackH - thumbH))
    end

    local function CursorUIY()
        return select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
    end

    -- Drag thumb to scroll
    local dragging, dragStartY, dragStartScroll = false, 0, 0
    thumb:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        dragging        = true
        dragStartY      = CursorUIY()
        dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    thumb:SetScript("OnMouseUp", function() dragging = false end)
    thumb:SetScript("OnUpdate", function()
        if not dragging then return end
        local tTop = track:GetTop(); local tBot = track:GetBottom()
        if not tTop or not tBot then return end
        local trackH_UI = tTop - tBot
        local thumbH_UI = thumb:GetTop() and thumb:GetBottom() and (thumb:GetTop() - thumb:GetBottom()) or 0
        local range = trackH_UI - thumbH_UI
        if range <= 0 then return end
        local delta     = dragStartY - CursorUIY()  -- positive = cursor moved down = more scroll
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, dragStartScroll + (delta / range) * maxScroll)))
        UpdateThumb()
    end)

    -- Click track above/below thumb to page-scroll
    track:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        local thumbTop = thumb:IsShown() and thumb:GetTop()
        local cur      = scrollFrame:GetVerticalScroll()
        local viewH    = scrollFrame:GetHeight()
        local maxS     = scrollFrame:GetVerticalScrollRange()
        if thumbTop and CursorUIY() > thumbTop then
            scrollFrame:SetVerticalScroll(math.max(0, cur - viewH))
        else
            scrollFrame:SetVerticalScroll(math.min(maxS, cur + viewH))
        end
        UpdateThumb()
    end)

    scrollFrame:HookScript("OnVerticalScroll",    UpdateThumb)
    scrollFrame:HookScript("OnScrollRangeChanged", UpdateThumb)
end

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
        local trimmed = {}
        for i = 1, MAX_AUTOCOMPLETE do trimmed[i] = results[i] end
        return trimmed
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

local function BuildRosterEntries(filter)
    local entries = {}
    local lowerFilter = filter and filter:lower() or ""
    for i = 1, GetNumGuildMembers() do
        local name, rankName, rankIndex, level, _, _, _, _, isOnline, _, classToken = GetGuildRosterInfo(i)
        if name then
            local groupIdx, group, isMain = addon.MI_Guild_GetGroupForChar(name)
            local matches = lowerFilter == ""
                or name:lower():find(lowerFilter, 1, true)
                or (group and group.main:lower():find(lowerFilter, 1, true))
                or (group and group.nick and group.nick:lower():find(lowerFilter, 1, true))
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
        -- Sort so linked characters appear together, mains before their alts
        local aKey = a.group and (a.group.main .. "\001" .. (a.isMain and "\000" or a.name)) or a.name
        local bKey = b.group and (b.group.main .. "\001" .. (b.isMain and "\000" or b.name)) or b.name
        return aKey < bKey
    end)
    return entries
end

local function StatusText(entry)
    if entry.isMain then
        return "|cffffcc00Main|r"
    elseif entry.group then
        return "|cff555555" .. (entry.group.nick or entry.group.main) .. "|r"
    else
        return "|cff2a2a2a-|r"
    end
end

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

function addon.MI_GuildPanel_UpdateDetail(name)
    for _, row in ipairs(linkedRows) do row:Hide(); row:ClearAllPoints() end
    detailActionBtn:Hide(); detailDestructBtn:Hide()
    detailActionBtn:SetScript("OnClick", nil)
    detailDestructBtn:SetScript("OnClick", nil)

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

    -- Join date: show oldest across the whole linked group (or just this char if unlinked)
    local chars = { group and group.main or name }
    if group then
        for _, a in ipairs(group.alts) do table.insert(chars, a) end
    end
    local joinTimestamp = GetOldestJoinDate(chars)
    if joinTimestamp then
        detailJoinLabel:SetText("|cff666666Joined:|r " .. date("%b %d, %Y", joinTimestamp))
    else
        detailJoinLabel:SetText("")
    end

    if not group then
        detailNickLabel:Hide()
        detailNickBtn:Hide()
        detailStatusLabel:SetText(infoStr .. "|cff555555Not linked|r")
        linkedChild:SetHeight(20)

        detailActionBtn:SetPoint("TOPLEFT", linkedScroll, "BOTTOMLEFT", 0, -6)
        detailActionBtn.lbl:SetText("Set as Main")
        StyleGoldButton(detailActionBtn)
        detailActionBtn:Show()
        detailActionBtn:SetScript("OnClick", function()
            addon.MI_Guild_SetAsMain(name)
            addon.MI_GuildPanel_Refresh()
        end)

        detailDestructBtn:SetPoint("TOPRIGHT", linkedScroll, "BOTTOMRIGHT", 0, -6)
        detailDestructBtn.lbl:SetText("Link as Alt...")
        StyleGoldButton(detailDestructBtn)
        detailDestructBtn:Show()
        detailDestructBtn:SetScript("OnClick", function()
            ShowInputDialog("Link " .. name .. " as alt of:", function(mainName)
                addon.MI_Guild_LinkAltToMain(name, mainName)
                addon.MI_GuildPanel_Refresh()
            end)
        end)
        return
    end

    -- Nick row
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

    if isMain then
        detailStatusLabel:SetText(infoStr .. "|cffffcc00Main|r")
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
        local isThisMain = (charName == group.main)
        local isCurrent  = (charName == name)

        local cLvl, _, cToken = GetMemberInfo(charName)
        local cColor  = ClassColor(cToken)
        local cLvlStr = cLvl > 0 and ("|cff666666" .. cLvl .. "|r ") or ""
        local mainTag = isThisMain and "|cffffcc00[M]|r " or ""
        row.nameLabel:SetText(mainTag .. cLvlStr .. cColor .. charName .. "|r")
        row.hl:SetColorTexture(0.25, 0.2, 0.05, isCurrent and 0.16 or 0)

        if isThisMain then
            row.setMainBtn:Hide()
        else
            row.setMainBtn:Show()
        end
        row:Show()
        yOff = yOff + ROW_H
    end
    linkedChild:SetHeight(math.max(yOff, 20))

    detailActionBtn:SetPoint("TOPLEFT", linkedScroll, "BOTTOMLEFT", 0, -6)
    detailActionBtn.lbl:SetText("Link Alt...")
    StyleGoldButton(detailActionBtn)
    detailActionBtn:Show()
    detailActionBtn:SetScript("OnClick", function()
        ShowInputDialog("Add alt to " .. group.main .. ":", function(altName)
            addon.MI_Guild_LinkAltToMain(altName, group.main)
            addon.MI_GuildPanel_Refresh()
        end)
    end)

    detailDestructBtn:SetPoint("TOPRIGHT", linkedScroll, "BOTTOMRIGHT", 0, -6)
    if isMain then
        detailDestructBtn.lbl:SetText("Delete Group")
        StyleRedButton(detailDestructBtn)
        detailDestructBtn:SetScript("OnClick", function()
            addon.MI_Guild_DeleteGroup(groupIdx)
            selectedName = nil
            addon.MI_GuildPanel_Refresh()
        end)
    else
        detailDestructBtn.lbl:SetText("Unlink Me")
        StyleRedButton(detailDestructBtn)
        detailDestructBtn:SetScript("OnClick", function()
            addon.MI_Guild_UnlinkChar(name)
            addon.MI_GuildPanel_Refresh()
        end)
    end
    detailDestructBtn:Show()
end

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

    local prevGroupMain = nil  -- nil means "no previous group seen yet"
    local yOff = 0
    for i, entry in ipairs(rosterEntries) do
        local groupMain = entry.group and entry.group.main
        if groupMain ~= prevGroupMain then
            if i > 1 then yOff = yOff + 3 end  -- 3px visual gap between groups
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

local function FormatAgo(sec)
    if sec < 60    then return sec .. "s ago"
    elseif sec < 3600 then return math.floor(sec / 60) .. "m ago"
    else                   return math.floor(sec / 3600) .. "h ago"
    end
end

local function UpdateSyncStatus()
    if not syncStatus or not syncIdle then return end
    local now   = time()
    local parts = {}
    if addon.MI_GuildSync_lastBroadcast > 0 then
        table.insert(parts, "sent " .. FormatAgo(now - addon.MI_GuildSync_lastBroadcast))
    end
    if addon.MI_GuildSync_lastReceive > 0 then
        table.insert(parts, "rcvd " .. FormatAgo(now - addon.MI_GuildSync_lastReceive))
    end
    syncStatus:SetText(table.concat(parts, " · "))
    syncStatus:SetTextColor(0.42, 0.35, 0.10, 1)
end

local function RefreshSyncPopup()
    if not syncPopup or not syncPopup:IsShown() then return end

    local POPUP_W   = 300
    local TITLE_H   = 26
    local SECTION_H = 20
    local ROW_H_P   = 16
    local FOOTER_H  = 58

    local threshold = addon.MI_GuildSync_rankThreshold or 1
    local myName    = UnitName("player")
    local peers     = {}
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline and rankIndex <= threshold then
            local bare = name and name:match("^([^%-]+)") or name
            if bare ~= myName then table.insert(peers, bare) end
        end
    end
    table.sort(peers)

    local peerStatus = addon.MI_GuildSync_peerStatus or {}
    local N = #peers

    for i = 1, N do
        if not syncPopupRows[i] then
            local row = CreateFrame("Frame", nil, syncPopup)
            row:SetHeight(ROW_H_P)
            row.dot     = MakeLabel(row, FONT, 11)
            row.dot:SetPoint("TOPLEFT", 8, -1); row.dot:SetJustifyH("LEFT")
            row.nameLbl = MakeLabel(row, FONT, 10)
            row.nameLbl:SetPoint("TOPLEFT", 22, 0); row.nameLbl:SetJustifyH("LEFT")
            row.statusLbl = MakeLabel(row, FONT, 9)
            row.statusLbl:SetPoint("TOPRIGHT", -8, 0); row.statusLbl:SetJustifyH("RIGHT")
            syncPopupRows[i] = row
        end
        local row    = syncPopupRows[i]
        local bare   = peers[i]
        local status = peerStatus[bare]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", syncPopup, "TOPLEFT", 0, -(TITLE_H + SECTION_H + (i - 1) * ROW_H_P))
        row:SetWidth(POPUP_W)
        if status == "ok" then
            row.dot:SetText("|cff44aa44●|r")
            row.nameLbl:SetText(bare); row.nameLbl:SetTextColor(0.8, 0.8, 0.8, 1)
            row.statusLbl:SetText("|cff44aa44in sync|r")
        elseif status == "diff" then
            row.dot:SetText("|cffcc8833●|r")
            row.nameLbl:SetText(bare); row.nameLbl:SetTextColor(0.8, 0.8, 0.8, 1)
            row.statusLbl:SetText("|cffcc8833out of sync|r")
        else
            row.dot:SetText("|cff666666●|r")
            row.nameLbl:SetText(bare); row.nameLbl:SetTextColor(0.55, 0.55, 0.55, 1)
            row.statusLbl:SetText("|cff555555unknown|r")
        end
        row:Show()
    end
    for i = N + 1, #syncPopupRows do syncPopupRows[i]:Hide() end

    if N == 0 then syncPopupNoPeers:Show() else syncPopupNoPeers:Hide() end

    local peerAreaH = math.max(1, N) * ROW_H_P
    local totalH    = TITLE_H + SECTION_H + peerAreaH + 8 + FOOTER_H
    syncPopup:SetHeight(totalH)

    local footerY = -(TITLE_H + SECTION_H + peerAreaH + 8)
    syncPopup.footerSep:ClearAllPoints()
    syncPopup.footerSep:SetPoint("TOPLEFT",  syncPopup, "TOPLEFT",  1, footerY)
    syncPopup.footerSep:SetPoint("TOPRIGHT", syncPopup, "TOPRIGHT", -1, footerY)

    local now   = time()
    local parts = {}
    if addon.MI_GuildSync_lastBroadcast > 0 then
        table.insert(parts, "sent " .. FormatAgo(now - addon.MI_GuildSync_lastBroadcast))
    end
    if addon.MI_GuildSync_lastReceive > 0 then
        table.insert(parts, "rcvd " .. FormatAgo(now - addon.MI_GuildSync_lastReceive))
    end
    local statusTxt = table.concat(parts, " · ")
    if syncIdle then
        syncPopupStatusLbl:SetText(statusTxt ~= "" and statusTxt or "Never synced")
        syncPopupStatusLbl:SetTextColor(0.42, 0.35, 0.10, 1)
    end
    syncPopupStatusLbl:ClearAllPoints()
    syncPopupStatusLbl:SetPoint("TOPLEFT", syncPopup, "TOPLEFT", 8, footerY - 8)

    syncPopup.syncNowBtn:ClearAllPoints()
    syncPopup.syncNowBtn:SetPoint("BOTTOM", syncPopup, "BOTTOM", 0, 8)
end

local function BuildSyncPopup()
    if syncPopup then return end

    syncPopup = CreateFrame("Frame", "MysteriousQoL_SyncPopup", UIParent, "BackdropTemplate")
    syncPopup:SetSize(300, 100)
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

    local sectionHdr = MakeLabel(syncPopup, FONT, 9, 0.50, 0.42, 0.12)
    sectionHdr:SetPoint("TOPLEFT", 8, -28)
    sectionHdr:SetText("ELIGIBLE PEERS")

    syncPopupNoPeers = MakeLabel(syncPopup, FONT, 10, 0.4, 0.4, 0.4)
    syncPopupNoPeers:SetPoint("TOPLEFT", 12, -44)
    syncPopupNoPeers:SetText("No eligible peers online")
    syncPopupNoPeers:Hide()

    local footerSep = syncPopup:CreateTexture(nil, "ARTWORK")
    footerSep:SetHeight(1)
    footerSep:SetColorTexture(0.32, 0.26, 0.06, 0.5)
    syncPopup.footerSep = footerSep

    syncPopupStatusLbl = MakeLabel(syncPopup, FONT, 10, 0.42, 0.35, 0.10)

    local syncNowBtn = CreateFrame("Button", nil, syncPopup, "BackdropTemplate")
    syncNowBtn:SetSize(100, 22)
    StyleGoldButton(syncNowBtn)
    syncPopupBtnLbl = MakeLabel(syncNowBtn, FONT, 11, GOLD_R, GOLD_G, GOLD_B)
    syncPopupBtnLbl:SetAllPoints(); syncPopupBtnLbl:SetJustifyH("CENTER")
    syncPopupBtnLbl:SetText("Sync Now")
    syncPopup.syncNowBtn = syncNowBtn

    syncNowBtn:SetScript("OnClick", function()
        local n = addon.MI_GuildSync_Broadcast()
        if not n then return end
        syncIdle = false
        syncPopupBtnLbl:SetText("Syncing…")
        syncPopupStatusLbl:SetText("Syncing " .. n .. " groups…")
        syncPopupStatusLbl:SetTextColor(0.80, 0.70, 0.20, 1)
        if syncStatus then
            syncStatus:SetText("Syncing…")
            syncStatus:SetTextColor(0.80, 0.70, 0.20, 1)
        end
        addon.MI_GuildSync_onComplete = function()
            print("|cffffcc00[Guild Sync]|r " .. n .. " groups broadcast to guild.")
            syncPopupBtnLbl:SetText("Sync Now")
            addon.MI_GuildSync_peerStatus = {}
            addon.MI_GuildSync_BroadcastHello()
            C_Timer.After(3, function()
                syncIdle = true
                UpdateSyncStatus()
                RefreshSyncPopup()
            end)
        end
    end)
end

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

    local title = MakeLabel(panelFrame, FONT, 13, GOLD_R, GOLD_G, GOLD_B)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Guild Manager")

    local closeBtn = CreateFrame("Button", nil, panelFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panelFrame:Hide() end)

    local function MakeToolbarButton(label, x, onClick)
        local btn = CreateFrame("Button", nil, panelFrame, "BackdropTemplate")
        btn:SetSize(88, 22)
        btn:SetPoint("TOPLEFT", x, -26)
        StyleGoldButton(btn)
        local lbl = MakeLabel(btn, FONT, 11, GOLD_R, GOLD_G, GOLD_B)
        lbl:SetAllPoints(); lbl:SetJustifyH("CENTER"); lbl:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local syncBtn = MakeToolbarButton("Sync...", 8, nil)
    syncStatus = MakeLabel(panelFrame, FONT, 10, 0.50, 0.42, 0.12)
    syncStatus:SetPoint("LEFT", syncBtn, "RIGHT", 6, 0)
    syncStatus:SetText("")
    syncBtn:SetScript("OnClick", function()
        BuildSyncPopup()
        if syncPopup:IsShown() then
            syncPopup:Hide()
        else
            if addon.MI_GuildSync_BroadcastHello then addon.MI_GuildSync_BroadcastHello() end
            RefreshSyncPopup()
            syncPopup:Show()
        end
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

    local contentTop = -54  -- Y offset from panel top edge, just below the toolbar separator
    local listTop    = contentTop - 22  -- Y offset where the scrollable list starts (below the filter radio row)

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

    -- Vertical divider between roster and detail panes
    local divider = panelFrame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT",    LEFT_W + 8, listTop)
    divider:SetPoint("BOTTOMLEFT", LEFT_W + 8, 22)
    divider:SetColorTexture(0.32, 0.26, 0.06, 0.5)

    -- Stats bar along the bottom
    local statsSep = panelFrame:CreateTexture(nil, "ARTWORK")
    statsSep:SetHeight(1)
    statsSep:SetPoint("BOTTOMLEFT",  1,  20)
    statsSep:SetPoint("BOTTOMRIGHT", -1, 20)
    statsSep:SetColorTexture(0.28, 0.22, 0.05, 0.4)

    statsLabel = MakeLabel(panelFrame, FONT, 9, 0.5, 0.5, 0.5)
    statsLabel:SetPoint("BOTTOMLEFT",  8,  6)
    statsLabel:SetPoint("BOTTOMRIGHT", -8, 6)
    statsLabel:SetJustifyH("LEFT")

    -- Resize grip (bottom-right corner): drag left/right to scale the panel
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
        gripDragging   = true
        gripStartX     = GetCursorPosition()
        gripStartScale = panelFrame:GetScale()
    end)
    grip:SetScript("OnMouseUp", function() gripDragging = false end)
    grip:SetScript("OnUpdate", function()
        if not gripDragging then return end
        local cx = GetCursorPosition()
        -- 600 pixels of drag = full 1.0 scale change; clamp between 0.6 and 1.4
        local newScale = math.max(0.6, math.min(1.4, gripStartScale + (cx - gripStartX) / 600))
        local snapped  = math.floor(newScale / 0.05 + 0.5) * 0.05  -- snap to nearest 0.05
        addon.db.guild_panel_scale = snapped
        panelFrame:SetScale(snapped)
    end)

    -- Left pane: roster scroll

    rosterScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildRosterScroll", panelFrame)
    rosterScroll:SetPoint("TOPLEFT",    4, listTop)
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

    MakeScrollbar(rosterScroll, rosterChild, 16)

    -- Right pane: detail block

    local rightX = LEFT_W + 14  -- X start for all right-pane content

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
    StyleGoldButton(detailNickBtn)
    detailNickBtn.lbl = MakeLabel(detailNickBtn, FONT, 8, GOLD_R, GOLD_G, GOLD_B)
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
    linkedSep:SetPoint("TOPLEFT",  rightX, listTop - 101)
    linkedSep:SetPoint("TOPRIGHT", -6,     listTop - 101)
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

    MakeScrollbar(linkedScroll, linkedChild, 12)

    -- Action buttons (repositioned each time UpdateDetail runs)
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

    -- Right pane: separator between detail and log

    local midSepY = listTop - DETAIL_H  -- Y where the detail block ends and the log begins

    local midSep = panelFrame:CreateTexture(nil, "ARTWORK")
    midSep:SetHeight(1)
    midSep:SetPoint("TOPLEFT",  rightX - 4, midSepY)
    midSep:SetPoint("TOPRIGHT", -6,         midSepY)
    midSep:SetColorTexture(0.30, 0.24, 0.06, 0.45)

    local logHdr = MakeLabel(panelFrame, FONT, 9, 0.50, 0.42, 0.12)
    logHdr:SetPoint("TOPLEFT", rightX, midSepY - 4)
    logHdr:SetText("ACTIVITY LOG")

    -- Log scroll
    local logScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildLogScroll", panelFrame)
    logScroll:SetPoint("TOPLEFT",    rightX, midSepY - 18)
    logScroll:SetPoint("BOTTOMRIGHT", -4,    22)
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
    logEdit:SetEnabled(false)
    logScroll:SetScrollChild(logEdit)
end

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
    UpdateSyncStatus()
    RefreshSyncPopup()
    logEdit:SetText(BuildLogText())
    if statsLabel then statsLabel:SetText(BuildStatsText()) end
    C_Timer.After(0, function()
        local logScroll = logEdit:GetParent()
        if logScroll and logScroll.SetVerticalScroll then
            logScroll:SetVerticalScroll(0)
        end
    end)
end
