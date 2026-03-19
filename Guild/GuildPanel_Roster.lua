local _, addon = ...

local P  = addon.GuildPanel
local GU = addon.GuildUI

local rosterRows = {}

-- ---------------------------------------------------------------------------------
-- Row pool

local function GetOrCreateRosterRow(i)
    if rosterRows[i] then return rosterRows[i] end

    local row = CreateFrame("Frame", nil, P.rosterChild)
    row:SetHeight(P.ROW_H)

    local colorBar = row:CreateTexture(nil, "ARTWORK")
    colorBar:SetWidth(3)
    colorBar:SetPoint("TOPLEFT", 0, 0); colorBar:SetPoint("BOTTOMLEFT", 0, 0)
    colorBar:SetColorTexture(0.65, 0.65, 0.65, 0.5)
    row.colorBar = colorBar

    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(); hl:SetColorTexture(0.25, 0.2, 0.05, 0); row.hl = hl

    row.levelLabel = GU.MakeLabel(row, GU.FONT, 9, 0.55, 0.55, 0.55)
    row.levelLabel:SetPoint("LEFT", 4, 0)
    row.levelLabel:SetWidth(22)
    row.levelLabel:SetJustifyH("RIGHT")

    local collapseBtn = CreateFrame("Button", nil, row)
    collapseBtn:SetSize(13, P.ROW_H)
    collapseBtn:SetPoint("LEFT", 27, 0)
    collapseBtn:Hide()
    local collapseLbl = collapseBtn:CreateFontString(nil, "OVERLAY")
    collapseLbl:SetFont(GU.FONT, 9, "")
    collapseLbl:SetTextColor(0.7, 0.6, 0.3, 1)
    collapseLbl:SetAllPoints()
    collapseLbl:SetJustifyH("CENTER")
    collapseBtn.lbl = collapseLbl
    row.collapseBtn = collapseBtn

    row.nameLabel = GU.MakeLabel(row, GU.FONT, 11)
    row.nameLabel:SetPoint("LEFT", 41, 0)
    row.nameLabel:SetPoint("RIGHT", -110, 0)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetWordWrap(false)

    local function MakeRoleIcon(xOff)
        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetSize(12, 12); tex:Hide()
        tex:SetPoint("RIGHT", row, "RIGHT", xOff, 0)
        return tex
    end
    row.roleIconTank = MakeRoleIcon(-94)
    row.roleIconHeal = MakeRoleIcon(-80)
    row.roleIconDps  = MakeRoleIcon(-66)

    row.inactiveMark = GU.MakeLabel(row, GU.FONT_HDR, 9, 1, 0.5, 0, 1)
    row.inactiveMark:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    row.inactiveMark:SetWidth(14)
    row.inactiveMark:SetJustifyH("CENTER")
    row.inactiveMark:Hide()

    row.statusLabel = GU.MakeLabel(row, GU.FONT, 9)
    row.statusLabel:SetPoint("RIGHT", -4, 0)
    row.statusLabel:SetWidth(64)
    row.statusLabel:SetJustifyH("RIGHT")

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self.entryName ~= P.selectedName then
            self.hl:SetColorTexture(0.22, 0.18, 0.04, 0.12)
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.entryName ~= P.selectedName then
            self.hl:SetColorTexture(0, 0, 0, 0)
        end
    end)
    row:SetScript("OnMouseUp", function(self, btn)
        if not self.entryName then return end
        if btn == "RightButton" then P.ShowRosterContextMenu(self.entryName); return end
        P.selectedName = self.entryName
        for _, r in ipairs(rosterRows) do r.hl:SetColorTexture(0, 0, 0, 0) end
        self.hl:SetColorTexture(0.28, 0.22, 0.05, 0.25)
        addon.MI_GuildPanel_UpdateDetail(P.selectedName)
    end)

    rosterRows[i] = row
    return row
end

-- ---------------------------------------------------------------------------------
-- Context menu

function P.ShowRosterContextMenu(charName)
    local _, group = addon.MI_Guild_GetGroupForChar(charName)
    MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
        rootDescription:CreateTitle(charName)
        rootDescription:CreateButton("Set as Main", function()
            addon.MI_Guild_SetAsMain(charName)
            addon.MI_GuildPanel_Refresh()
        end)
        rootDescription:CreateButton("Link as Alt to...", function()
            P.ShowInputDialog("Link " .. charName .. " as alt of:", function(main)
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
-- Entry builder + sort

local function BuildRosterEntries(filter)
    local entries = {}
    local lowerF  = filter and filter:lower() or ""
    for i = 1, GetNumGuildMembers() do
        local name, rankName, rankIndex, level, _, _, _, _, isOnline, _, classToken = GetGuildRosterInfo(i)
        if name then
            local _, group, isMain = addon.MI_Guild_GetGroupForChar(name)
            local charData = P.GetCharData(name)
            local matches = lowerF == ""
                or name:lower():find(lowerF, 1, true)
                or (group and group.main:lower():find(lowerF, 1, true))
                or (group and group.nick and group.nick:lower():find(lowerF, 1, true))
            if matches
                and (P.rosterFilter == "all"
                     or (P.rosterFilter == "mains"    and group and isMain and #group.alts > 0)
                     or (P.rosterFilter == "alts"     and group and not isMain)
                     or (P.rosterFilter == "unlinked" and not group))
                and (not P.onlineOnly or isOnline)
            then
                table.insert(entries, {
                    name       = name,
                    rank       = rankName or "",
                    rankIdx    = rankIndex or 0,
                    group      = group,
                    isMain     = isMain,
                    level      = level or 0,
                    classToken = classToken or "",
                    isOnline   = isOnline,
                    lastSeen   = charData and charData.lastSeen,
                    roles      = charData and charData.roles or "000",
                })
            end
        end
    end

    table.sort(entries, function(a, b)
        if P.sortKey == "level" then
            local la, lb = a.level or 0, b.level or 0
            if la ~= lb then
                if P.sortAsc then return la < lb else return la > lb end
            end
        end
        local ka = a.group and (a.group.main .. "\001" .. (a.isMain and "\000" or a.name)) or a.name
        local kb = b.group and (b.group.main .. "\001" .. (b.isMain and "\000" or b.name)) or b.name
        if P.sortAsc then return ka < kb else return ka > kb end
    end)
    return entries
end

-- ---------------------------------------------------------------------------------
-- Roster list builder

function P.BuildRosterList()
    local filter = P.filterBox and P.filterBox:GetText() or ""
    filter = filter:match("^%s*(.-)%s*$")
    P.rosterEntries = BuildRosterEntries(filter)

    for _, row in ipairs(rosterRows) do
        row:Hide(); row:ClearAllPoints(); row.hl:SetColorTexture(0, 0, 0, 0)
    end

    if not addon.MI_Guild_guildName then
        local row = GetOrCreateRosterRow(1)
        row:SetPoint("TOPLEFT", P.rosterChild, "TOPLEFT", 0, 0); row:SetWidth(P.LEFT_W - 20)
        row.nameLabel:SetText("|cff555555Not in a guild.|r"); row.statusLabel:SetText("")
        row.entryName = nil; row.collapseBtn:Hide(); row.inactiveMark:Hide()
        row.roleIconTank:Hide(); row.roleIconHeal:Hide(); row.roleIconDps:Hide()
        row:Show(); P.rosterChild:SetHeight(P.ROW_H)
        return
    end

    if #P.rosterEntries == 0 then
        local row = GetOrCreateRosterRow(1)
        row:SetPoint("TOPLEFT", P.rosterChild, "TOPLEFT", 0, 0); row:SetWidth(P.LEFT_W - 20)
        row.nameLabel:SetText("|cff444444No members found.|r"); row.statusLabel:SetText("")
        row.entryName = nil; row.collapseBtn:Hide(); row.inactiveMark:Hide()
        row.roleIconTank:Hide(); row.roleIconHeal:Hide(); row.roleIconDps:Hide()
        row:Show(); P.rosterChild:SetHeight(P.ROW_H)
        return
    end

    local yOff = 0
    local rowIdx = 0
    local prevGroupMain = nil

    for _, entry in ipairs(P.rosterEntries) do
        local groupMain = entry.group and entry.group.main
        local skip = P.sortKey == "name" and entry.group and not entry.isMain and P.collapsedMains[entry.group.main]
        if not skip then
            if groupMain ~= prevGroupMain then
                if rowIdx > 0 then yOff = yOff + 3 end
                prevGroupMain = groupMain
            end

            rowIdx = rowIdx + 1
            local row = GetOrCreateRosterRow(rowIdx)
            row:SetPoint("TOPLEFT", P.rosterChild, "TOPLEFT", 0, -yOff)
            row:SetWidth(P.LEFT_W - 20)
            row.entryName = entry.name

            local cr, cg, cb = P.ClassColorRGB(entry.classToken)
            row.colorBar:SetColorTexture(cr, cg, cb, 0.7)
            row.levelLabel:SetText(entry.level > 0 and tostring(entry.level) or "")

            local cc     = P.ClassColor(entry.classToken)
            local indent = (entry.group and not entry.isMain) and "  " or ""
            row.nameLabel:SetText(indent .. cc .. entry.name .. "|r")

            local hasAlts = entry.group and #entry.group.alts > 0
            if P.sortKey == "name" and entry.isMain and hasAlts then
                row.collapseBtn:Show()
                row.collapseBtn.lbl:SetText(P.collapsedMains[entry.name] and "[+]" or "[-]")
                row.collapseBtn:SetScript("OnClick", function()
                    P.collapsedMains[entry.name] = not P.collapsedMains[entry.name]
                    P.BuildRosterList()
                end)
            else
                row.collapseBtn:Hide()
            end

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

            if P.IsInactive(entry.lastSeen, entry.group) then
                row.inactiveMark:SetText("⚠"); row.inactiveMark:Show()
            else
                row.inactiveMark:Hide()
            end

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

            if entry.name == P.selectedName then
                row.hl:SetColorTexture(0.28, 0.22, 0.05, 0.25)
            end

            row:Show()
            yOff = yOff + P.ROW_H
        end
    end
    P.rosterChild:SetHeight(math.max(yOff, 100))
end

-- ---------------------------------------------------------------------------------
-- Section builder (called once from GuildPanel.lua:BuildPanel)

function P.BuildRosterSection(parent, contentTop, hdrY, listTop)
    -- Filter radio buttons
    local function UpdateRosterRadios()
        P._radioAll:SetChecked(P.rosterFilter == "all")
        P._radioMains:SetChecked(P.rosterFilter == "mains")
        P._radioAlts:SetChecked(P.rosterFilter == "alts")
        P._radioUnlinked:SetChecked(P.rosterFilter == "unlinked")
        P._onlineOnlyBtn:SetChecked(P.onlineOnly)
    end

    local function MakeRadioOption(label, x)
        local btn = CreateFrame("CheckButton", "MIGuildRadio_" .. label, parent, "UIRadioButtonTemplate")
        btn:SetPoint("TOPLEFT", x, contentTop + 2)
        local lbl = parent:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(GU.FONT, 10, ""); lbl:SetTextColor(0.85, 0.75, 0.45)
        lbl:SetPoint("LEFT", btn, "RIGHT", 2, 0); lbl:SetText(label)
        return btn
    end

    P._radioAll      = MakeRadioOption("All",      4)
    P._radioMains    = MakeRadioOption("Mains",    46)
    P._radioAlts     = MakeRadioOption("Alts",     96)
    P._radioUnlinked = MakeRadioOption("Unlinked", 140)

    P._onlineOnlyBtn = CreateFrame("CheckButton", "MIGuildOnlineOnly", parent, "UICheckButtonTemplate")
    P._onlineOnlyBtn:SetSize(18, 18); P._onlineOnlyBtn:SetPoint("TOPLEFT", 212, contentTop + 1)
    local onlineLbl = parent:CreateFontString(nil, "OVERLAY")
    onlineLbl:SetFont(GU.FONT, 10, ""); onlineLbl:SetTextColor(0.85, 0.75, 0.45)
    onlineLbl:SetPoint("LEFT", P._onlineOnlyBtn, "RIGHT", 2, 0); onlineLbl:SetText("Online Only")

    P._radioAll:SetScript("OnClick", function()
        P.rosterFilter = "all"; UpdateRosterRadios(); P.BuildRosterList()
    end)
    P._radioMains:SetScript("OnClick", function()
        P.rosterFilter = "mains"; UpdateRosterRadios(); P.BuildRosterList()
    end)
    P._radioAlts:SetScript("OnClick", function()
        P.rosterFilter = "alts"; UpdateRosterRadios(); P.BuildRosterList()
    end)
    P._radioUnlinked:SetScript("OnClick", function()
        P.rosterFilter = "unlinked"; UpdateRosterRadios(); P.BuildRosterList()
    end)
    P._onlineOnlyBtn:SetScript("OnClick", function()
        P.onlineOnly = P._onlineOnlyBtn:GetChecked(); P.BuildRosterList()
    end)
    UpdateRosterRadios()

    -- Column sort headers
    local colDefs = {
        { key = "level", label = "Lvl",  x = 4,  w = 36, defaultAsc = false },
        { key = "name",  label = "Name", x = 41, w = 88, defaultAsc = true  },
    }

    local function UpdateSortHeaders()
        for _, def in ipairs(colDefs) do
            local btn = P.sortHeaders[def.key]
            if btn then
                local arrow = (P.sortKey == def.key) and (P.sortAsc and " ▲" or " ▼") or ""
                if P.sortKey == def.key then
                    btn.lbl:SetText("|cffffcc00" .. def.label .. arrow .. "|r")
                else
                    btn.lbl:SetText("|cff555555" .. def.label .. "|r")
                end
            end
        end
    end

    for _, def in ipairs(colDefs) do
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(def.w, 14); btn:SetPoint("TOPLEFT", def.x, hdrY)
        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(GU.FONT_HDR, 9, ""); lbl:SetAllPoints(); lbl:SetJustifyH("LEFT")
        btn.lbl = lbl
        btn:SetScript("OnClick", function()
            if P.sortKey == def.key then
                P.sortAsc = not P.sortAsc
            else
                P.sortKey = def.key
                P.sortAsc = def.defaultAsc
            end
            UpdateSortHeaders(); P.BuildRosterList(); P.rosterScroll:SetVerticalScroll(0)
        end)
        P.sortHeaders[def.key] = btn
    end
    UpdateSortHeaders()

    -- Roster scroll area
    P.rosterScroll = CreateFrame("ScrollFrame", "MysteriousQoL_GuildRosterScroll", parent)
    P.rosterScroll:SetPoint("TOPLEFT",    4, listTop)
    P.rosterScroll:SetPoint("BOTTOMLEFT", 4, 2)
    P.rosterScroll:SetWidth(P.LEFT_W)
    P.rosterScroll:EnableMouseWheel(true)
    P.rosterScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll(); local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * P.ROW_H * 3)))
    end)

    P.rosterChild = CreateFrame("Frame", nil, P.rosterScroll)
    P.rosterChild:SetWidth(P.LEFT_W - 4); P.rosterChild:SetHeight(100)
    P.rosterScroll:SetScrollChild(P.rosterChild)
    GU.MakeScrollbar(P.rosterScroll, P.rosterChild, 16)
end
