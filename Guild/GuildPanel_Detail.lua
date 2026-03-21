local _, addon = ...

local P  = addon.GuildPanel
local GU = addon.GuildUI

local linkedRows = {}

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
            row.nameLabel = GU.MakeLabel(row, GU.FONT, 11)
            row.nameLabel:SetPoint("LEFT", 8, 0); row.nameLabel:SetPoint("RIGHT", -60, 0)
            row.nameLabel:SetJustifyH("LEFT")
            row.rankLabel = GU.MakeLabel(row, GU.FONT, 9, 0.45, 0.45, 0.45)
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
    local parent = P.frame or UIParent
    inputDialog = CreateFrame("Frame", "MysteriousQoL_GuildInput", parent, "BackdropTemplate")
    inputDialog:SetSize(270, INPUT_DIALOG_H); inputDialog:SetPoint("CENTER")
    inputDialog:SetFrameLevel(parent:GetFrameLevel() + 20)
    inputDialog:SetBackdrop(GU.MakeBackdrop())
    inputDialog:SetBackdropColor(0.07, 0.07, 0.07, 0.98)
    inputDialog:SetBackdropBorderColor(0.55, 0.44, 0.12, 1)
    inputDialog:Hide()

    inputDialog.titleText = GU.MakeLabel(inputDialog, GU.FONT, 11, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    inputDialog.titleText:SetPoint("TOPLEFT", 8, -8)

    local editBox = CreateFrame("EditBox", nil, inputDialog, "BackdropTemplate")
    editBox:SetSize(250, 22); editBox:SetPoint("TOP", 0, -28)
    editBox:SetFont(GU.FONT, 11, ""); editBox:SetTextColor(1, 1, 1, 1); editBox:SetAutoFocus(true)
    editBox:SetBackdrop(GU.MakeBackdrop())
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
    autocompleteFrame:SetBackdrop(GU.MakeBackdrop())
    autocompleteFrame:SetBackdropColor(0.08, 0.07, 0.03, 0.97)
    autocompleteFrame:SetBackdropBorderColor(0.35, 0.28, 0.07, 0.6)
    autocompleteFrame:Hide()

    local okBtn = CreateFrame("Button", nil, inputDialog, "BackdropTemplate")
    okBtn:SetSize(70, 20); okBtn:SetPoint("BOTTOMLEFT", 8, 8)
    GU.StyleGoldButton(okBtn)
    local okLabel = GU.MakeLabel(okBtn, GU.FONT, 10, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    okLabel:SetAllPoints(); okLabel:SetJustifyH("CENTER"); okLabel:SetText("OK")
    okBtn:SetScript("OnClick", function()
        local t = editBox:GetText():match("^%s*(.-)%s*$")
        inputDialog:Hide()
        if (t ~= "" or inputAllowEmpty) and inputCallback then inputCallback(t) end
    end)

    local cancelBtn = CreateFrame("Button", nil, inputDialog, "BackdropTemplate")
    cancelBtn:SetSize(70, 20); cancelBtn:SetPoint("BOTTOMRIGHT", -8, 8)
    GU.StyleRedButton(cancelBtn)
    local cancelLabel = GU.MakeLabel(cancelBtn, GU.FONT, 10, GU.RED_R, GU.RED_G, GU.RED_B)
    cancelLabel:SetAllPoints(); cancelLabel:SetJustifyH("CENTER"); cancelLabel:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() inputDialog:Hide() end)
end

function P.ShowInputDialog(title, callback, noAC, prefill, allowEmpty)
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
-- Linked character row pool

local function GetOrCreateLinkedRow(i)
    if linkedRows[i] then return linkedRows[i] end
    local row = CreateFrame("Frame", nil, P.linkedChild)
    row:SetHeight(P.ROW_H)

    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(); hl:SetColorTexture(0.25, 0.2, 0.05, 0); row.hl = hl

    row.nameLabel = GU.MakeLabel(row, GU.FONT, 11)
    row.nameLabel:SetPoint("LEFT", 4, 0)
    row.nameLabel:SetPoint("RIGHT", -68, 0)
    row.nameLabel:SetJustifyH("LEFT")

    row.setMainBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.setMainBtn:SetSize(60, 15); row.setMainBtn:SetPoint("RIGHT", -3, 0)
    GU.StyleGoldButton(row.setMainBtn)
    local setMainLabel = GU.MakeLabel(row.setMainBtn, GU.FONT, 9, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    setMainLabel:SetAllPoints(); setMainLabel:SetJustifyH("CENTER"); setMainLabel:SetText("Set Main")
    row.setMainBtn:SetScript("OnClick", function()
        if not row.charName then return end
        addon.MI_Guild_SetAsMain(row.charName)
        addon.MI_GuildPanel_Refresh()
    end)

    linkedRows[i] = row
    return row
end

-- ---------------------------------------------------------------------------------
-- Detail pane updater

function P.UpdateDetail(name)
    local d = P.detail
    for _, row in ipairs(linkedRows) do row:Hide(); row:ClearAllPoints() end
    d.actionBtn:Hide(); d.destructBtn:Hide()
    d.actionBtn:SetScript("OnClick", nil); d.destructBtn:SetScript("OnClick", nil)
    d.roleTankCB:SetScript("OnClick", nil)
    d.roleHealCB:SetScript("OnClick", nil)
    d.roleDpsCB:SetScript("OnClick", nil)

    if not name then
        d.nameLabel:SetText("|cff333333Select a member from the roster|r")
        d.statusLabel:SetText(""); d.noteLabel:SetText("")
        d.joinLabel:SetText(""); d.lastSeenLabel:SetText("")
        d.inactiveLabel:Hide(); d.joinEditBtn:Hide()
        d.nickLabel:Hide(); d.nickBtn:Hide()
        d.roleTankCB:Hide(); d.roleTankCB.roleLbl:Hide()
        d.roleHealCB:Hide(); d.roleHealCB.roleLbl:Hide()
        d.roleDpsCB:Hide();  d.roleDpsCB.roleLbl:Hide()
        if d.rolesHdr then d.rolesHdr:Hide() end
        P.linkedChild:SetHeight(20)
        return
    end

    local _, group, isMain = addon.MI_Guild_GetGroupForChar(name)
    local charData = P.GetCharData(name)
    local level, classDisplay, classToken, publicNote, officerNote = P.GetMemberInfo(name)
    local cc      = P.ClassColor(classToken)
    local infoStr = (level > 0 and classDisplay ~= "") and ("|cff888888" .. level .. " " .. classDisplay .. "|r  ") or ""

    d.nameLabel:SetText(cc .. name .. "|r")

    local noteLines = {}
    if publicNote  ~= "" then table.insert(noteLines, "|cff888888Note:|r " .. publicNote) end
    if officerNote ~= "" then table.insert(noteLines, "|cff666666Officer:|r " .. officerNote) end
    d.noteLabel:SetText(table.concat(noteLines, "\n"))

    local lastSeen = charData and charData.lastSeen
    if lastSeen then
        d.lastSeenLabel:SetText("|cff666666Last seen:|r " .. P.FormatDaysAgo(lastSeen))
    else
        d.lastSeenLabel:SetText("|cff444444Last seen:|r |cff444444Unknown|r")
    end

    local charNames = { group and group.main or name }
    if group then for _, a in ipairs(group.alts) do table.insert(charNames, a) end end
    local joinTs = P.GetOldestJoinDate(charNames)
    if joinTs then
        d.joinLabel:SetText("|cff666666Joined:|r " .. P.FormatDate(joinTs))
    else
        d.joinLabel:SetText("|cff444444Joined:|r |cff444444Unknown|r")
    end
    d.joinEditBtn:Show()
    d.joinEditBtn:SetScript("OnClick", function()
        local curStr = joinTs and P.FormatDate(joinTs) or ""
        P.ShowInputDialog("Join date (YYYY-MM-DD or Unknown):", function(input)
            local ts = P.ParseDateInput(input)
            if ts ~= nil then
                addon.MI_Guild_SetJoinDate(name, ts)
                addon.MI_GuildPanel_Refresh()
            end
        end, true, curStr, true)
    end)

    if P.IsInactive(lastSeen, group) then
        d.inactiveLabel:SetText("|cffff8800⚠ Inactive|r"); d.inactiveLabel:Show()
    else
        d.inactiveLabel:Hide()
    end

    if d.rolesHdr then d.rolesHdr:Show() end
    local roles = charData and charData.roles or "000"
    d.roleTankCB:SetChecked(roles:sub(1,1) == "1"); d.roleTankCB:Show(); d.roleTankCB.roleLbl:Show()
    d.roleHealCB:SetChecked(roles:sub(2,2) == "1"); d.roleHealCB:Show(); d.roleHealCB.roleLbl:Show()
    d.roleDpsCB:SetChecked(roles:sub(3,3) == "1");  d.roleDpsCB:Show();  d.roleDpsCB.roleLbl:Show()

    local function OnRoleClick()
        local t = d.roleTankCB:GetChecked() and "1" or "0"
        local h = d.roleHealCB:GetChecked() and "1" or "0"
        local dp = d.roleDpsCB:GetChecked() and "1" or "0"
        addon.MI_Guild_SetRoles(name, t .. h .. dp)
    end
    d.roleTankCB:SetScript("OnClick", OnRoleClick)
    d.roleHealCB:SetScript("OnClick", OnRoleClick)
    d.roleDpsCB:SetScript("OnClick", OnRoleClick)

    if not group then
        d.nickLabel:Hide(); d.nickBtn:Hide()
        d.statusLabel:SetText(infoStr .. "|cff555555Not linked|r")
        P.linkedChild:SetHeight(20)

        d.actionBtn:SetPoint("TOPLEFT", P.linkedScroll, "BOTTOMLEFT", 0, -6)
        d.actionBtn.lbl:SetText("Set as Main"); GU.StyleGoldButton(d.actionBtn); d.actionBtn:Show()
        d.actionBtn:SetScript("OnClick", function()
            addon.MI_Guild_SetAsMain(name); addon.MI_GuildPanel_Refresh()
        end)

        d.destructBtn:SetPoint("TOPRIGHT", P.linkedScroll, "BOTTOMRIGHT", 0, -6)
        d.destructBtn.lbl:SetText("Link as Alt..."); GU.StyleGoldButton(d.destructBtn); d.destructBtn:Show()
        d.destructBtn:SetScript("OnClick", function()
            P.ShowInputDialog("Link " .. name .. " as alt of:", function(mn)
                addon.MI_Guild_LinkAltToMain(name, mn); addon.MI_GuildPanel_Refresh()
            end)
        end)
        return
    end

    local nick = group.nick
    d.nickLabel:SetText(nick and ("|cff666666Nickname:|r " .. nick) or "|cff333333Nickname: none|r")
    d.nickLabel:Show()
    d.nickBtn.lbl:SetText(nick and "Edit Nickname" or "Set Nickname")
    d.nickBtn:SetScript("OnClick", function()
        P.ShowInputDialog("Nickname for " .. group.main .. ":", function(newNick)
            addon.MI_Guild_SetNick(group.main, newNick); addon.MI_GuildPanel_Refresh()
        end, true, nick or "", true)
    end)
    d.nickBtn:Show()

    if isMain then
        d.statusLabel:SetText(infoStr .. "|cffffcc00Main|r")
    else
        d.statusLabel:SetText(infoStr .. "Alt of |cffffcc00" .. group.main .. "|r")
    end

    local members = { group.main }
    for _, a in ipairs(group.alts) do table.insert(members, a) end
    local yOff = 0
    for i, charName in ipairs(members) do
        local row = GetOrCreateLinkedRow(i)
        row:SetPoint("TOPLEFT", P.linkedChild, "TOPLEFT", 0, -yOff)
        row:SetWidth(P.linkedChild:GetWidth())
        row.charName = charName
        local isThisMain = (charName == group.main)
        local isCurrent  = (charName == name)
        local cLvl, _, cToken = P.GetMemberInfo(charName)
        local cColor  = P.ClassColor(cToken)
        local cLvlStr = cLvl > 0 and ("|cff666666" .. cLvl .. "|r ") or ""
        local mainTag = isThisMain and "|cffffcc00[M]|r " or ""
        row.nameLabel:SetText(mainTag .. cLvlStr .. cColor .. charName .. "|r")
        row.hl:SetColorTexture(0.25, 0.2, 0.05, isCurrent and 0.16 or 0)
        if isThisMain then row.setMainBtn:Hide() else row.setMainBtn:Show() end
        row:Show(); yOff = yOff + P.ROW_H
    end
    P.linkedChild:SetHeight(math.max(yOff, 20))

    d.actionBtn:SetPoint("TOPLEFT", P.linkedScroll, "BOTTOMLEFT", 0, -6)
    d.actionBtn.lbl:SetText("Link Alt..."); GU.StyleGoldButton(d.actionBtn); d.actionBtn:Show()
    d.actionBtn:SetScript("OnClick", function()
        P.ShowInputDialog("Add alt to " .. group.main .. ":", function(altName)
            addon.MI_Guild_LinkAltToMain(altName, group.main); addon.MI_GuildPanel_Refresh()
        end)
    end)

    d.destructBtn:SetPoint("TOPRIGHT", P.linkedScroll, "BOTTOMRIGHT", 0, -6)
    if isMain then
        d.destructBtn.lbl:SetText("Delete Group"); GU.StyleRedButton(d.destructBtn)
        d.destructBtn:SetScript("OnClick", function()
            addon.MI_Guild_DeleteGroup(group.main); P.selectedName = nil; addon.MI_GuildPanel_Refresh()
        end)
    else
        d.destructBtn.lbl:SetText("Unlink Me"); GU.StyleRedButton(d.destructBtn)
        d.destructBtn:SetScript("OnClick", function()
            addon.MI_Guild_UnlinkChar(name); addon.MI_GuildPanel_Refresh()
        end)
    end
    d.destructBtn:Show()
end

-- ---------------------------------------------------------------------------------
-- Section builder (called once from GuildPanel.lua:BuildPanel)

function P.BuildDetailSection(parent, rightX, listTop)
    local d = P.detail

    d.nameLabel = GU.MakeLabel(parent, GU.FONT, 13, 1, 1, 1)
    d.nameLabel:SetPoint("TOPLEFT", rightX, listTop)
    d.nameLabel:SetWidth(P.PW - P.LEFT_W - 26); d.nameLabel:SetJustifyH("LEFT")
    d.nameLabel:SetText("|cff333333Select a member from the roster|r")

    d.statusLabel = GU.MakeLabel(parent, GU.FONT, 10, 0.6, 0.6, 0.6)
    d.statusLabel:SetPoint("TOPLEFT", rightX, listTop - 18)
    d.statusLabel:SetWidth(P.PW - P.LEFT_W - 26); d.statusLabel:SetJustifyH("LEFT")

    d.nickLabel = GU.MakeLabel(parent, GU.FONT, 9, 0.45, 0.45, 0.45)
    d.nickLabel:SetPoint("TOPLEFT", rightX, listTop - 32)
    d.nickLabel:SetWidth(P.PW - P.LEFT_W - 26 - 68); d.nickLabel:SetJustifyH("LEFT")
    d.nickLabel:Hide()

    d.nickBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    d.nickBtn:SetSize(62, 14); d.nickBtn:SetPoint("TOPRIGHT", -6, listTop - 32)
    GU.StyleGoldButton(d.nickBtn)
    d.nickBtn.lbl = GU.MakeLabel(d.nickBtn, GU.FONT, 8, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    d.nickBtn.lbl:SetAllPoints(); d.nickBtn.lbl:SetJustifyH("CENTER")
    d.nickBtn:Hide()

    d.noteLabel = GU.MakeLabel(parent, GU.FONT, 9, 0.55, 0.55, 0.55)
    d.noteLabel:SetPoint("TOPLEFT", rightX, listTop - 46)
    d.noteLabel:SetWidth(P.PW - P.LEFT_W - 26); d.noteLabel:SetJustifyH("LEFT")

    d.lastSeenLabel = GU.MakeLabel(parent, GU.FONT, 9, 0.45, 0.45, 0.45)
    d.lastSeenLabel:SetPoint("TOPLEFT", rightX, listTop - 66)
    d.lastSeenLabel:SetWidth(P.PW - P.LEFT_W - 26); d.lastSeenLabel:SetJustifyH("LEFT")

    d.joinLabel = GU.MakeLabel(parent, GU.FONT, 9, 0.45, 0.45, 0.45)
    d.joinLabel:SetPoint("TOPLEFT", rightX, listTop - 80)
    d.joinLabel:SetWidth(P.PW - P.LEFT_W - 26 - 68); d.joinLabel:SetJustifyH("LEFT")

    d.joinEditBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    d.joinEditBtn:SetSize(62, 14); d.joinEditBtn:SetPoint("TOPRIGHT", -6, listTop - 80)
    GU.StyleGoldButton(d.joinEditBtn)
    d.joinEditBtn.lbl = GU.MakeLabel(d.joinEditBtn, GU.FONT, 8, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    d.joinEditBtn.lbl:SetAllPoints(); d.joinEditBtn.lbl:SetJustifyH("CENTER")
    d.joinEditBtn.lbl:SetText("Edit Date")
    d.joinEditBtn:Hide()

    d.rolesHdr = GU.MakeLabel(parent, GU.FONT, 9, 0.40, 0.33, 0.10)
    d.rolesHdr:SetPoint("TOPLEFT", rightX, listTop - 96)
    d.rolesHdr:SetText("ROLES:"); d.rolesHdr:Hide()

    local function MakeRoleCB(label, xOffset)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(16, 16); cb:SetPoint("TOPLEFT", rightX + xOffset, listTop - 96)
        cb:Hide()
        local lbl = parent:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(GU.FONT, 10, ""); lbl:SetTextColor(0.7, 0.7, 0.7, 1)
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0); lbl:SetText(label)
        cb.roleLbl = lbl
        return cb
    end
    d.roleTankCB = MakeRoleCB("Tank",   46)
    d.roleHealCB = MakeRoleCB("Healer", 104)
    d.roleDpsCB  = MakeRoleCB("DPS",    170)

    d.inactiveLabel = GU.MakeLabel(parent, GU.FONT_HDR, 10, 1, 0.5, 0, 1)
    d.inactiveLabel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, listTop)
    d.inactiveLabel:SetWidth(80); d.inactiveLabel:SetJustifyH("RIGHT")
    d.inactiveLabel:Hide()

    local linkedHdr = GU.MakeLabel(parent, GU.FONT, 9, 0.50, 0.42, 0.12)
    linkedHdr:SetPoint("TOPLEFT", rightX, listTop - 128)
    linkedHdr:SetText("LINKED CHARACTERS")

    local linkedSep = parent:CreateTexture(nil, "ARTWORK")
    linkedSep:SetHeight(1)
    linkedSep:SetPoint("TOPLEFT",  rightX, listTop - 139)
    linkedSep:SetPoint("TOPRIGHT", -6,     listTop - 139)
    linkedSep:SetColorTexture(0.30, 0.24, 0.06, 0.45)

    P.linkedScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildLinkedScroll", parent)
    P.linkedScroll:SetPoint("TOPLEFT", rightX, listTop - 143)
    P.linkedScroll:SetWidth(P.PW - P.LEFT_W - 26)
    P.linkedScroll:SetHeight(P.ROW_H * 4)
    P.linkedScroll:EnableMouseWheel(true)
    P.linkedScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll(); local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * P.ROW_H * 3)))
    end)

    P.linkedChild = CreateFrame("Frame", nil, P.linkedScroll)
    P.linkedChild:SetWidth(P.PW - P.LEFT_W - 36); P.linkedChild:SetHeight(20)
    P.linkedScroll:SetScrollChild(P.linkedChild)
    GU.MakeScrollbar(P.linkedScroll, P.linkedChild, 12)

    d.actionBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    d.actionBtn:SetSize(P.PW - P.LEFT_W - 26 - 96 - 8, 20)
    GU.StyleGoldButton(d.actionBtn)
    d.actionBtn.lbl = GU.MakeLabel(d.actionBtn, GU.FONT, 10, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    d.actionBtn.lbl:SetAllPoints(); d.actionBtn.lbl:SetJustifyH("CENTER")
    d.actionBtn:Hide()

    d.destructBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    d.destructBtn:SetSize(90, 20)
    GU.StyleRedButton(d.destructBtn)
    d.destructBtn.lbl = GU.MakeLabel(d.destructBtn, GU.FONT, 10, GU.RED_R, GU.RED_G, GU.RED_B)
    d.destructBtn.lbl:SetAllPoints(); d.destructBtn.lbl:SetJustifyH("CENTER")
    d.destructBtn:Hide()
end
