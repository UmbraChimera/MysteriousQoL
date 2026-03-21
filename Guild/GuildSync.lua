local _, addon = ...

local SYNC_PREFIX     = "MQOL_GUILD"
local sendQueue       = {}
local sendTicker      = nil
local debugMode       = false

-- Alphabetical bucket boundaries — 8 buckets covering A–Z.
local BUCKETS     = { "", "D", "G", "J", "M", "P", "S", "V", "~" }
local NUM_BUCKETS = #BUCKETS - 1  -- 8

-- peerInfo[bareName] = { rank=N, maxModified=T, lastHello=T, buckets={h1..h8} }
local peerInfo        = {}
local PEER_EXPIRE_SEC = 300  -- 5 minutes without a HELLO = considered offline

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

-- Returns the rank index of the local player (0 = GM). Returns 999 if not found.
local function GetMyRankIndex()
    local me = UnitName("player")
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name and StripRealm(name) == me then return rankIndex end
    end
    return 999
end

-- Returns the rank index of any guild member by bare name. Returns 999 if not found.
local function GetRankIndexOf(bareName)
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name and StripRealm(name) == bareName then return rankIndex end
    end
    return 999
end

-- Reads #MQoL:N# from Guild Info text. Default: rank index 1 and above can sync.
local function GetTrustedRankThreshold()
    local info = GetGuildInfoText and GetGuildInfoText() or ""
    local n = info:match("#MQoL:(%d+)#")
    return n and tonumber(n) or 1
end

local function IsTrustedRank(rankIndex)
    return rankIndex <= GetTrustedRankThreshold()
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

-- Determine the current leader: among trusted-rank peers (and self), the one with
-- the highest maxModified. Ties broken by name (alphabetical) for determinism.
local function GetLeaderName()
    PruneExpiredPeers()
    local myName = UnitName("player")
    local myMax  = GetMaxModified()
    local leader, leaderMax

    if IsTrustedRank(GetMyRankIndex()) then
        leader, leaderMax = myName, myMax
    end

    for bareName, info in pairs(peerInfo) do
        if IsTrustedRank(info.rank or 999) then
            local peerMax = info.maxModified or 0
            if not leader or peerMax > leaderMax or (peerMax == leaderMax and bareName < leader) then
                leader    = bareName
                leaderMax = peerMax
            end
        end
    end
    return leader or myName
end

function addon.MI_GuildSync_GetLeader()
    return GetLeaderName()
end

function addon.MI_GuildSync_IsLeader()
    return GetLeaderName() == UnitName("player")
end

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
    local entry   = table.remove(sendQueue, 1)
    local msg     = entry.msg
    local target  = entry.target
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

-- Merge incoming char data using timestamp-wins conflict resolution.

local function MergeChar(charName, main, nick, joinDateRaw, roles, modified)
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return end

    local chars    = data.chars
    local existing = chars[charName]
    local mod      = tonumber(modified) or 0

    if not existing or mod > (existing.modified or 0) then
        local joinDate = (joinDateRaw == "U") and false or (tonumber(joinDateRaw) or false)
        local lastSeen = existing and existing.lastSeen
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

-- SYNC message building helpers.

local function CharRecord(charName, c)
    local nick     = c.nick or ""
    local joinDate = c.joinDate and tostring(c.joinDate) or "U"
    local roles    = c.roles or "000"
    return charName .. "~" .. c.main .. "~" .. nick .. "~" .. joinDate .. "~" .. roles .. "~" .. (c.modified or 0)
end

local function BatchAndSend(records, target)
    local header = "SYNC|"
    local batch, batchLen = {}, #header
    for _, rec in ipairs(records) do
        local recLen = #rec + 1
        if batchLen + recLen > 250 and #batch > 0 then
            Enqueue(header .. table.concat(batch, "|"), target)
            batch, batchLen = {}, #header
        end
        table.insert(batch, rec)
        batchLen = batchLen + recLen
    end
    if #batch > 0 then Enqueue(header .. table.concat(batch, "|"), target) end
    Enqueue("SYNC_END", target)
end

-- Enqueue all chars modified after sinceTimestamp. Returns count sent.
local function EnqueueDelta(sinceTimestamp, target)
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return 0 end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return 0 end

    local records = {}
    for charName, c in pairs(data.chars) do
        if (c.modified or 0) > sinceTimestamp then
            table.insert(records, CharRecord(charName, c))
        end
    end
    if #records == 0 then return 0 end
    BatchAndSend(records, target)
    if debugMode then
        SyncPrint("Delta enqueued " .. #records .. " chars (since=" .. sinceTimestamp
            .. (target and ", target=" .. target or "") .. ")")
    end
    return #records
end

-- Enqueue specific chars by name list. Used for auto-broadcast on edit.
local function EnqueueChars(charNames, target)
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return end

    local records = {}
    for _, charName in ipairs(charNames) do
        local c = data.chars[charName]
        if c then table.insert(records, CharRecord(charName, c)) end
    end
    if #records == 0 then return end
    BatchAndSend(records, target)
    if debugMode then SyncPrint("BroadcastChars enqueued " .. #records .. " chars") end
end

-- Enqueue all chars in a bucket range.
local function EnqueueBucket(bucketIndex, target)
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return end

    local low     = BUCKETS[bucketIndex]
    local high    = BUCKETS[bucketIndex + 1]
    local records = {}
    for charName, c in pairs(data.chars) do
        if (low == "" or charName > low) and (high == "~" or charName <= high) then
            table.insert(records, CharRecord(charName, c))
        end
    end
    if #records == 0 then
        Enqueue("SYNC_END", target)
        return
    end
    BatchAndSend(records, target)
    if debugMode then
        SyncPrint("Bucket " .. bucketIndex .. " enqueued " .. #records .. " chars → " .. (target or "GUILD"))
    end
end

-- Bucket hashing.

local function BucketHash(bucketIndex)
    if not addon.MI_Guild_guildName or not MysteriousQoLDB.guildData then return "0" end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data or not data.chars then return "0" end
    local low  = BUCKETS[bucketIndex]
    local high = BUCKETS[bucketIndex + 1]
    local sum  = 0
    for name, c in pairs(data.chars) do
        if (low == "" or name > low) and (high == "~" or name <= high) then
            sum = sum + (c.modified or 0)
        end
    end
    return string.format("%X", sum)
end

local function BuildBucketHashes()
    local hashes = {}
    for i = 1, NUM_BUCKETS do
        hashes[i] = BucketHash(i)
    end
    return hashes
end

-- Public broadcast functions.

function addon.MI_GuildSync_BroadcastHello()
    if not addon.MI_Guild_guildName then return end
    if not addon.db.guild_sync_enabled then return end
    local hashes = BuildBucketHashes()
    local msg = "HELLO|" .. GetMyRankIndex() .. "|" .. GetMaxModified() .. "|" .. table.concat(hashes, "|")
    C_ChatInfo.SendAddonMessage(SYNC_PREFIX, msg, "GUILD")
    if debugMode then SyncPrint("HELLO sent rank=" .. GetMyRankIndex()) end
end

-- Auto-broadcast specific chars on edit. Any trusted-rank user can call this.
function addon.MI_GuildSync_BroadcastChars(charNames)
    if not addon.db.guild_sync_enabled then return end
    if not IsTrustedRank(GetMyRankIndex()) then return end
    if InCombatLockdown() then return end
    if not charNames or #charNames == 0 then return end
    EnqueueChars(charNames, nil)
end

-- Delta broadcast to a specific peer or guild (manual sync button). Leader only.
function addon.MI_GuildSync_BroadcastDelta(sinceTimestamp, target)
    if InCombatLockdown() then return end
    if not addon.MI_Guild_guildName then return end
    if not addon.db.guild_sync_enabled then return end
    if not addon.MI_GuildSync_IsLeader() then return end
    local count = EnqueueDelta(sinceTimestamp or 0, target)
    if count > 0 then
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    end
    return count
end

-- Incoming message handler.

local syncFrame = CreateFrame("Frame")

local function OnAddonMessage(_, _, prefix, msg, channel, sender)
    if not addon.db.guild_alts_enabled then return end
    if prefix ~= SYNC_PREFIX then return end
    if channel ~= "GUILD" and channel ~= "WHISPER" then return end
    local senderBare = StripRealm(sender)
    if senderBare == UnitName("player") then return end

    if debugMode then
        SyncPrint("RECV " .. channel .. " from " .. (sender or "?")
            .. "  " .. EscapeMsg(msg:sub(1, 80)))
    end

    -- HELLO|rankIndex|maxModified|h1|h2|h3|h4|h5|h6|h7|h8
    local rankStr, maxModStr, hashStr = msg:match("^HELLO|(%d+)|(%d+)|(.+)$")
    if rankStr then
        local buckets = {}
        for h in hashStr:gmatch("[^|]+") do
            table.insert(buckets, h)
        end
        local isNewPeer = not peerInfo[senderBare]
        peerInfo[senderBare] = {
            rank        = tonumber(rankStr) or 999,
            maxModified = tonumber(maxModStr) or 0,
            lastHello   = time(),
            buckets     = buckets,
        }
        -- If this is a peer we hadn't seen before, whisper our HELLO back so they
        -- can compare our hashes without needing a periodic broadcast.
        if isNewPeer and addon.db.guild_sync_enabled then
            local hashes = BuildBucketHashes()
            local reply  = "HELLO|" .. GetMyRankIndex() .. "|" .. GetMaxModified() .. "|" .. table.concat(hashes, "|")
            C_ChatInfo.SendAddonMessage(SYNC_PREFIX, reply, "WHISPER", senderBare)
        end
        -- Compare bucket hashes and request exchange for any mismatch.
        local myHashes = BuildBucketHashes()
        for i = 1, NUM_BUCKETS do
            if buckets[i] and buckets[i] ~= myHashes[i] then
                Enqueue("BUCKET_REQ|" .. i, senderBare)
            end
        end
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
        return
    end

    -- SYNC_END
    if msg == "SYNC_END" then
        addon.MI_Guild_RebuildIndex()
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
        return
    end

    -- SYNC|rec1|rec2|...  (accept from any trusted-rank peer)
    local body = msg:match("^SYNC|(.+)$")
    if body then
        local senderInfo = peerInfo[senderBare]
        local senderRank = senderInfo and senderInfo.rank or GetRankIndexOf(senderBare)
        if not IsTrustedRank(senderRank) then
            if debugMode then SyncPrint("IGNORED SYNC (not trusted rank): " .. senderBare) end
            return
        end
        for rec in body:gmatch("[^|]+") do
            local charName, main, nick, joinDate, roles, modified =
                rec:match("^([^~]+)~([^~]+)~([^~]*)~([^~]+)~([^~]+)~(%d+)$")
            if charName then
                MergeChar(charName, main, nick, joinDate, roles, modified)
            end
        end
        return
    end

    -- BUCKET_REQ|N  (peer wants our chars for bucket N)
    local bucketStr = msg:match("^BUCKET_REQ|(%d+)$")
    if bucketStr then
        local idx = tonumber(bucketStr)
        if idx and idx >= 1 and idx <= NUM_BUCKETS then
            EnqueueBucket(idx, senderBare)
            if debugMode then SyncPrint("BUCKET_REQ " .. idx .. " from " .. senderBare) end
        end
        return
    end
end

syncFrame:SetScript("OnEvent", OnAddonMessage)

-- Exported peer status (read by GuildPanel for the sync status UI).

-- Returns a table of { name, rank, rankName, maxModified, status } for all known peers.
-- status: "synced" | "stale" | "unknown"
function addon.MI_GuildSync_GetPeerStatuses()
    PruneExpiredPeers()
    local myMax  = GetMaxModified()
    local result = {}
    for bareName, info in pairs(peerInfo) do
        local status = "unknown"
        if info.maxModified then
            status = (info.maxModified >= myMax) and "synced" or "stale"
        end
        local rankName = ""
        for i = 1, GetNumGuildMembers() do
            local n, rn = GetGuildRosterInfo(i)
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


function addon.MI_GuildSync_Init()
    C_ChatInfo.RegisterAddonMessagePrefix(SYNC_PREFIX)
    syncFrame:RegisterEvent("CHAT_MSG_ADDON")

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(self, event, isLogin, isReload)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
            if isLogin and not isReload then
                C_Timer.After(60, function()
                    if addon.db.guild_alts_enabled then
                        addon.MI_GuildSync_BroadcastHello()
                    end
                end)
            end
        end
    end)
end
