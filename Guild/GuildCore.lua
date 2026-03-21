local _, addon = ...

addon.MI_Guild_guildName = nil

local function StripRealm(name)
    return name and name:match("^([^%-]+)") or name
end

-- Collapses "Name-Realm-Realm-Realm" to "Name-Realm" (or "Name" if no realm).
local function NormalizeName(name)
    if not name then return name end
    return name:match("^([^%-]+%-[^%-]+)") or name
end

-- Resolves a bare name to the full roster name (Name-Realm when cross-realm).
-- Falls back to input if ambiguous or not found.
local function CanonicalName(name)
    if not name or name == "" then return name end
    if name:find("-", 1, true) then return name end
    local found = nil
    for i = 1, GetNumGuildMembers() do
        local n = GetGuildRosterInfo(i)
        if n and n:match("^([^%-]+)") == name then
            if found then return name end
            found = n
        end
    end
    return found or name
end

local function GetGuildData()
    local g = addon.MI_Guild_guildName
    if not g or not MysteriousQoLDB.guildData then return nil end
    return MysteriousQoLDB.guildData[g]
end

local function GetChars()
    local data = GetGuildData()
    return data and data.chars
end

-- Push nick for a group to NSRT (NameSort Real Tough) if that addon is loaded.
local function PushGroupToNSRT(mainName)
    if not (NSAPI and NSRT and NSRT.NickNames) then return end
    local chars = GetChars()
    if not chars or not chars[mainName] then return end
    local nick = chars[mainName].nick
    nick = (nick and nick ~= "") and nick or nil
    local realm = "-" .. GetRealmName()
    for charName, c in pairs(chars) do
        if c.main == mainName or charName == mainName then
            local key = charName:find("-", 1, true) and charName or (charName .. realm)
            NSRT.NickNames[key] = nick
        end
    end
end

-- Public API -----------------------------------------------------------------------

-- Returns mainName if charName is an alt, nil if charName is a main or unlinked.
function addon.MI_Guild_GetMain(charName)
    local chars = GetChars()
    if not chars or not charName then return nil end
    local c = chars[charName]
    if not c then return nil end
    return c.main ~= charName and c.main or nil
end

-- Returns array of virtual group objects {main, alts[], nick, modified} sorted by main name.
function addon.MI_Guild_GetAllGroups()
    local chars = GetChars()
    if not chars then return {} end
    local groups = {}
    for charName, c in pairs(chars) do
        if c.main == charName then
            local alts, maxMod = {}, c.modified or 0
            for altName, ac in pairs(chars) do
                if ac.main == charName and altName ~= charName then
                    table.insert(alts, altName)
                    if (ac.modified or 0) > maxMod then maxMod = ac.modified end
                end
            end
            table.sort(alts)
            table.insert(groups, { main = charName, alts = alts, nick = c.nick, modified = maxMod })
        end
    end
    table.sort(groups, function(a, b) return a.main < b.main end)
    return groups
end

-- Creates a solo entry for mainName. Returns mainName on success, nil if already tracked.
function addon.MI_Guild_CreateGroup(mainName)
    if not mainName or mainName == "" then return nil end
    local chars = GetChars()
    if not chars then return nil end
    local canonical = CanonicalName(mainName)
    if chars[canonical] then return nil end
    chars[canonical] = { main = canonical, joinDate = false, lastSeen = nil, roles = "000", modified = time() }
    if addon.MI_GuildSync_BroadcastChars then addon.MI_GuildSync_BroadcastChars({canonical}) end
    return canonical
end

-- Links altName as an alt under mainName.
function addon.MI_Guild_AddAlt(mainName, altName)
    if not altName or altName == "" then return end
    local chars = GetChars()
    if not chars then return end
    local canonical = CanonicalName(altName)
    if canonical == mainName then return end
    if not chars[mainName] then return end
    if chars[canonical] and chars[canonical].main == mainName then return end
    local prev = chars[canonical] or {}
    local now = time()
    chars[canonical] = {
        main     = mainName,
        nick     = prev.nick,
        joinDate = prev.joinDate or false,
        lastSeen = prev.lastSeen,
        roles    = prev.roles or "000",
        modified = now,
    }
    chars[mainName].modified = now
    if addon.MI_GuildSync_BroadcastChars then addon.MI_GuildSync_BroadcastChars({canonical, mainName}) end
end

-- Unlinks altName from mainName's group; altName becomes a solo unlinked entry.
function addon.MI_Guild_RemoveAlt(mainName, altName)
    local chars = GetChars()
    if not chars then return end
    local c = chars[altName]
    if not c or c.main ~= mainName then return end
    local now = time()
    c.main = altName
    c.modified = now
    if chars[mainName] then chars[mainName].modified = now end
    if addon.MI_GuildSync_BroadcastChars then addon.MI_GuildSync_BroadcastChars({altName, mainName}) end
end

-- Promotes charName to main within their existing group.
-- All current alts of charName's old main now point to charName; old main becomes an alt.
function addon.MI_Guild_SetMain(charName)
    local chars = GetChars()
    if not chars then return end
    local c = chars[charName]
    if not c or c.main == charName then return end
    local oldMain = c.main
    local now = time()
    for k, v in pairs(chars) do
        if v.main == oldMain then
            v.main = charName
            v.modified = now
        end
    end
    chars[charName].main = charName
    chars[charName].modified = now
    if addon.MI_GuildSync_BroadcastChars then
        local affected = {}
        for k, v in pairs(chars) do
            if v.main == charName then table.insert(affected, k) end
        end
        if #affected > 0 then addon.MI_GuildSync_BroadcastChars(affected) end
    end
end

-- Unlinks all members of mainName's group; each becomes a solo unlinked entry.
function addon.MI_Guild_DeleteGroup(mainName)
    local chars = GetChars()
    if not chars then return end
    local now = time()
    local affected = {}
    for charName, c in pairs(chars) do
        if c.main == mainName then
            table.insert(affected, charName)
            c.main = charName
            c.modified = now
        end
    end
    if addon.MI_GuildSync_BroadcastChars and #affected > 0 then
        addon.MI_GuildSync_BroadcastChars(affected)
    end
end

-- Returns (mainName, {main, alts[], nick}, isMain) for charName, or nil if not tracked.
function addon.MI_Guild_GetGroupForChar(charName)
    if not charName then return nil end
    local chars = GetChars()
    if not chars then return nil end
    local c = chars[charName]
    if not c then return nil end
    local mainName = c.main
    local alts = {}
    for altName, ac in pairs(chars) do
        if ac.main == mainName and altName ~= mainName then
            table.insert(alts, altName)
        end
    end
    table.sort(alts)
    local mainChar = chars[mainName]
    local group = { main = mainName, alts = alts, nick = mainChar and mainChar.nick }
    return mainName, group, mainName == charName
end

-- Sets charName as the main of their existing group, or creates a solo entry.
function addon.MI_Guild_SetAsMain(charName)
    local canonical = CanonicalName(charName)
    local mainName = addon.MI_Guild_GetGroupForChar(canonical)
    if mainName then
        addon.MI_Guild_SetMain(canonical)
    else
        addon.MI_Guild_CreateGroup(canonical)
    end
end

-- Links altName as alt of mainName, moving altName out of any prior group first.
function addon.MI_Guild_LinkAltToMain(altName, mainName)
    local chars = GetChars()
    if not chars then return end
    local altCanon  = CanonicalName(altName)
    local mainCanon = CanonicalName(mainName)
    if altCanon == mainCanon then return end
    local now = time()

    local existing = chars[altCanon]
    if existing then
        if existing.main == altCanon then
            -- altCanon is currently a main; promote their first alt
            local alts = {}
            for k, v in pairs(chars) do
                if v.main == altCanon and k ~= altCanon then table.insert(alts, k) end
            end
            table.sort(alts)
            if #alts > 0 then
                for k, v in pairs(chars) do
                    if v.main == altCanon then v.main = alts[1]; v.modified = now end
                end
            end
        else
            -- altCanon is currently an alt; remove from old group
            if chars[existing.main] then chars[existing.main].modified = now end
        end
    end

    if not chars[mainCanon] then
        chars[mainCanon] = { main = mainCanon, joinDate = false, lastSeen = nil, roles = "000", modified = now }
    end

    local prev = chars[altCanon] or {}
    chars[altCanon] = {
        main     = mainCanon,
        nick     = prev.nick,
        joinDate = prev.joinDate or false,
        lastSeen = prev.lastSeen,
        roles    = prev.roles or "000",
        modified = now,
    }
    chars[mainCanon].modified = now
    if addon.MI_GuildSync_BroadcastChars then
        local affected = {}
        for k, c in pairs(chars) do
            if c.modified == now then table.insert(affected, k) end
        end
        if #affected > 0 then addon.MI_GuildSync_BroadcastChars(affected) end
    end
end

-- Removes charName from their group. Promotes first alt if charName was the main.
function addon.MI_Guild_UnlinkChar(charName)
    local chars = GetChars()
    if not chars then return end
    local c = chars[charName]
    if not c then return end
    local now = time()

    if c.main == charName then
        local alts = {}
        for k, v in pairs(chars) do
            if v.main == charName and k ~= charName then table.insert(alts, k) end
        end
        table.sort(alts)
        if #alts > 0 then
            for k, v in pairs(chars) do
                if v.main == charName then v.main = alts[1]; v.modified = now end
            end
            chars[charName].main = charName
            chars[charName].modified = now
        end
    else
        local oldMain = c.main
        c.main = charName
        c.modified = now
        if chars[oldMain] then chars[oldMain].modified = now end
    end
    if addon.MI_GuildSync_BroadcastChars then
        local affected = {}
        for k, ch in pairs(chars) do
            if ch.modified == now then table.insert(affected, k) end
        end
        if #affected > 0 then addon.MI_GuildSync_BroadcastChars(affected) end
    end
end

-- Returns display name (nick or main's bare name) for alts. Returns nil for mains / unlinked.
function addon.MI_Guild_GetNickForChar(charName)
    if not charName then return nil end
    local chars = GetChars()
    if not chars then return nil end
    local c = chars[charName]
    if not c then return nil end
    if c.main == charName then return nil end
    return c.nick or StripRealm(c.main)
end

-- Sets nick on all characters in mainName's group. Pass nil or "" to clear.
function addon.MI_Guild_SetNick(mainName, nick)
    local chars = GetChars()
    if not chars then return end
    local value = (nick and nick ~= "") and nick or nil
    local now = time()
    for charName, c in pairs(chars) do
        if c.main == mainName or charName == mainName then
            c.nick = value
            c.modified = now
        end
    end
    if addon.MI_GuildSync_BroadcastChars then
        local affected = {}
        for charName, c in pairs(chars) do
            if c.modified == now then table.insert(affected, charName) end
        end
        if #affected > 0 then addon.MI_GuildSync_BroadcastChars(affected) end
    end
    PushGroupToNSRT(mainName)
end

-- Set joinDate for charName. User input always wins (no "oldest wins" logic).
function addon.MI_Guild_SetJoinDate(charName, ts)
    local chars = GetChars()
    if not chars then return end
    if not chars[charName] then
        chars[charName] = { main = charName, joinDate = ts or false, lastSeen = nil, roles = "000", modified = time() }
    else
        chars[charName].joinDate = ts or false
        chars[charName].modified = time()
    end
    if addon.MI_GuildSync_BroadcastChars then addon.MI_GuildSync_BroadcastChars({charName}) end
end

-- Records joinDate only if the character has none (used by GuildLog on first-seen).
function addon.MI_Guild_RecordJoinDate(charName, ts)
    local chars = GetChars()
    if not chars then return end
    charName = NormalizeName(charName)
    if not chars[charName] then
        chars[charName] = { main = charName, joinDate = ts, lastSeen = nil, roles = "000", modified = 0 }
    elseif not chars[charName].joinDate then
        chars[charName].joinDate = ts
    end
end

-- Updates lastSeen to ts (or now). Creates a bare entry if char is unknown.
function addon.MI_Guild_SetLastSeen(charName, ts)
    local chars = GetChars()
    if not chars then return end
    charName = NormalizeName(charName)
    if not chars[charName] then
        chars[charName] = { main = charName, joinDate = false, lastSeen = ts, roles = "000", modified = 0 }
    else
        chars[charName].lastSeen = ts
    end
end

-- Sets roles bitmask string ("000" = none, "100" = Tank, "010" = Healer, "001" = DPS).
function addon.MI_Guild_SetRoles(charName, roles)
    local chars = GetChars()
    if not chars then return end
    if not chars[charName] then return end
    chars[charName].roles = roles or "000"
    chars[charName].modified = time()
    if addon.MI_GuildSync_BroadcastChars then addon.MI_GuildSync_BroadcastChars({charName}) end
end

-- Returns roles bitmask string for charName, or "000" if unknown.
function addon.MI_Guild_GetRoles(charName)
    local chars = GetChars()
    if not chars or not charName then return "000" end
    local c = chars[charName]
    return c and c.roles or "000"
end

-- Returns the raw chars table (read-only use only).
function addon.MI_Guild_GetAllChars()
    return GetChars() or {}
end

-- No-op kept for compatibility; flat schema needs no index rebuild.
function addon.MI_Guild_RebuildIndex() end

-- ---------------------------------------------------------------------------------

local function EnsureGuildData(guildName)
    MysteriousQoLDB.guildData = MysteriousQoLDB.guildData or {}
    if not MysteriousQoLDB.guildData[guildName] then
        MysteriousQoLDB.guildData[guildName] = { schemaVer = 2, chars = {}, log = {} }
    end
    local data = MysteriousQoLDB.guildData[guildName]
    data.chars = data.chars or {}
    data.log   = data.log   or {}
end

function addon.MI_Guild_Init()
    local guildName = GetGuildInfo("player")
    addon.MI_Guild_guildName = guildName
    if guildName then
        EnsureGuildData(guildName)
    end

    addon.MI_GuildChat_Init()
    addon.MI_GuildSync_Init()
    addon.MI_GuildLog_Init()
    addon.MI_GuildPanel_Init()
    addon.MI_GuildCommunities_Init()

    C_Timer.After(1, function()
        local chars = GetChars()
        if not chars then return end
        for charName, c in pairs(chars) do
            if c.main == charName then PushGroupToNSRT(charName) end
        end
    end)

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_GUILD_UPDATE")
    f:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_GUILD_UPDATE" then
            local newGuild = GetGuildInfo("player")
            if newGuild ~= addon.MI_Guild_guildName then
                addon.MI_Guild_guildName = newGuild
                if newGuild then
                    EnsureGuildData(newGuild)
                end
            end
        end
    end)
end
