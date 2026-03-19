local _, addon = ...

local P  = addon.GuildPanel
local GU = addon.GuildUI

local syncPopupRows     = {}
local syncPopupNoPeers  = nil
local syncPopupLeaderLbl = nil
local syncPopupAllBtn   = nil

-- ---------------------------------------------------------------------------------

function P.RefreshSyncPopup()
    if not P.syncPopup or not P.syncPopup:IsShown() then return end

    local peers    = addon.MI_GuildSync_GetPeerStatuses and addon.MI_GuildSync_GetPeerStatuses() or {}
    local isLeader = addon.MI_GuildSync_IsLeader and addon.MI_GuildSync_IsLeader() or false
    local leader   = addon.MI_GuildSync_GetLeader and addon.MI_GuildSync_GetLeader() or nil

    if isLeader then
        syncPopupLeaderLbl:SetText("|cff44aa44You are the sync leader|r")
    elseif leader then
        syncPopupLeaderLbl:SetText("Leader: |cffffcc00" .. leader .. "|r")
    else
        syncPopupLeaderLbl:SetText("|cff666666No leader elected|r")
    end

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
            local row = CreateFrame("Frame", nil, P.syncPopup)
            row:SetHeight(ROW_H_P)

            local sep = row:CreateTexture(nil, "BACKGROUND")
            sep:SetHeight(1); sep:SetPoint("TOPLEFT", 4, 0); sep:SetPoint("TOPRIGHT", -4, 0)
            sep:SetColorTexture(0.22, 0.18, 0.04, 0.3)

            row.nameLbl = GU.MakeLabel(row, GU.FONT, 10)
            row.nameLbl:SetPoint("LEFT", 8, -1); row.nameLbl:SetPoint("RIGHT", -82, -1)
            row.nameLbl:SetJustifyH("LEFT")

            row.statusLbl = GU.MakeLabel(row, GU.FONT, 9)
            row.statusLbl:SetPoint("RIGHT", -4, -1)
            row.statusLbl:SetWidth(74); row.statusLbl:SetJustifyH("RIGHT")

            local syncBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
            syncBtn:SetSize(58, 15); syncBtn:SetPoint("RIGHT", -4, -1)
            GU.StyleGoldButton(syncBtn)
            local syncLbl = GU.MakeLabel(syncBtn, GU.FONT, 9, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
            syncLbl:SetAllPoints(); syncLbl:SetJustifyH("CENTER"); syncLbl:SetText("Sync →")
            row.syncBtn = syncBtn
            syncPopupRows[i] = row
        end

        local row  = syncPopupRows[i]
        local peer = peers[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  P.syncPopup, "TOPLEFT",  0, -(56 + (i - 1) * ROW_H_P))
        row:SetPoint("TOPRIGHT", P.syncPopup, "TOPRIGHT", 0, -(56 + (i - 1) * ROW_H_P))

        local rankSuffix = peer.rankName ~= "" and (" |cff777777" .. peer.rankName .. "|r") or ""
        row.nameLbl:SetText(peer.name .. rankSuffix)

        if peer.status == "synced" then
            row.statusLbl:SetText("|cff44aa44✓ Synced|r"); row.syncBtn:Hide(); row.statusLbl:Show()
        elseif peer.status == "stale" then
            row.statusLbl:SetText("|cffcc8833⚠ Stale|r")
            if isLeader then
                row.syncBtn:Show(); row.statusLbl:Hide()
                local peerMaxMod = peer.maxModified or 0
                local peerName   = peer.name
                row.syncBtn:SetScript("OnClick", function()
                    addon.MI_GuildSync_BroadcastDelta(peerMaxMod, peerName)
                end)
            else
                row.syncBtn:Hide(); row.statusLbl:Show()
            end
        else
            row.statusLbl:SetText("|cff666666? Unknown|r"); row.statusLbl:Show(); row.syncBtn:Hide()
        end
        row:Show()
    end
    for i = N + 1, #syncPopupRows do syncPopupRows[i]:Hide() end

    if N == 0 then syncPopupNoPeers:Show() else syncPopupNoPeers:Hide() end

    local peerH  = math.max(N, 1) * ROW_H_P
    local totalH = 56 + peerH + (isLeader and hasStale and 34 or 8)
    P.syncPopup:SetHeight(totalH)
    if syncPopupAllBtn then
        syncPopupAllBtn:ClearAllPoints()
        syncPopupAllBtn:SetPoint("BOTTOM", P.syncPopup, "BOTTOM", 0, 8)
    end
end

-- ---------------------------------------------------------------------------------

function P.BuildSyncPopup()
    if P.syncPopup then return end

    P.syncPopup = CreateFrame("Frame", "MysteriousQoL_SyncPopup", UIParent, "BackdropTemplate")
    P.syncPopup:SetWidth(300)
    P.syncPopup:SetPoint("TOPLEFT", P.frame, "TOPRIGHT", 4, 0)
    P.syncPopup:SetFrameStrata("HIGH")
    P.syncPopup:SetFrameLevel(P.frame:GetFrameLevel() + 5)
    P.syncPopup:SetBackdrop(GU.MakeBackdrop())
    P.syncPopup:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    P.syncPopup:SetBackdropBorderColor(0.45, 0.35, 0.08, 0.8)
    P.syncPopup:Hide()

    table.insert(UISpecialFrames, "MysteriousQoL_SyncPopup")

    local accent = P.syncPopup:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(0.75, 0.60, 0.12, 1)

    local titleLbl = GU.MakeLabel(P.syncPopup, GU.FONT, 11, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    titleLbl:SetPoint("TOPLEFT", 8, -8); titleLbl:SetText("Guild Sync")

    local closeBtn = CreateFrame("Button", nil, P.syncPopup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() P.syncPopup:Hide() end)

    syncPopupLeaderLbl = GU.MakeLabel(P.syncPopup, GU.FONT, 10, 0.65, 0.65, 0.65)
    syncPopupLeaderLbl:SetPoint("TOPLEFT", 8, -26)

    local sectionHdr = GU.MakeLabel(P.syncPopup, GU.FONT, 9, 0.50, 0.42, 0.12)
    sectionHdr:SetPoint("TOPLEFT", 8, -42); sectionHdr:SetText("PEERS")

    syncPopupNoPeers = GU.MakeLabel(P.syncPopup, GU.FONT, 10, 0.4, 0.4, 0.4)
    syncPopupNoPeers:SetPoint("TOPLEFT", 12, -58); syncPopupNoPeers:SetText("No peers online")
    syncPopupNoPeers:Hide()

    syncPopupAllBtn = CreateFrame("Button", nil, P.syncPopup, "BackdropTemplate")
    syncPopupAllBtn:SetSize(130, 22)
    GU.StyleGoldButton(syncPopupAllBtn)
    local allLbl = GU.MakeLabel(syncPopupAllBtn, GU.FONT, 10, GU.GOLD_R, GU.GOLD_G, GU.GOLD_B)
    allLbl:SetAllPoints(); allLbl:SetJustifyH("CENTER"); allLbl:SetText("Sync All Stale")
    syncPopupAllBtn:Hide()
end
