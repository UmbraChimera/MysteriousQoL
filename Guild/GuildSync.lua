local _, addon = ...

local SYNC_PREFIX = "MQOL_GUILD"
local sendQueue   = {}
local sendTicker  = nil
local debugMode   = false

-- peerInfo[bareName] = { rank=N, maxModified=T, lastHello=T }
-- Tracks every online MQOL user we have heard from.
local peerInfo = {}
local PEER_EXPIRE_SEC = 300  -- 5 minutes without a HELLO = considered offline

-- Timestamp of the last completed outgoing broadcast (full or delta).
local lastBroadcastTimestamp = 0

local function SyncPrint(msg)
    print("|cff88ccff[GuildSync]|r " .. msg)
end

local function EscapeMsg(s)
    return s:gsub("|", "||")
end

function addon.MI_GuildSync_ToggleDebug()
    debugMode = not debugMode
    SyncPrint(debugMode and "|cff44ff44Debug ON|r" or "|cffff4444Debug OFF|r")
end

local function StripRealm(name)
    return name and name:match("^([^%-]+)") or name
end

-- Returns the max "modified" timestamp across all chars in the current guild data.
local function GetMaxModified()
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return 0 end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return 0 end
    local maxMod = 0
    for _, c in pairs(data.chars) do
        if (c.modified or 0) > maxMod then maxMod = c.modified end
    end
    return maxMod
end

-- Fingerprint: charCount|altCount|modifiedSum
local function GetDataHash()
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return "0|0|0" end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return "0|0|0" end
    local charCount, altCount, modSum = 0, 0, 0
    for charName, c in pairs(data.chars) do
        charCount = charCount + 1
        if c.main ~= charName then altCount = altCount + 1 end
        modSum = modSum + (c.modified or 0)
    end
    return charCount .. "|" .. altCount .. "|" .. modSum
end

-- Returns the rank index of the local player (0 = GM). Returns 999 if not found.
local function GetMyRankIndex()
    local me = UnitName("player")
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name and StripRealm(name) == me then return rankIndex end
    end
    return 999
end

-- Prune peers that have not sent a HELLO within PEER_EXPIRE_SEC.
local function PruneExpiredPeers()
    local now = time()
    for name, info in pairs(peerInfo) do
        if (now - (info.lastHello or 0)) > PEER_EXPIRE_SEC then
            peerInfo[name] = nil
        end
    end
end

-- Determine the current leader: the tracked peer (or self) with the lowest rank index.
-- Lowest rank index = highest guild rank. Ties broken by name (alphabetical).
local function GetLeaderName()
    PruneExpiredPeers()
    local myName = UnitName("player")
    local myRank = GetMyRankIndex()
    local leader, leaderRank = myName, myRank

    for bareName, info in pairs(peerInfo) do
        local rank = info.rank or 999
        if rank < leaderRank or (rank == leaderRank and bareName < leader) then
            leader = bareName
            leaderRank = rank
        end
    end
    return leader
end

function addon.MI_GuildSync_GetLeader()
    return GetLeaderName()
end

function addon.MI_GuildSync_IsLeader()
    return GetLeaderName() == UnitName("player")
end

-- ---------------------------------------------------------------------------------
-- Send queue: 1 message/sec to avoid throttle failures.

local function FlushQueue()
    if #sendQueue == 0 then
        if sendTicker then sendTicker:Cancel(); sendTicker = nil end
        if debugMode then SyncPrint("Queue drained.") end
        if addon.MI_GuildSync_onComplete then
            addon.MI_GuildSync_onComplete()
            addon.MI_GuildSync_onComplete = nil
        end
        return
    end
    local entry = table.remove(sendQueue, 1)
    local msg    = entry.msg
    local target = entry.target
    local channel = target and "WHISPER" or "GUILD"
    local ok = C_ChatInfo.SendAddonMessage(SYNC_PREFIX, msg, channel, target)
    if debugMode then
        local status = ok and "|cff44ff44OK|r" or "|cffff4444FAIL|r"
        SyncPrint("SEND [" .. status .. "] " .. channel .. (target and " → " .. target or "")
            .. " len=" .. #msg .. " remain=" .. #sendQueue
            .. "  " .. EscapeMsg(msg:sub(1, 60)))
    elseif not ok then
        SyncPrint("|cffff4444Send failed (throttled?)|r len=" .. #msg)
    end
end

local function Enqueue(msg, target)
    table.insert(sendQueue, { msg = msg, target = target })
    if not sendTicker then
        sendTicker = C_Timer.NewTicker(1.0, FlushQueue)
    end
end

-- ---------------------------------------------------------------------------------
-- Merge incoming char data using timestamp-wins conflict resolution.

local function MergeChar(charName, main, nick, joinDateRaw, roles, modified)
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return end

    local chars = data.chars
    local existing = chars[charName]
    local mod = tonumber(modified) or 0

    if not existing or mod > (existing.modified or 0) then
        local joinDate = (joinDateRaw == "U") and false or (tonumber(joinDateRaw) or false)
        -- Preserve lastSeen from existing (it's local-only, not synced)
        local lastSeen = existing and existing.lastSeen
        -- Keep oldest joinDate
        if existing and existing.joinDate and joinDate and joinDate > existing.joinDate then
            joinDate = existing.joinDate
        end
        chars[charName] = {
            main     = main,
            nick     = (nick ~= "" and nick ~= "nil") and nick or nil,
            joinDate = joinDate,
            lastSeen = lastSeen,
            roles    = (roles ~= "" and roles ~= "nil") and roles or "000",
            modified = mod,
        }
        if debugMode then SyncPrint("MERGE " .. charName .. " → " .. main) end
    elseif debugMode then
        SyncPrint("SKIP " .. charName .. " (local newer: " .. (existing.modified or 0) .. " >= " .. mod .. ")")
    end
end

-- ---------------------------------------------------------------------------------
-- Build outgoing SYNC messages for chars modified since sinceTimestamp.
-- Batches chars into messages up to 250 chars each.
-- Returns the number of chars enqueued, or 0 if nothing to send.

local function EnqueueDelta(sinceTimestamp, target)
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return 0 end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return 0 end

    local pending = {}
    for charName, c in pairs(data.chars) do
        if (c.modified or 0) > sinceTimestamp then
            -- Format: charName~mainName~nick~joinDate~roles~modified
            local nick     = c.nick or ""
            local joinDate = c.joinDate and tostring(c.joinDate) or "U"
            local roles    = c.roles or "000"
            table.insert(pending, charName .. "~" .. c.main .. "~" .. nick
                .. "~" .. joinDate .. "~" .. roles .. "~" .. (c.modified or 0))
        end
    end

    if #pending == 0 then return 0 end

    -- Batch: prefix SYNC|v2| then pipe-separated char records up to 250 chars each.
    local header = "SYNC|v2|"
    local batch, batchLen = {}, #header
    for _, rec in ipairs(pending) do
        local recLen = #rec + 1  -- +1 for the pipe separator
        if batchLen + recLen > 250 and #batch > 0 then
            Enqueue(header .. table.concat(batch, "|"), target)
            batch, batchLen = {}, #header
        end
        table.insert(batch, rec)
        batchLen = batchLen + recLen
    end
    if #batch > 0 then Enqueue(header .. table.concat(batch, "|"), target) end
    Enqueue("SYNC_END|v2", target)

    if debugMode then
        SyncPrint("Delta enqueued " .. #pending .. " chars (since=" .. sinceTimestamp
            .. (target and ", target=" .. target or "") .. ")")
    end
    return #pending
end

-- ---------------------------------------------------------------------------------
-- Public broadcast functions.

function addon.MI_GuildSync_BroadcastHello()
    if not addon.MI_Guild_guildName then return end
    if not addon.db.guild_sync_enabled then return end
    local msg = "HELLO|v2|" .. GetMyRankIndex() .. "|" .. GetDataHash() .. "|" .. GetMaxModified()
    C_ChatInfo.SendAddonMessage(SYNC_PREFIX, msg, "GUILD")
    if debugMode then SyncPrint("HELLO sent rank=" .. GetMyRankIndex()) end
end

-- Full broadcast: sends ALL chars. Only the leader should call this.
function addon.MI_GuildSync_Broadcast()
    if InCombatLockdown() then return end
    if not addon.MI_Guild_guildName then return end
    if not addon.db.guild_sync_enabled then return end
    if not addon.MI_GuildSync_IsLeader() then return end
    local count = EnqueueDelta(0, nil)
    if count > 0 then
        lastBroadcastTimestamp = time()
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    end
    return count
end

-- Delta broadcast toward a specific peer via whisper.
-- sinceTimestamp: send all chars with modified > sinceTimestamp.
function addon.MI_GuildSync_BroadcastDelta(sinceTimestamp, target)
    if InCombatLockdown() then return end
    if not addon.MI_Guild_guildName then return end
    if not addon.db.guild_sync_enabled then return end
    if not addon.MI_GuildSync_IsLeader() then return end
    local count = EnqueueDelta(sinceTimestamp or 0, target)
    if count > 0 then
        if not target then lastBroadcastTimestamp = time() end
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    end
    return count
end

-- ---------------------------------------------------------------------------------
-- Incoming message handler.

local syncFrame = CreateFrame("Frame")

local function OnAddonMessage(_, event, prefix, msg, channel, sender)
    if prefix ~= SYNC_PREFIX then return end
    if channel ~= "GUILD" and channel ~= "WHISPER" then return end
    local senderBare = StripRealm(sender)
    if senderBare == UnitName("player") then return end

    if debugMode then
        SyncPrint("RECV " .. channel .. " from " .. (sender or "?")
            .. "  " .. EscapeMsg(msg:sub(1, 80)))
    end

    -- HELLO|v2|rankIndex|dataHash|maxModified
    local rankStr, hash, maxModStr = msg:match("^HELLO|v2|(%d+)|([^|]+)|(%d+)$")
    if rankStr then
        peerInfo[senderBare] = {
            rank        = tonumber(rankStr) or 999,
            maxModified = tonumber(maxModStr) or 0,
            lastHello   = time(),
            hash        = hash,
        }
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
        return
    end

    -- SYNC_END|v2
    if msg == "SYNC_END|v2" then
        addon.MI_Guild_RebuildIndex()
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
        return
    end

    -- SYNC|v2|rec1|rec2|...  (only accept from current leader)
    local body = msg:match("^SYNC|v2|(.+)$")
    if body then
        local currentLeader = GetLeaderName()
        if senderBare ~= currentLeader then
            if debugMode then SyncPrint("IGNORED (not leader): " .. senderBare .. " vs " .. currentLeader) end
            return
        end
        for rec in body:gmatch("[^|]+") do
            -- Format: charName~mainName~nick~joinDate~roles~modified
            local charName, main, nick, joinDate, roles, modified =
                rec:match("^([^~]+)~([^~]+)~([^~]*)~([^~]+)~([^~]+)~(%d+)$")
            if charName then
                MergeChar(charName, main, nick, joinDate, roles, modified)
            end
        end
        return
    end

    -- Legacy v1 HELLO (ignore gracefully)
    -- Legacy v1 SYNC (ignore; v1 data is incompatible with v2 schema)
end

syncFrame:SetScript("OnEvent", OnAddonMessage)

-- ---------------------------------------------------------------------------------
-- Exported peer status (read by GuildPanel for the sync status UI).

-- Returns a table of { name, rank, status, maxModified } for all known peers.
-- status: "synced" | "stale" | "unknown"
function addon.MI_GuildSync_GetPeerStatuses()
    PruneExpiredPeers()
    local myMax = GetMaxModified()
    local result = {}
    for bareName, info in pairs(peerInfo) do
        local status = "unknown"
        if info.maxModified then
            status = (info.maxModified >= myMax) and "synced" or "stale"
        end
        -- Look up rank name from roster
        local rankName = ""
        for i = 1, GetNumGuildMembers() do
            local n, rn, ri = GetGuildRosterInfo(i)
            if n and StripRealm(n) == bareName then
                rankName = rn or ""
                break
            end
        end
        table.insert(result, {
            name        = bareName,
            rank        = info.rank or 999,
            rankName    = rankName,
            maxModified = info.maxModified or 0,
            status      = status,
        })
    end
    table.sort(result, function(a, b) return (a.rank ~= b.rank) and a.rank < b.rank or a.name < b.name end)
    return result
end

function addon.MI_GuildSync_GetMyMaxModified()
    return GetMaxModified()
end

-- ---------------------------------------------------------------------------------

function addon.MI_GuildSync_Init()
    C_ChatInfo.RegisterAddonMessagePrefix(SYNC_PREFIX)
    syncFrame:RegisterEvent("CHAT_MSG_ADDON")

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(self, event, isLogin, isReload)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
            if isLogin and not isReload then
                C_Timer.After(15, addon.MI_GuildSync_BroadcastHello)
                C_Timer.After(60, function()
                    if addon.MI_GuildSync_IsLeader() then
                        local minPeerMax = math.huge
                        for _, p in ipairs(addon.MI_GuildSync_GetPeerStatuses()) do
                            if p.status == "stale" and p.maxModified < minPeerMax then
                                minPeerMax = p.maxModified
                            end
                        end
                        if minPeerMax ~= math.huge then
                            EnqueueDelta(minPeerMax, nil)
                        end
                    end
                end)
            end
        end
    end)
end
