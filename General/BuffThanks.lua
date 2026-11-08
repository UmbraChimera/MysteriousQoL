local _, addon = ...

-- Sends /thank to players outside your group who give you a longer buff.
--
-- Rules: a helpful buff over 2 minutes that was just cast on you (not an old one
-- the game reports again after a loading screen), from another player who is not
-- in your group or raid. Out of combat only. The emote goes out a second later,
-- at most once per player every 5 minutes and never closer than 3 seconds apart.

local MIN_DURATION = 120
local FRESH        = 1.5  -- seconds between the cast and when we see it
local DELAY        = 1
local GAP          = 3
local PLAYER_CD    = 300
local SETTLE       = 5    -- quiet time after a loading screen

local thanked = {}   -- guid -> time
local pending = {}   -- guid -> name
local lastThanks = 0
local settleUntil = 0

local function isSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function inMyGroup(guid)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitGUID("raid" .. i) == guid then return true end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            if UnitGUID("party" .. i) == guid then return true end
        end
    end
    return false
end

local function sendThanks(name)
    if C_ChatInfo and C_ChatInfo.PerformEmote then
        pcall(C_ChatInfo.PerformEmote, "THANK", name)
    elseif DoEmote then
        pcall(DoEmote, "THANK", name)
    end
end

local function fire(guid)
    local name = pending[guid]
    if not name then return end
    if not addon.db.general_thankBuffs then
        pending[guid] = nil
        return
    end
    local now = GetTime()
    if InCombatLockdown() or now - lastThanks < GAP then
        C_Timer.After(GAP, function() fire(guid) end)
        return
    end
    pending[guid] = nil
    if thanked[guid] and now - thanked[guid] < PLAYER_CD then return end
    for g, t in pairs(thanked) do
        if now - t >= PLAYER_CD then thanked[g] = nil end
    end
    thanked[guid] = now
    lastThanks = now
    sendThanks(name)
end

local function casterGUID(aura)
    local guid
    if C_UnitAuras.GetAuraCasterGUID and aura.auraInstanceID then
        local ok, result = pcall(C_UnitAuras.GetAuraCasterGUID, "player", aura.auraInstanceID)
        if ok then guid = result end
    end
    if not guid and type(aura.sourceUnit) == "string" then
        guid = UnitGUID(aura.sourceUnit)
    end
    return guid
end

local function consider(aura)
    if type(aura) ~= "table" or isSecret(aura.isHelpful) then return end
    if not aura.isHelpful then return end
    local duration, expires = aura.duration, aura.expirationTime
    if type(duration) ~= "number" or type(expires) ~= "number" then return end
    if duration <= MIN_DURATION then return end
    if math.abs((expires - duration) - GetTime()) > FRESH then return end

    local guid = casterGUID(aura)
    if type(guid) ~= "string" or isSecret(guid) then return end
    if not guid:match("^Player%-") or guid == UnitGUID("player") then return end
    if inMyGroup(guid) or pending[guid] then return end

    local name = select(6, GetPlayerInfoByGUID(guid))
    if type(name) ~= "string" or name == "" then return end
    pending[guid] = name
    C_Timer.After(DELAY, function() fire(guid) end)
end

local function onAura(info)
    if type(info) ~= "table" or info.isFullUpdate then return end
    for _, aura in ipairs(info.addedAuras or {}) do
        consider(aura)
    end
    -- A buff cast again over an existing one comes in as an update.
    for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do
        consider(C_UnitAuras.GetAuraDataByAuraInstanceID("player", id))
    end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, unit, info)
    if event == "PLAYER_ENTERING_WORLD" then
        settleUntil = GetTime() + SETTLE
        return
    end
    if unit ~= "player" or InCombatLockdown() or GetTime() < settleUntil then return end
    pcall(onAura, info)
end)

function addon.MI_BuffThanks_SetEnabled()
    if addon.db.general_thankBuffs then
        settleUntil = GetTime() + SETTLE
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterUnitEvent("UNIT_AURA", "player")
    else
        f:UnregisterAllEvents()
        wipe(pending)
    end
end
