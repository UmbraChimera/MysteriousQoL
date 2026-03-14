local _, addon = ...

-- Attaches a small alt-info popup to CommunitiesFrame when a guild member is clicked.
-- Character-centric: click any linked member to set them as main or manage links.

local FONT    = "Fonts\\FRIZQT__.TTF"
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]

local POPUP_W  = 206
local ROW_H    = 20
local PAD      = 6

local popup        = nil
local rowsScroll, rowsChild
local linkedRows   = {}     -- pool of per-member rows inside the popup
local currentName  = nil    -- bare name being shown
local ShowForMember  -- forward declaration

local MAX_VISIBLE_ROWS = 6

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function MakeBackdrop()
    return {
        bgFile = BAR_TEX, edgeFile = BAR_TEX, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    }
end

local function MakeFS(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 11, "")
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    return fs
end

local function StyleBtn(btn, r, g, b)
    btn:SetBackdrop(MakeBackdrop())
    btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    btn:SetBackdropBorderColor(r, g, b, 0.65)
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(r, g, b, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(r, g, b, 0.65) end)
end

local function MakeBtn(parent, w, label, r, g, b, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, 20)
    StyleBtn(btn, r, g, b)
    local fs = MakeFS(btn, 10, math.min(r * 1.5, 1), math.min(g * 1.5, 1), math.min(b * 1.5, 1))
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetText(label)
    btn.lbl = fs
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

-- ── Autocomplete dialog (reused from GuildPanel pattern) ──────────────────────

local acDialog, acCallback, acAcFrame, acRows, acSuppressAC = nil, nil, nil, {}, false
local AC_MAX = 8
local AC_ROW_H = 20
local AC_BASE_H = 88

local function HideAC()
    if acAcFrame then acAcFrame:Hide() end
    for _, r in ipairs(acRows) do r:Hide() end
    if acDialog then acDialog:SetHeight(AC_BASE_H) end
end

local function GetMatches(filter)
    local results = {}
    filter = filter:lower()
    for i = 1, GetNumGuildMembers() do
        local name, rankName = GetGuildRosterInfo(i)
        if name then
            local bare = name:match("^([^%-]+)")
            if bare:lower():find(filter, 1, true) then
                table.insert(results, { name = bare, rank = rankName or "" })
            end
        end
    end
    table.sort(results, function(a, b) return a.name < b.name end)
    if #results > AC_MAX then
        local t = {}
        for i = 1, AC_MAX do t[i] = results[i] end
        return t
    end
    return results
end

local function UpdateAC(text)
    if not acAcFrame then return end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then HideAC(); return end
    local results = GetMatches(text)
    if #results == 0 then HideAC(); return end

    for i = 1, #results do
        if not acRows[i] then
            local row = CreateFrame("Button", nil, acAcFrame)
            row:SetHeight(AC_ROW_H)
            row:SetPoint("LEFT", 0, 0)
            row:SetPoint("RIGHT", 0, 0)
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0); row.bg = bg
            local nl = MakeFS(row, 11); nl:SetPoint("LEFT", 8, 0)
            nl:SetPoint("RIGHT", -60, 0); nl:SetJustifyH("LEFT"); row.nl = nl
            local rl = MakeFS(row, 9, 0.45, 0.45, 0.45)
            rl:SetPoint("RIGHT", -4, 0); rl:SetJustifyH("RIGHT"); row.rl = rl
            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.22, 0.18, 0.04, 0.35)
                self.nl:SetTextColor(1, 0.88, 0.3, 1)
            end)
            row:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0, 0, 0, 0)
                self.nl:SetTextColor(1, 1, 1, 1)
            end)
            row:SetScript("OnClick", function(self)
                acSuppressAC = true
                acDialog.eb:SetText(self.memberName)
                acSuppressAC = false
                HideAC()
                acDialog.eb:SetCursorPosition(#self.memberName)
            end)
            acRows[i] = row
        end
    end
    for i, data in ipairs(results) do
        local row = acRows[i]
        row:SetPoint("TOPLEFT", acAcFrame, "TOPLEFT", 0, -(i - 1) * AC_ROW_H)
        row.memberName = data.name
        row.nl:SetText(data.name); row.rl:SetText(data.rank); row:Show()
    end
    for i = #results + 1, #acRows do acRows[i]:Hide() end
    local h = #results * AC_ROW_H
    acAcFrame:SetHeight(h); acAcFrame:Show()
    acDialog:SetHeight(AC_BASE_H + h + 2)
end

local function BuildAcDialog()
    if acDialog then return end
    acDialog = CreateFrame("Frame", "MysteriousQoL_CommAcInput", UIParent, "BackdropTemplate")
    acDialog:SetSize(260, AC_BASE_H)
    acDialog:SetPoint("CENTER")
    acDialog:SetFrameStrata("FULLSCREEN_DIALOG")
    acDialog:SetBackdrop(MakeBackdrop())
    acDialog:SetBackdropColor(0.07, 0.07, 0.07, 0.98)
    acDialog:SetBackdropBorderColor(0.55, 0.44, 0.12, 1)
    acDialog:Hide()

    acDialog.title = MakeFS(acDialog, 11, 0.9, 0.76, 0.22)
    acDialog.title:SetPoint("TOPLEFT", 8, -8)

    local eb = CreateFrame("EditBox", nil, acDialog, "BackdropTemplate")
    eb:SetSize(242, 22); eb:SetPoint("TOP", 0, -28)
    eb:SetFont(FONT, 11, ""); eb:SetTextColor(1, 1, 1, 1)
    eb:SetAutoFocus(true)
    eb:SetBackdrop(MakeBackdrop())
    eb:SetBackdropColor(0.04, 0.04, 0.04, 1)
    eb:SetBackdropBorderColor(0.40, 0.32, 0.08, 0.8)
    eb:SetScript("OnTextChanged", function()
        if acSuppressAC then return end
        UpdateAC(eb:GetText())
    end)
    eb:SetScript("OnEnterPressed", function()
        local t = eb:GetText():match("^%s*(.-)%s*$")
        if t ~= "" and acCallback then acCallback(t) end
        acDialog:Hide()
    end)
    eb:SetScript("OnEscapePressed", function() acDialog:Hide() end)
    acDialog.eb = eb

    acAcFrame = CreateFrame("Frame", nil, acDialog, "BackdropTemplate")
    acAcFrame:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, -2)
    acAcFrame:SetPoint("TOPRIGHT", eb, "BOTTOMRIGHT", 0, -2)
    acAcFrame:SetHeight(0)
    acAcFrame:SetFrameLevel(acDialog:GetFrameLevel() + 5)
    acAcFrame:SetBackdrop(MakeBackdrop())
    acAcFrame:SetBackdropColor(0.08, 0.07, 0.03, 0.97)
    acAcFrame:SetBackdropBorderColor(0.35, 0.28, 0.07, 0.6)
    acAcFrame:Hide()

    local ok = MakeBtn(acDialog, 70, "OK", 0.50, 0.40, 0.09, function()
        local t = eb:GetText():match("^%s*(.-)%s*$")
        if t ~= "" and acCallback then acCallback(t) end
        acDialog:Hide()
    end)
    ok:SetPoint("BOTTOMLEFT", 8, 8)

    local cancel = MakeBtn(acDialog, 70, "Cancel", 0.5, 0.1, 0.1,
        function() acDialog:Hide() end)
    cancel:SetPoint("BOTTOMRIGHT", -8, 8)
end

local function ShowAcDialog(title, callback)
    BuildAcDialog()
    acDialog.title:SetText(title)
    acSuppressAC = true; acDialog.eb:SetText(""); acSuppressAC = false
    HideAC()
    acCallback = callback
    C_GuildInfo.GuildRoster()
    acDialog:Show()
    acDialog.eb:SetFocus()
end

-- ── Member info lookup ─────────────────────────────────────────────────────────

local function GetGuildMemberInfo(charName)
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, classDisplay, _, _, _, _, _, classToken = GetGuildRosterInfo(i)
        if name and name:match("^([^%-]+)") == charName then
            return level or 0, classDisplay or "", classToken or ""
        end
    end
    return 0, "", ""
end

local function ClassColor(classToken)
    local c = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
    if c then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
end

-- ── Popup frame ───────────────────────────────────────────────────────────────

local function GetOrCreateLinkedRow(i)
    if linkedRows[i] then return linkedRows[i] end

    local row = CreateFrame("Frame", nil, rowsChild)
    row:SetHeight(ROW_H)

    -- Highlight texture (hover / current-member)
    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(); hl:SetColorTexture(0.25, 0.2, 0.05, 0); row.hl = hl

    row.nameLabel = MakeFS(row, 11)
    row.nameLabel:SetPoint("LEFT", PAD, 0)
    row.nameLabel:SetPoint("RIGHT", -70, 0)
    row.nameLabel:SetJustifyH("LEFT")

    -- "Set Main" button (shown for non-main members)
    row.setMainBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.setMainBtn:SetSize(62, 16)
    row.setMainBtn:SetPoint("RIGHT", -PAD, 0)
    StyleBtn(row.setMainBtn, 0.50, 0.40, 0.09)
    local smL = MakeFS(row.setMainBtn, 9, 0.9, 0.76, 0.22)
    smL:SetAllPoints(); smL:SetJustifyH("CENTER"); smL:SetText("Set Main")
    row.setMainBtn.lbl = smL
    -- OnClick set at populate time via row.charName
    row.setMainBtn:SetScript("OnClick", function()
        if not row.charName then return end
        addon.MI_Guild_SetAsMain(row.charName)
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
        -- re-show popup for same member, now with updated data
        if currentName then ShowForMember(currentName) end
    end)

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) self.hl:SetColorTexture(0.22, 0.18, 0.04, 0.2) end)
    row:SetScript("OnLeave", function(self) self.hl:SetColorTexture(0.25, 0.2, 0.05, 0) end)

    linkedRows[i] = row
    return row
end

local function BuildPopup()
    if popup then return end

    popup = CreateFrame("Frame", "MysteriousQoL_CommPop", UIParent, "BackdropTemplate")
    popup:SetWidth(POPUP_W)
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetBackdrop(MakeBackdrop())
    popup:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    popup:SetBackdropBorderColor(0.45, 0.35, 0.08, 0.8)
    popup:Hide()

    -- Top accent
    local accent = popup:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(0.75, 0.60, 0.12, 1)

    -- Name header
    popup.nameLabel = MakeFS(popup, 12, 1, 1, 1)
    popup.nameLabel:SetPoint("TOPLEFT", PAD, -6)
    popup.nameLabel:SetPoint("TOPRIGHT", -22, -6)
    popup.nameLabel:SetJustifyH("LEFT")

    -- Close button (x)
    local closeBtn = CreateFrame("Button", nil, popup)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    local closeLabel = MakeFS(closeBtn, 11, 0.5, 0.5, 0.5)
    closeLabel:SetAllPoints(); closeLabel:SetJustifyH("CENTER")
    closeLabel:SetText("x")
    closeBtn:SetScript("OnEnter", function() closeLabel:SetTextColor(1, 0.3, 0.3, 1) end)
    closeBtn:SetScript("OnLeave", function() closeLabel:SetTextColor(0.5, 0.5, 0.5, 1) end)
    closeBtn:SetScript("OnClick", function() popup:Hide(); currentName = nil end)

    -- Status line (Main / Alt of X / Not linked)
    popup.statusLabel = MakeFS(popup, 10, 0.6, 0.6, 0.6)
    popup.statusLabel:SetPoint("TOPLEFT", PAD, -22)

    -- Section separator
    popup.sep1 = popup:CreateTexture(nil, "ARTWORK")
    popup.sep1:SetHeight(1)
    popup.sep1:SetPoint("TOPLEFT", 3, -34)
    popup.sep1:SetPoint("TOPRIGHT", -3, -34)
    popup.sep1:SetColorTexture(0.30, 0.24, 0.06, 0.5)

    -- "Linked Characters" section label
    popup.sectionLabel = MakeFS(popup, 9, 0.50, 0.42, 0.12)
    popup.sectionLabel:SetPoint("TOPLEFT", PAD, -40)

    -- Scrollable rows area (height set at populate time)
    rowsScroll = CreateFrame("ScrollFrame", nil, popup)
    rowsScroll:SetPoint("TOPLEFT", PAD - 2, -46)
    rowsScroll:SetWidth(POPUP_W - PAD * 2 + 2 - 6)
    rowsScroll:SetHeight(ROW_H)
    rowsScroll:EnableMouseWheel(true)
    rowsScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_H * 2)))
    end)
    rowsChild = CreateFrame("Frame", nil, rowsScroll)
    rowsChild:SetWidth(POPUP_W - PAD * 2 + 2 - 6)
    rowsChild:SetHeight(ROW_H)
    rowsScroll:SetScrollChild(rowsChild)

    -- Minimal scrollbar
    local sbTrack = CreateFrame("Frame", nil, popup)
    sbTrack:SetWidth(5)
    sbTrack:SetPoint("TOPLEFT", rowsScroll, "TOPRIGHT", 1, 0)
    sbTrack:SetPoint("BOTTOMLEFT", rowsScroll, "BOTTOMRIGHT", 1, 0)
    local sbBg = sbTrack:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints(); sbBg:SetColorTexture(0.12, 0.10, 0.03, 0.35)
    local sbThumb = sbTrack:CreateTexture(nil, "OVERLAY")
    sbThumb:SetWidth(4); sbThumb:SetColorTexture(0.55, 0.44, 0.10, 0.75); sbThumb:Hide()
    local function UpdateScrollbar()
        local childH = rowsChild:GetHeight()
        local viewH  = rowsScroll:GetHeight()
        if childH <= viewH then sbThumb:Hide(); return end
        sbThumb:Show()
        local trackH = sbTrack:GetHeight()
        if trackH <= 0 then return end
        local thumbH = math.max(10, trackH * viewH / childH)
        sbThumb:SetHeight(thumbH)
        local maxScroll = rowsScroll:GetVerticalScrollRange()
        local cur       = rowsScroll:GetVerticalScroll()
        local ratio     = maxScroll > 0 and (cur / maxScroll) or 0
        sbThumb:ClearAllPoints()
        sbThumb:SetPoint("TOPLEFT", sbTrack, "TOPLEFT", 0, -ratio * (trackH - thumbH))
    end
    rowsScroll:HookScript("OnVerticalScroll", UpdateScrollbar)
    rowsScroll:HookScript("OnScrollRangeChanged", UpdateScrollbar)

    -- Bottom button area (height and position set at populate time)
    popup.btn1 = MakeBtn(popup, 90, "", 0.50, 0.40, 0.09)
    popup.btn2 = MakeBtn(popup, 90, "", 0.55, 0.15, 0.15)
end

-- ── Populate popup for a given member ─────────────────────────────────────────

ShowForMember = function(memberName)
    if not addon.db.guild_alts_enabled then return end
    BuildPopup()
    currentName = memberName

    local level, classDisplay, classToken = GetGuildMemberInfo(memberName)
    local cc = ClassColor(classToken)
    local infoStr = (level > 0 and classDisplay ~= "") and
        ("|cff888888" .. level .. " " .. classDisplay .. "|r") or ""

    popup.nameLabel:SetText(cc .. memberName .. "|r")

    -- Hide all linked rows
    for _, row in ipairs(linkedRows) do
        row:Hide(); row:ClearAllPoints()
    end
    popup.btn1:Hide(); popup.btn2:Hide()
    popup.btn1:SetScript("OnClick", nil)
    popup.btn2:SetScript("OnClick", nil)

    local idx, group, isMain = addon.MI_Guild_GetGroupForChar(memberName)

    local rowsY = -46  -- Y offset from popup top where rows start

    if not group then
        -- Not linked
        local suffix = infoStr ~= "" and (infoStr .. "  ") or ""
        popup.statusLabel:SetText(suffix .. "|cff666666Not linked|r")
        popup.sectionLabel:SetText("")
        popup.sep1:Show()

        popup.btn1:SetPoint("TOPLEFT", PAD, rowsY - 4)
        popup.btn1.lbl:SetText("Set as Main")
        popup.btn1:Show()
        popup.btn1:SetScript("OnClick", function()
            addon.MI_Guild_SetAsMain(memberName)
            if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
            ShowForMember(memberName)
        end)

        popup.btn2:SetPoint("TOPRIGHT", -PAD, rowsY - 4)
        popup.btn2.lbl:SetText("Link as Alt...")
        StyleBtn(popup.btn2, 0.50, 0.40, 0.09)
        popup.btn2:Show()
        popup.btn2:SetScript("OnClick", function()
            ShowAcDialog("Link " .. memberName .. " as alt of:", function(mainName)
                addon.MI_Guild_LinkAltToMain(memberName, mainName)
                if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
                ShowForMember(memberName)
            end)
        end)

        popup:SetHeight(86)

    else
        -- In a group
        local prefix = infoStr ~= "" and (infoStr .. "  ") or ""
        if isMain then
            popup.statusLabel:SetText(prefix .. "|cffffcc00Main|r")
        else
            popup.statusLabel:SetText(prefix .. "Alt of |cffffcc00" .. group.main .. "|r")
        end
        popup.sep1:Show()
        popup.sectionLabel:SetText("LINKED CHARACTERS")

        -- Build member list: main first, then alts
        local members = { group.main }
        for _, a in ipairs(group.alts) do table.insert(members, a) end

        local rowIdx = 0
        local yOff = 0
        for _, name in ipairs(members) do
            rowIdx = rowIdx + 1
            local row = GetOrCreateLinkedRow(rowIdx)
            row:SetPoint("TOPLEFT", rowsChild, "TOPLEFT", 0, -yOff)
            row:SetWidth(rowsChild:GetWidth())
            row.charName = name
            local isCurrentMember = (name == memberName)
            local isMn = (name == group.main)

            if isMn then
                row.nameLabel:SetText("|cffffcc00" .. name .. "|r")
            else
                row.nameLabel:SetText(name)
            end
            row.hl:SetColorTexture(0.25, 0.2, 0.05, isCurrentMember and 0.18 or 0)

            if isMn then
                row.setMainBtn:Hide()
            else
                row.setMainBtn:Show()
            end
            row:Show()
            yOff = yOff + ROW_H
        end
        rowsChild:SetHeight(math.max(yOff, ROW_H))

        local visH = math.min(#members, MAX_VISIBLE_ROWS) * ROW_H
        rowsScroll:SetHeight(visH)

        -- Action buttons anchored below the scroll area
        local btnY = -(46 + visH + 6)
        popup.btn1:SetPoint("TOPLEFT", PAD, btnY)
        popup.btn1.lbl:SetText("Link Alt...")
        StyleBtn(popup.btn1, 0.50, 0.40, 0.09)
        popup.btn1:Show()
        popup.btn1:SetScript("OnClick", function()
            ShowAcDialog("Add alt to " .. group.main .. ":", function(altName)
                addon.MI_Guild_LinkAltToMain(altName, group.main)
                if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
                ShowForMember(memberName)
            end)
        end)

        popup.btn2:SetPoint("TOPRIGHT", -PAD, btnY)
        if isMain then
            popup.btn2.lbl:SetText("Delete Group")
            StyleBtn(popup.btn2, 0.55, 0.1, 0.1)
            popup.btn2:SetScript("OnClick", function()
                addon.MI_Guild_DeleteGroup(idx)
                if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
                popup:Hide(); currentName = nil
            end)
        else
            popup.btn2.lbl:SetText("Unlink Me")
            StyleBtn(popup.btn2, 0.55, 0.1, 0.1)
            popup.btn2:SetScript("OnClick", function()
                addon.MI_Guild_UnlinkChar(memberName)
                if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
                ShowForMember(memberName)
            end)
        end
        popup.btn2:Show()

        popup:SetHeight(math.abs(btnY) + 20 + PAD + 8)
    end

    -- Anchor: to the right of GuildMemberDetailFrame when visible,
    -- otherwise to the right of CommunitiesFrame offset downward.
    popup:ClearAllPoints()
    local detailFrame = CommunitiesFrame.GuildMemberDetailFrame
    if detailFrame and detailFrame:IsShown() then
        popup:SetPoint("TOPLEFT", detailFrame, "TOPRIGHT", 4, -10)
    else
        popup:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", 4, -120)
    end
    popup:Show()
end

-- ── Scroll button hooks ────────────────────────────────────────────────────────

local function HookButton(button)
    if button._mqol_hooked then return end
    button._mqol_hooked = true
    button:HookScript("OnClick", function(self, btn)
        if btn ~= "LeftButton" then return end
        local info = self.memberInfo or (self.GetMemberInfo and self:GetMemberInfo())
        local name = info and info.name
        if not name or name == "" then return end
        ShowForMember(name:match("^([^%-]+)") or name)
    end)
end

local mixin_hooked = false

local function HookMixin()
    if mixin_hooked then return end
    if not CommunitiesMemberListEntryMixin then return end
    mixin_hooked = true
    hooksecurefunc(CommunitiesMemberListEntryMixin, "SetMember", function(self)
        HookButton(self)
    end)
    if CommunitiesFrame and CommunitiesFrame.MemberList and CommunitiesFrame.MemberList.ScrollBox then
        CommunitiesFrame.MemberList.ScrollBox:ForEachFrame(HookButton)
    end
end

local tryHookDone = false

local function TryHook()
    if tryHookDone then return end
    if not CommunitiesFrame then return end
    tryHookDone = true

    HookMixin()

    CommunitiesFrame:HookScript("OnHide", function()
        if popup then popup:Hide() end
        currentName = nil
    end)
    local function onTab() if popup then popup:Hide() end; currentName = nil end
    if CommunitiesFrame.RosterTab        then CommunitiesFrame.RosterTab:HookScript("OnClick", onTab) end
    if CommunitiesFrame.ChatTab          then CommunitiesFrame.ChatTab:HookScript("OnClick", onTab) end
    if CommunitiesFrame.GuildBenefitsTab then CommunitiesFrame.GuildBenefitsTab:HookScript("OnClick", onTab) end
    if CommunitiesFrame.GuildInfoTab     then CommunitiesFrame.GuildInfoTab:HookScript("OnClick", onTab) end

    -- "Guild Manager" button pinned to the bottom-right of CommunitiesFrame
    local gmBtn = CreateFrame("Button", "MysteriousQoL_GuildMgrBtn", CommunitiesFrame, "BackdropTemplate")
    gmBtn:SetSize(110, 20)
    gmBtn:SetPoint("BOTTOMLEFT", CommunitiesFrame, "BOTTOMLEFT", 8, 8)
    StyleBtn(gmBtn, 0.50, 0.40, 0.09)
    local gmLbl = MakeFS(gmBtn, 10, 0.9, 0.76, 0.22)
    gmLbl:SetAllPoints(); gmLbl:SetJustifyH("CENTER"); gmLbl:SetText("Guild Manager")
    gmBtn:SetScript("OnClick", function()
        if addon.MI_GuildPanel_Toggle then addon.MI_GuildPanel_Toggle() end
    end)
end

function addon.MI_GuildCommunities_Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name == "Blizzard_Communities" then
            self:UnregisterEvent("ADDON_LOADED")
            TryHook()
        end
    end)
    if CommunitiesFrame then TryHook() end
end
