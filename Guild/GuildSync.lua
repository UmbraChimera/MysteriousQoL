local _, addon = ...

local SYNC_PREFIX = "MQOL_GUILD"
local sendQueue = {}
local sendTicker = nil

-- Rank threshold parsed from Guild Info. Cached and refreshed on roster update.
-- rankIndex 0 = GM, 1 = first officer rank, etc. Members with rankIndex <= threshold are trusted.
local syncRankThreshold = 1  -- default: GM + first officer rank

local function StripRealm(name)
    return name and name:match("^([^%-]+)") or name
end

local function RefreshSyncRankThreshold()
    local info = C_GuildInfo.GetInfoText and C_GuildInfo.GetInfoText() or ""
    local n = info and info:match("%^#MQoL:(%d+)#%^")
    syncRankThreshold = n and tonumber(n) or 1
end

local function FlushQueue()
    if #sendQueue == 0 then
        if sendTicker then sendTicker:Cancel(); sendTicker = nil end
        return
    end
    C_ChatInfo.SendAddonMessage(SYNC_PREFIX, table.remove(sendQueue, 1), "GUILD")
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
local function MergeGroup(main, alts, modified, sender)
    if not addon.MI_Guild_guildName then return end
    if not MysteriousQoLDB.guildData then return end
    local data = MysteriousQoLDB.guildData[addon.MI_Guild_guildName]
    if not data then return end

    -- Only accept sync from members at or above the configured rank threshold.
    local rankIdx = GetSenderRankIndex(sender)
    if rankIdx == nil or rankIdx > syncRankThreshold then return end

    for _, group in ipairs(data.altGroups) do
        if group.main == main then
            if modified > group.modified then
                group.alts = alts
                group.modified = modified
            end
            return
        end
    end
    table.insert(data.altGroups, { main = main, alts = alts, modified = modified })
end

local syncFrame = CreateFrame("Frame")

local function OnAddonMessage(_, event, prefix, msg, channel, sender)
    if prefix ~= SYNC_PREFIX then return end
    if channel ~= "GUILD" then return end
    if StripRealm(sender) == UnitName("player") then return end

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
    MergeGroup(main, alts, tonumber(modifiedStr) or 0, sender)
end

syncFrame:SetScript("OnEvent", OnAddonMessage)

function addon.MI_GuildSync_Broadcast()
    if InCombatLockdown() then return end
    if not addon.MI_Guild_guildName then return end
    if not addon.db.guild_sync_enabled then return end

    for _, g in ipairs(addon.MI_Guild_GetAllGroups()) do
        table.insert(sendQueue, string.format("SYNC|v1|%s|%s|%d",
            g.main, table.concat(g.alts, ","), g.modified))
    end
    table.insert(sendQueue, "SYNC_END|v1")

    if not sendTicker then
        sendTicker = C_Timer.NewTicker(0.25, FlushQueue)
    end
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
                C_Timer.After(60, addon.MI_GuildSync_Broadcast)
            end
        end
    end)
end
