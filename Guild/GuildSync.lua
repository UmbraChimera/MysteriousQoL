local _, addon = ...

local SYNC_PREFIX = "MQOL_GUILD"
local sendQueue = {}
local sendTicker = nil
local debugMode  = false

local function SyncPrint(msg)
    print("|cff88ccff[GuildSync]|r " .. msg)
end

-- Escape pipe characters so WoW's print() doesn't interpret them as color codes.
local function EscapeMsg(s)
    return s:gsub("|", "||")
end

function addon.MI_GuildSync_ToggleDebug()
    debugMode = not debugMode
    SyncPrint(debugMode and "|cff44ff44Debug ON|r" or "|cffff4444Debug OFF|r")
end

-- Rank threshold parsed from Guild Info. Cached and refreshed on roster update.
-- rankIndex 0 = GM, 1 = first officer rank, etc. Only members with rankIndex <= threshold may SEND.
-- Anyone may receive and merge data regardless of rank.
local syncRankThreshold = 3  -- default: ranks 0-3 may broadcast

addon.MI_GuildSync_rankThreshold = 3
addon.MI_GuildSync_lastBroadcast = 0
addon.MI_GuildSync_lastReceive   = 0
addon.MI_GuildSync_peerStatus    = {}  -- bare name -> "ok" | "diff"

local function StripRealm(name)
    return name and name:match("^([^%-]+)") or name
end

local function RefreshSyncRankThreshold()
    local info = C_GuildInfo.GetInfoText and C_GuildInfo.GetInfoText() or ""
    local n = info and info:match("%^#MQoL:(%d+)#%^")
    syncRankThreshold = n and tonumber(n) or 3
    addon.MI_GuildSync_rankThreshold = syncRankThreshold
end

-- Sum of all group.modified timestamps — cheap fingerprint of the alt-group dataset.
local function GetDataHash()
    if not addon.MI_Guild_guildName then return 0 end
    if not MysteriousQoLDB.guildData then return 0 end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data then return 0 end
    local h = 0
    for _, group in ipairs(data.altGroups) do
        h = h + (group.modified or 0)
    end
    return h
end

local function FlushQueue()
    if #sendQueue == 0 then
        if sendTicker then sendTicker:Cancel(); sendTicker = nil end
        if debugMode then SyncPrint("Queue drained — send complete.") end
        if addon.MI_GuildSync_onComplete then
            addon.MI_GuildSync_onComplete()
            addon.MI_GuildSync_onComplete = nil
        end
        return
    end
    local msg = table.remove(sendQueue, 1)
    local ok = C_ChatInfo.SendAddonMessage(SYNC_PREFIX, msg, "GUILD")
    if debugMode then
        local status = ok and "|cff44ff44OK|r" or "|cffff4444FAIL|r"
        SyncPrint("SEND [" .. status .. "] len=" .. #msg .. " remain=" .. #sendQueue
            .. "  " .. EscapeMsg(msg:sub(1, 60)))
    elseif not ok then
        -- Always warn on failure even without debug mode
        SyncPrint("|cffff4444Send failed (throttled?)|r len=" .. #msg .. " remain=" .. #sendQueue)
    end
end

-- Returns the rankIndex for a guild member from the local roster, or nil if not found.
local function GetSenderRankIndex(senderName)
    local bare = StripRealm(senderName)
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name and StripRealm(name) == bare then
            return rankIndex
        end
    end
    return nil
end

-- Merge an incoming group into local data using timestamp-wins conflict resolution.
-- When modified matches exactly, append any alts not already present (handles chunked sends).
local function MergeGroup(main, alts, modified)
    if not addon.MI_Guild_guildName then return end
    if not MysteriousQoLDB.guildData then return end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data then return end

    for _, group in ipairs(data.altGroups) do
        if group.main == main then
            -- Always append any alts we don't already have.
            local have = {}
            for _, a in ipairs(group.alts) do have[a] = true end
            local added = 0
            for _, a in ipairs(alts) do
                if not have[a] then
                    table.insert(group.alts, a)
                    added = added + 1
                end
            end
            if modified > group.modified then
                group.modified = modified
            end
            if debugMode then
                if added > 0 then
                    SyncPrint("MERGE " .. main .. " +" .. added .. " alts")
                else
                    local stored = table.concat(group.alts, ", ")
                    SyncPrint("SKIP (alt exists) " .. main .. " incoming=[" .. EscapeMsg(table.concat(alts, ", ")) .. "] stored=[" .. EscapeMsg(stored) .. "]")
                end
            end
            return
        end
    end
    if debugMode then
        SyncPrint("MERGE (new) " .. main .. " alts=" .. #alts)
    end
    table.insert(data.altGroups, { main = main, alts = alts, modified = modified })
end

local syncFrame = CreateFrame("Frame")
local lastHelloTime = 0

local function OnAddonMessage(_, event, prefix, msg, channel, sender)
    if prefix ~= SYNC_PREFIX then return end
    if channel ~= "GUILD" then return end
    if StripRealm(sender) == UnitName("player") then return end

    if debugMode then
        SyncPrint("RECV from " .. (sender or "?") .. " len=" .. #msg
            .. "  " .. EscapeMsg(msg:sub(1, 60)))
    end

    -- HELLO: lightweight hash announce. Compare to our hash, record peer status.
    local helloHash = msg:match("^HELLO|v1|(%d+)$")
    if helloHash then
        local bare = StripRealm(sender)
        local myHash = GetDataHash()
        addon.MI_GuildSync_peerStatus[bare] = (tonumber(helloHash) == myHash) and "ok" or "diff"
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
        -- Respond with our hash so the sender can see our status too (throttled).
        if addon.MI_Guild_guildName and addon.db.guild_sync_enabled and time() - lastHelloTime > 60 then
            C_ChatInfo.SendAddonMessage(SYNC_PREFIX, "HELLO|v1|" .. myHash, "GUILD")
            lastHelloTime = time()
        end
        return
    end

    if msg:sub(1, 8) == "SYNC_END" then
        addon.MI_Guild_RebuildIndex()
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
        return
    end

    -- Format: SYNC|v1|main|alt1,alt2,...|modified
    local ver, main, altsStr, modifiedStr = msg:match("^SYNC|([^|]+)|([^|]+)|([^|]*)|(%d+)$")
    if not main or ver ~= "v1" then return end

    local alts = {}
    if altsStr ~= "" then
        for alt in altsStr:gmatch("[^,]+") do
            table.insert(alts, alt)
        end
    end
    MergeGroup(main, alts, tonumber(modifiedStr) or 0)
    addon.MI_GuildSync_lastReceive = time()
end

syncFrame:SetScript("OnEvent", OnAddonMessage)

local function LocalPlayerCanSend()
    local rankIdx = GetSenderRankIndex(UnitName("player"))
    return rankIdx ~= nil and rankIdx <= syncRankThreshold
end

function addon.MI_GuildSync_BroadcastHello()
    if not addon.MI_Guild_guildName then return end
    if not addon.db.guild_sync_enabled then return end
    C_ChatInfo.SendAddonMessage(SYNC_PREFIX, "HELLO|v1|" .. GetDataHash(), "GUILD")
    lastHelloTime = time()
end

function addon.MI_GuildSync_Broadcast()
    if InCombatLockdown() then return end
    if not addon.MI_Guild_guildName then return end
    if not addon.db.guild_sync_enabled then return end
    if not LocalPlayerCanSend() then return end

    local groups = addon.MI_Guild_GetAllGroups()
    for _, g in ipairs(groups) do
        if #g.alts == 0 then
            table.insert(sendQueue, string.format("SYNC|v1|%s||%d", g.main, g.modified))
        else
            for _, alt in ipairs(g.alts) do
                table.insert(sendQueue, string.format("SYNC|v1|%s|%s|%d", g.main, alt, g.modified))
            end
        end
    end
    table.insert(sendQueue, "SYNC_END|v1")

    addon.MI_GuildSync_lastBroadcast = time()

    if debugMode then
        SyncPrint("Broadcasting " .. #groups .. " group(s) — queue=" .. #sendQueue)
    end

    if not sendTicker then
        sendTicker = C_Timer.NewTicker(0.25, FlushQueue)
    end
    return #groups
end

function addon.MI_GuildSync_Init()
    C_ChatInfo.RegisterAddonMessagePrefix(SYNC_PREFIX)
    syncFrame:RegisterEvent("CHAT_MSG_ADDON")

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("GUILD_ROSTER_UPDATE")
    f:SetScript("OnEvent", function(self, event, isLogin, isReload)
        if event == "GUILD_ROSTER_UPDATE" then
            RefreshSyncRankThreshold()
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
            RefreshSyncRankThreshold()
            if isLogin and not isReload then
                C_Timer.After(15, addon.MI_GuildSync_BroadcastHello)
                C_Timer.After(60, addon.MI_GuildSync_Broadcast)
            end
        end
    end)
end
