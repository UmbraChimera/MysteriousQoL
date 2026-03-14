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

-- Write [M:MainName] or [M:MainName(Nick)] to a member's officer note.
-- Only writes to empty notes or notes already tagged by us.
local function TryWriteOfficerNote(memberName, mainName, nick)
    if not addon.db.guild_writeOfficerNotes then return end
    if IsAddOnLoaded("Guild_Roster_Manager") then return end  -- don't conflict with GRM's officer note usage
    C_Timer.After(0.2, function()
        if not C_GuildInfo.CanEditOfficerNote() then return end
        if InCombatLockdown() then return end
        for i = 1, GetNumGuildMembers() do
            local name, _, _, _, _, _, _, oNote, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if name and (name == memberName or StripRealm(name) == StripRealm(memberName)) then
                local tag = nick and ("[M:" .. mainName .. "(" .. nick .. ")]") or ("[M:" .. mainName .. "]")
                if #tag > 31 then tag = "[M:" .. mainName .. "]" end  -- fallback if nick makes it too long
                -- Allow overwriting: empty, our own tag format, or plain main name (GRM-style)
                if (oNote == "" or oNote:sub(1, 3) == "[M:" or oNote == mainName)
                    and #tag <= 31 and guid and guid ~= "" then
                    C_GuildInfo.SetNote(guid, tag, false)
                end
                return
            end
        end
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function addon.MI_Guild_RebuildIndex()
    local g = addon.MI_Guild_guildName
    if not g then return end
    local index = {}
    addon.MI_Guild_Index[g] = index
    local data = GetGuildData()
    if not data then return end
    -- Track bare names that map to multiple groups (conflict → don't add bare alias).
    local bareConflict = {}
    local function addEntry(name, groupIdx)
        index[name] = groupIdx
        local bare = StripRealm(name)
        if bare ~= name then
            if index[bare] and index[bare] ~= groupIdx then
                bareConflict[bare] = true
                index[bare] = nil  -- remove conflicting bare alias
            elseif not bareConflict[bare] then
                index[bare] = groupIdx
            end
        end
    end
    for i, group in ipairs(data.altGroups) do
        if group.main then addEntry(group.main, i) end
        for _, alt in ipairs(group.alts) do addEntry(alt, i) end
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
    local haRealm = charName:find("-", 1, true) ~= nil
    local isMain = (group.main == charName) or
        (not haRealm and group.main:find("-", 1, true) and StripRealm(group.main) == charName)
    if not isMain then return group.main end
    return nil
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
    if index and (index[canonical] or index[StripRealm(canonical)]) then return nil end
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
    local bare = StripRealm(canonical)
    for _, a in ipairs(group.alts) do
        if a == canonical or StripRealm(a) == bare then return end
    end
    table.insert(group.alts, canonical)
    group.modified = time()
    addon.MI_Guild_RebuildIndex()
    TryWriteOfficerNote(canonical, group.main, group.nick)
end

function addon.MI_Guild_RemoveAlt(groupIndex, altName)
    local data = GetGuildData()
    if not data then return end
    local group = data.altGroups[groupIndex]
    if not group then return end
    local bare = StripRealm(altName)
    for i, a in ipairs(group.alts) do
        if a == altName or StripRealm(a) == bare then table.remove(group.alts, i); break end
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
    local bare = StripRealm(canonical)
    if group.main == canonical or StripRealm(group.main) == bare then return end
    -- Move old main into alts, remove new main from alts
    local oldMain = group.main
    for i, a in ipairs(group.alts) do
        if a == canonical or StripRealm(a) == bare then table.remove(group.alts, i); break end
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
    -- Try exact match first; fall back to bare-name alias for backward compat with stored bare names.
    -- RebuildIndex removes the bare alias when two groups share the same bare name, so this is safe.
    local idx = index and (index[charName] or index[StripRealm(charName)])
    if not idx then return nil end
    local data = GetGuildData()
    if not data then return nil end
    local group = data.altGroups[idx]
    if not group then return nil end
    -- isMain: exact match, OR same-realm bare charName vs realm-qualified stored main.
    local haRealm = charName:find("-", 1, true) ~= nil
    local isMain = (group.main == charName) or
        (not haRealm and group.main:find("-", 1, true) and StripRealm(group.main) == charName)
    return idx, group, isMain
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
    local bareAlt  = StripRealm(altName)
    local bareMain = StripRealm(mainName)
    if bareAlt == bareMain then return end

    -- Remove alt from its current group
    local altIdx, altGroup, altIsMain = addon.MI_Guild_GetGroupForChar(bareAlt)
    if altGroup then
        if altIsMain then
            if #altGroup.alts == 0 then
                addon.MI_Guild_DeleteGroup(altIdx)
            else
                -- Promote first alt to main, then the old main slot is freed
                addon.MI_Guild_SetMain(altIdx, altGroup.alts[1])
                -- SetMain moved bareAlt into alts; now remove it
                addon.MI_Guild_RemoveAlt(altIdx, bareAlt)
            end
        else
            addon.MI_Guild_RemoveAlt(altIdx, bareAlt)
        end
    end

    -- Find or create mainName's group, then add alt
    local mainIdx, mainGroup = addon.MI_Guild_GetGroupForChar(bareMain)
    if mainGroup then
        -- If mainName is an alt in their own group, use that group's main
        addon.MI_Guild_AddAlt(mainIdx, bareAlt)
    else
        local newIdx = addon.MI_Guild_CreateGroup(bareMain)
        if newIdx then addon.MI_Guild_AddAlt(newIdx, bareAlt) end
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
            if alt == name then
                TryWriteOfficerNote(name, group.main, group.nick)
                return
            end
        end
    end
    -- Not in any group — prompt to link them
    if addon.MI_GuildPanel_PromptNewMember then
        addon.MI_GuildPanel_PromptNewMember(name)
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
    local haRealm = charName:find("-", 1, true) ~= nil
    local isMain = (group.main == charName) or
        (not haRealm and group.main:find("-", 1, true) and StripRealm(group.main) == charName)
    if isMain then return nil end
    return group.nick or StripRealm(group.main)
end

function addon.MI_Guild_SetNick(groupIdx, nick)
    local data = GetGuildData()
    if not data then return end
    local group = data.altGroups[groupIdx]
    if not group then return end
    group.nick = (nick and nick ~= "") and nick or nil
    group.modified = time()
    for _, altName in ipairs(group.alts) do
        TryWriteOfficerNote(altName, group.main, group.nick)
    end
end

-- ── Officer note scanning ────────────────────────────────────────────────────
-- Reads [M:MainName] tags from officer notes to auto-import alt links.
-- Uses a conservative modified=1 so manual links always win in merges.

local noteThrottle = nil

local function ScanOfficerNotes()
    local data = GetGuildData()
    if not data then return end
    local changed = false
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, oNote = GetGuildRosterInfo(i)
        if name and oNote and oNote:sub(1, 3) == "[M:" then
            -- Parse [M:MainName] or [M:MainName(Nick)] — extract main name before any (
            local mainName = oNote:match("^%[M:([^%(%)%]]+)")
            if mainName and mainName ~= "" then
                -- Use full roster name (with realm if cross-realm) as the storage key.
                local storeName = name  -- name from GetGuildRosterInfo, may include realm
                if StripRealm(storeName) ~= mainName then
                    local found = false
                    for _, group in ipairs(data.altGroups) do
                        if group.main == mainName or StripRealm(group.main) == mainName
                            or group.nick == mainName then
                            found = true
                            local hasAlt = false
                            for _, a in ipairs(group.alts) do
                                if a == storeName or StripRealm(a) == StripRealm(storeName) then
                                    hasAlt = true; break
                                end
                            end
                            if not hasAlt then
                                table.insert(group.alts, storeName)
                                changed = true
                            end
                            break
                        end
                    end
                    if not found then
                        table.insert(data.altGroups, { main = mainName, alts = { storeName }, modified = 1 })
                        changed = true
                    end
                end
            end
        end
    end
    if changed then
        addon.MI_Guild_RebuildIndex()
        if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    end
end

-- ── GRM import ───────────────────────────────────────────────────────────────
-- Imports alt groups and join dates from GRM SavedVariables (if present).
-- Only runs when called explicitly (Import GRM button). Skips groups already tracked.
-- Returns groupsImported, groupsSkipped.

function addon.MI_Guild_ImportFromGRM()
    if not addon.MI_Guild_guildName then return 0, 0 end
    local guildName = addon.MI_Guild_guildName

    -- GRM stores data keyed as "GuildName-RealmName"; find our guild's key by prefix
    local grmKey = nil
    local function FindKey(tbl)
        if not tbl then return nil end
        for k in pairs(tbl) do
            if type(k) == "string" and k:sub(1, #guildName) == guildName then
                return k
            end
        end
    end
    grmKey = FindKey(GRM_Alts) or FindKey(GRM_GuildMemberHistory_Save)
    if not grmKey then return 0, 0 end

    local data = MysteriousQoLDB.guildData[guildName]
    if not data then return 0, 0 end
    data.members = data.members or {}

    local imported, skipped = 0, 0

    -- Import alt groups from GRM_Alts
    if GRM_Alts and GRM_Alts[grmKey] then
        for _, group in pairs(GRM_Alts[grmKey]) do
            if type(group) == "table" and group.main then
                local bareMain = group.main:match("^([^%-]+)")
                if addon.MI_Guild_GetGroupForChar(bareMain) then
                    skipped = skipped + 1
                else
                    local alts = {}
                    for _, member in ipairs(group) do
                        if type(member) == "table" and member.name then
                            local bare = member.name:match("^([^%-]+)")
                            if bare ~= bareMain then
                                table.insert(alts, bare)
                            end
                        end
                    end
                    table.insert(data.altGroups, {
                        main     = bareMain,
                        alts     = alts,
                        modified = group.timeModified or time(),
                    })
                    imported = imported + 1
                end
            end
        end
    end

    -- Import join dates from GRM_GuildMemberHistory_Save
    if GRM_GuildMemberHistory_Save and GRM_GuildMemberHistory_Save[grmKey] then
        for charNameRealm, memberData in pairs(GRM_GuildMemberHistory_Save[grmKey]) do
            if type(memberData) == "table" and memberData.joinDateHist then
                local bare = charNameRealm:match("^([^%-]+)")
                local oldest = nil
                for _, entry in ipairs(memberData.joinDateHist) do
                    local ts = entry[5]
                    if ts and ts > 0 and (not oldest or ts < oldest) then
                        oldest = ts
                    end
                end
                if oldest then
                    data.members[bare] = data.members[bare] or {}
                    data.members[bare].joinDate = oldest
                end
            end
        end
    end

    if imported > 0 then addon.MI_Guild_RebuildIndex() end
    if addon.MI_GuildPanel_Refresh then addon.MI_GuildPanel_Refresh() end
    return imported, skipped
end

-- ── GRM log import ───────────────────────────────────────────────────────────
-- Parses the GRM plain-text log export (the file GRM calls a .json but isn't).
-- Format: "N) DD Mon 'YY HH:MMam/pm : EventString;[;SubEvent;...]"
-- Imports join dates into data.members[charName].joinDate (keeps earliest known date).
-- Returns joinDatesImported.

function addon.MI_GuildImport_ParseGRMLog(text)
    if not addon.MI_Guild_guildName then return 0 end
    local data = GetGuildData()
    if not data then return 0 end
    data.members = data.members or {}

    local months = { Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12 }

    -- Parse "DD Mon 'YY HH:MMam/pm" or "DD Mon 'YY" into an epoch.
    local function ParseDate(s)
        local d, m, y, hh, mm, ap = s:match("(%d+) (%a+) '(%d+) (%d+):(%d+)(%a+)")
        if d and months[m] then
            local hour = tonumber(hh)
            if ap == "pm" and hour ~= 12 then hour = hour + 12 end
            if ap == "am" and hour == 12 then hour = 0 end
            return time({ year = 2000+tonumber(y), month = months[m],
                          day = tonumber(d), hour = hour, min = tonumber(mm), sec = 0 })
        end
        local d2, m2, y2 = s:match("(%d+) (%a+) '(%d+)")
        if d2 and months[m2] then
            return time({ year = 2000+tonumber(y2), month = months[m2],
                          day = tonumber(d2), hour = 0, min = 0, sec = 0 })
        end
        return 0
    end

    -- Collect earliest epoch per character before writing, so repeated entries take the minimum.
    local earliest = {}
    local function Candidate(charName, epoch)
        if epoch > 0 and (not earliest[charName] or epoch < earliest[charName]) then
            earliest[charName] = epoch
        end
    end

    for line in text:gmatch("[^\n]+") do
        -- Strip leading "N) " entry number
        local rest = line:match("^%d+%) (.+)$") or line
        -- Extract optional "DD Mon 'YY HH:MMam/pm : " timestamp prefix
        local ts_str, event = rest:match("^(%d+ %a+ '%d+ %d+:%d+%a+) : (.+)$")
        if not event then event = rest end  -- no timestamp on this line

        -- JOIN: "CharName has JOINED the guild! ..."
        local joined = event:match("^([^ ]+) has JOINED the guild!")
        if joined then
            Candidate(joined, ts_str and ParseDate(ts_str) or 0)
        end

        -- REINVITED: "Inviter has REINVITED CharName to the guild...;...;Date Originally Joined: DD Mon 'YY;..."
        local _, reinvited = event:match("^([^ ]+) has REINVITED ([^ ]+) to the guild")
        if reinvited then
            Candidate(reinvited, ts_str and ParseDate(ts_str) or 0)
            -- "Date Originally Joined" gives the real first-join date (earlier than reinvite date).
            local origDate = event:match("Date Originally Joined:%s*(%d+ %a+ '%d+)")
            if origDate then Candidate(reinvited, ParseDate(origDate)) end
        end
    end

    local joins = 0
    for charName, epoch in pairs(earliest) do
        data.members[charName] = data.members[charName] or {}
        if not data.members[charName].joinDate or epoch < data.members[charName].joinDate then
            data.members[charName].joinDate = epoch
            joins = joins + 1
        end
    end
    return joins
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
    f:RegisterEvent("GUILD_ROSTER_UPDATE")
    f:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_GUILD_UPDATE" then
            local newGuild = GetGuildInfo("player")
            if newGuild ~= addon.MI_Guild_guildName then
                addon.MI_Guild_guildName = newGuild
                if newGuild then EnsureGuildData(newGuild) end
                addon.MI_Guild_RebuildIndex()
            end
        elseif event == "GUILD_ROSTER_UPDATE" then
            if noteThrottle then return end
            noteThrottle = C_Timer.After(1.5, function()
                noteThrottle = nil
                ScanOfficerNotes()
            end)
        end
    end)
end
