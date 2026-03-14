local _, addon = ...

addon.MI_Guild_guildName = nil
addon.MI_Guild_Index = {}  -- [guildName][charName] = groupIndex (in-memory only)

local function StripRealm(name)
    return name and name:match("^([^%-]+)") or name
end

-- Returns the canonical roster name (Name-Realm when cross-realm, bare Name otherwise).
-- Resolves user-typed bare names against the live roster. Falls back to input if not found.
-- Only resolves unambiguously: if two roster members share the same bare name, returns input as-is.
local function CanonicalName(name)
    if not name or name == "" then return name end
    if name:find("-", 1, true) then return name end  -- already realm-qualified
    local found = nil
    for i = 1, GetNumGuildMembers() do
        local n = GetGuildRosterInfo(i)
        if n and n:match("^([^%-]+)") == name then
            if found then return name end  -- ambiguous: two members share bare name
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

-- ── Public API ────────────────────────────────────────────────────────────────

function addon.MI_Guild_RebuildIndex()
    local g = addon.MI_Guild_guildName
    if not g then return end
    local index = {}
    addon.MI_Guild_Index[g] = index
    local data = GetGuildData()
    if not data then return end
    for i, group in ipairs(data.altGroups) do
        if group.main then index[group.main] = i end
        for _, alt in ipairs(group.alts) do index[alt] = i end
    end
end

-- Returns the main name for charName if they are an alt, or nil if they are a main / unknown.
function addon.MI_Guild_GetMain(charName)
    if not charName then return nil end
    local g = addon.MI_Guild_guildName
    if not g then return nil end
    local index = addon.MI_Guild_Index[g]
    local idx = index and index[charName]
    if not idx then return nil end
    local data = GetGuildData()
    if not data then return nil end
    local group = data.altGroups[idx]
    if not group then return nil end
    if group.main == charName then return nil end
    return group.main
end

function addon.MI_Guild_GetAllGroups()
    local data = GetGuildData()
    return data and data.altGroups or {}
end

-- Creates a new alt group with mainName as the main. Returns the group index or nil on failure.
function addon.MI_Guild_CreateGroup(mainName)
    if not mainName or mainName == "" then return nil end
    local data = GetGuildData()
    if not data then return nil end
    local canonical = CanonicalName(mainName)
    local g = addon.MI_Guild_guildName
    local index = addon.MI_Guild_Index[g]
    if index and index[canonical] then return nil end
    table.insert(data.altGroups, { main = canonical, alts = {}, modified = time() })
    addon.MI_Guild_RebuildIndex()
    return #data.altGroups
end

function addon.MI_Guild_AddAlt(groupIndex, altName)
    if not altName or altName == "" then return end
    local data = GetGuildData()
    if not data then return end
    local group = data.altGroups[groupIndex]
    if not group then return end
    local canonical = CanonicalName(altName)
    for _, a in ipairs(group.alts) do
        if a == canonical then return end
    end
    table.insert(group.alts, canonical)
    group.modified = time()
    addon.MI_Guild_RebuildIndex()
end

function addon.MI_Guild_RemoveAlt(groupIndex, altName)
    local data = GetGuildData()
    if not data then return end
    local group = data.altGroups[groupIndex]
    if not group then return end
    for i, a in ipairs(group.alts) do
        if a == altName then table.remove(group.alts, i); break end
    end
    group.modified = time()
    addon.MI_Guild_RebuildIndex()
end

function addon.MI_Guild_SetMain(groupIndex, newMain)
    local data = GetGuildData()
    if not data then return end
    local group = data.altGroups[groupIndex]
    if not group then return end
    local canonical = CanonicalName(newMain)
    if group.main == canonical then return end
    -- Move old main into alts, remove new main from alts
    local oldMain = group.main
    for i, a in ipairs(group.alts) do
        if a == canonical then table.remove(group.alts, i); break end
    end
    if oldMain and oldMain ~= "" then
        table.insert(group.alts, oldMain)
    end
    group.main = canonical
    group.modified = time()
    addon.MI_Guild_RebuildIndex()
end

function addon.MI_Guild_DeleteGroup(groupIndex)
    local data = GetGuildData()
    if not data then return end
    table.remove(data.altGroups, groupIndex)
    addon.MI_Guild_RebuildIndex()
end

-- Returns groupIndex, group, isMain for charName, or nil if not found.
function addon.MI_Guild_GetGroupForChar(charName)
    if not charName then return nil end
    local g = addon.MI_Guild_guildName
    if not g then return nil end
    local index = addon.MI_Guild_Index[g]
    local idx = index and index[charName]
    if not idx then return nil end
    local data = GetGuildData()
    if not data then return nil end
    local group = data.altGroups[idx]
    if not group then return nil end
    return idx, group, group.main == charName
end

-- Sets charName as the main of their existing group, or creates a solo group.
function addon.MI_Guild_SetAsMain(charName)
    local canonical = CanonicalName(charName)
    local idx = addon.MI_Guild_GetGroupForChar(canonical)
    if idx then
        addon.MI_Guild_SetMain(idx, canonical)
    else
        addon.MI_Guild_CreateGroup(canonical)
    end
end

-- Links altName as an alt under mainName. Creates mainName's group if needed.
-- Moves altName out of any previous group first.
function addon.MI_Guild_LinkAltToMain(altName, mainName)
    if altName == mainName then return end

    -- Remove alt from its current group
    local altIdx, altGroup, altIsMain = addon.MI_Guild_GetGroupForChar(altName)
    if altGroup then
        if altIsMain then
            if #altGroup.alts == 0 then
                addon.MI_Guild_DeleteGroup(altIdx)
            else
                addon.MI_Guild_SetMain(altIdx, altGroup.alts[1])
                addon.MI_Guild_RemoveAlt(altIdx, altName)
            end
        else
            addon.MI_Guild_RemoveAlt(altIdx, altName)
        end
    end

    -- Find or create mainName's group, then add alt
    local mainIdx, mainGroup = addon.MI_Guild_GetGroupForChar(mainName)
    if mainGroup then
        addon.MI_Guild_AddAlt(mainIdx, altName)
    else
        local newIdx = addon.MI_Guild_CreateGroup(mainName)
        if newIdx then addon.MI_Guild_AddAlt(newIdx, altName) end
    end
end

-- Called when a member joins the guild during the session.
-- Re-writes their officer note if they are a known alt, or prompts to link them if unknown.
function addon.MI_Guild_OnMemberJoin(name)
    local data = GetGuildData()
    if not data then return end
    for _, group in ipairs(data.altGroups) do
        if group.main == name then
            return  -- they are a main; no [M:] tag needed on their own note
        end
        for _, alt in ipairs(group.alts) do
            if alt == name then return end
        end
    end
end

-- Removes charName from their group. Promotes first alt if they were the main.
function addon.MI_Guild_UnlinkChar(charName)
    local bare = charName  -- keep full name for exact lookup
    local idx, group, isMain = addon.MI_Guild_GetGroupForChar(bare)
    if not group then return end
    if isMain then
        if #group.alts == 0 then
            addon.MI_Guild_DeleteGroup(idx)
        else
            addon.MI_Guild_SetMain(idx, group.alts[1])
            addon.MI_Guild_RemoveAlt(idx, bare)
        end
    else
        addon.MI_Guild_RemoveAlt(idx, bare)
    end
end

-- Returns the display name (nick or main) for charName if they are an alt, nil for mains/unlinked.
function addon.MI_Guild_GetNickForChar(charName)
    if not charName then return nil end
    local g = addon.MI_Guild_guildName
    if not g then return nil end
    local index = addon.MI_Guild_Index[g]
    local idx = index and index[charName]
    if not idx then return nil end
    local data = GetGuildData()
    if not data then return nil end
    local group = data.altGroups[idx]
    if not group then return nil end
    if group.main == charName then return nil end
    return group.nick or StripRealm(group.main)
end

function addon.MI_Guild_SetNick(groupIdx, nick)
    local data = GetGuildData()
    if not data then return end
    local group = data.altGroups[groupIdx]
    if not group then return end
    group.nick = (nick and nick ~= "") and nick or nil
    group.modified = time()
end

-- ── Init ─────────────────────────────────────────────────────────────────────

local function EnsureGuildData(guildName)
    MysteriousQoLDB.guildData = MysteriousQoLDB.guildData or {}
    if not MysteriousQoLDB.guildData[guildName] then
        MysteriousQoLDB.guildData[guildName] = { altGroups = {}, log = {}, members = {} }
    end
    MysteriousQoLDB.guildData[guildName].members = MysteriousQoLDB.guildData[guildName].members or {}
end

function addon.MI_Guild_Init()
    local guildName = GetGuildInfo("player")
    addon.MI_Guild_guildName = guildName
    if guildName then EnsureGuildData(guildName) end
    addon.MI_Guild_RebuildIndex()

    addon.MI_GuildChat_Init()
    addon.MI_GuildSync_Init()
    addon.MI_GuildLog_Init()
    addon.MI_GuildPanel_Init()
    addon.MI_GuildCommunities_Init()

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_GUILD_UPDATE")
    f:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_GUILD_UPDATE" then
            local newGuild = GetGuildInfo("player")
            if newGuild ~= addon.MI_Guild_guildName then
                addon.MI_Guild_guildName = newGuild
                if newGuild then EnsureGuildData(newGuild) end
                addon.MI_Guild_RebuildIndex()
            end
        end
    end)
end
