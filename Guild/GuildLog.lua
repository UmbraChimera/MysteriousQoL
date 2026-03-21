local _, addon = ...

local prevSnapshot = {}  -- [charName] = { rankIndex, rankName }
local firstLoad = true
local throttleTimer = nil

local function GetLog()
    local g = addon.MI_Guild_guildName
    if not g or not MysteriousQoLDB.guildData then return nil end
    local data = MysteriousQoLDB.guildData[g]
    return data and data.log
end

local function AppendLog(entry)
    local log = GetLog()
    if not log then return end
    table.insert(log, entry)
    local max = addon.db.guild_log_maxEntries or 200
    while #log > max do table.remove(log, 1) end
end

local function ProcessRosterUpdate()
    if not addon.db.guild_log_enabled then return end
    if not addon.MI_Guild_guildName then return end

    local newSnapshot = {}
    local now = time()
    for i = 1, GetNumGuildMembers() do
        local name, rankName, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name then
            newSnapshot[name] = { rankIndex = rankIndex, rankName = rankName }
            if online then addon.MI_Guild_SetLastSeen(name, now) end
        end
    end

    if firstLoad then
        firstLoad = false
        prevSnapshot = newSnapshot
        for name in pairs(newSnapshot) do
            addon.MI_Guild_RecordJoinDate(name, now)
        end
        return
    end

    for name in pairs(newSnapshot) do
        if not prevSnapshot[name] then
            AppendLog({ t = now, type = "JOIN", name = name })
            addon.MI_Guild_RecordJoinDate(name, now)
        end
    end
    for name, oldInfo in pairs(prevSnapshot) do
        local newInfo = newSnapshot[name]
        if not newInfo then
            AppendLog({ t = now, type = "LEAVE", name = name })
        elseif newInfo.rankIndex ~= oldInfo.rankIndex then
            local logType = (newInfo.rankIndex < oldInfo.rankIndex) and "PROMOTE" or "DEMOTE"
            AppendLog({ t = now, type = logType, name = name,
                from = oldInfo.rankName, to = newInfo.rankName })
        end
    end
    prevSnapshot = newSnapshot

    if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
end

local logFrame = CreateFrame("Frame")
logFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
logFrame:SetScript("OnEvent", function()
    if throttleTimer then return end
    throttleTimer = C_Timer.After(0.5, function()
        throttleTimer = nil
        ProcessRosterUpdate()
    end)
end)

function addon.MI_GuildLog_Init()
    C_GuildInfo.GuildRoster()
end

function addon.MI_GuildLog_GetEntries()
    return GetLog() or {}
end

function addon.MI_GuildLog_Clear()
    local log = GetLog()
    if not log then return end
    for i = #log, 1, -1 do log[i] = nil end
end
