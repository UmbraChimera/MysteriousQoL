local _, addon = ...

-- Switches between the tracking spells you tick on a timer while out of combat, so they all
-- show on the minimap. With only one ticked or known, keeps that one on (also after dying).
-- Forever only.

-- Every tracker that can be ticked. class/race only tag it in the all-classes debug view.
-- alongside: stays on next to the others instead of taking turns.
local TRACKERS = {
    { key = "forever_autoTracking_herbs",      id = 2383,  name = "Find Herbs" },
    { key = "forever_autoTracking_minerals",   id = 2580,  name = "Find Minerals" },
    { key = "forever_autoTracking_fish",       id = 43308, name = "Find Fish" },
    { key = "forever_autoTracking_treasure",   id = 2481,  name = "Find Treasure", race = "Dwarf", alongside = true },
    -- camp: the camp item that also gives it at camp, to anyone.
    { key = "forever_autoTracking_beasts",     id = 1494,  name = "Track Beasts", camp = "Field Guide" },
    { key = "forever_autoTracking_humanoids",  id = 19883, name = "Track Humanoids", class = "HUNTER" },
    { key = "forever_autoTracking_undead",     id = 19884, name = "Track Undead", class = "HUNTER" },
    { key = "forever_autoTracking_hidden",     id = 19885, name = "Track Hidden", class = "HUNTER" },
    { key = "forever_autoTracking_elementals", id = 19880, name = "Track Elementals", class = "HUNTER" },
    { key = "forever_autoTracking_demons",     id = 19878, name = "Track Demons", class = "HUNTER" },
    { key = "forever_autoTracking_giants",     id = 19882, name = "Track Giants", class = "HUNTER" },
    { key = "forever_autoTracking_dragonkin",  id = 19879, name = "Track Dragonkin", class = "HUNTER" },
    { key = "forever_autoTracking_catHumanoids", id = 5225, name = "Track Humanoids", class = "DRUID", catOnly = true },
    { key = "forever_autoTracking_senseUndead", id = 5502, name = "Sense Undead", class = "PALADIN" },
    { key = "forever_autoTracking_senseDemons", id = 5500, name = "Sense Demons", class = "WARLOCK" },
}
local BY_ID, BY_NAME = {}, {}
for _, t in ipairs(TRACKERS) do
    BY_ID[t.id] = t
    -- A camp's version may come with its own spell ID, so those are also found by name.
    if t.camp then BY_NAME[t.name] = t end
end

local function trackerFor(info)
    return info and (BY_ID[info.spellID] or BY_NAME[info.name])
end

local CAT_FORM = 1
local GCD = 61304

local ticker
local mutedSFX = false
local owned -- spell ID this module last turned on

-- The trackers the settings show: the ones this character knows (or every one).
-- Camp trackers are always shown, since they're hard to tick only while at camp.
-- unlockedFrom is set on one you only get from a camp item.
function addon.MI_AutoTracking_List(all)
    local inMenu = {}
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local t = trackerFor(C_Minimap.GetTrackingInfo(i))
        if t then inMenu[t] = true end
    end
    local out = {}
    for _, t in ipairs(TRACKERS) do
        local known = IsPlayerSpell(t.id)
        if all or known or inMenu[t] or t.camp then
            local entry = setmetatable({}, { __index = t })
            if not known and (t.camp or inMenu[t]) then entry.unlockedFrom = t.camp or "a camp item" end
            out[#out + 1] = entry
        end
    end
    return out
end

local function usable(t)
    if t.catOnly and GetShapeshiftFormID() ~= CAT_FORM then return false end
    return true
end

-- Ticked trackers this character knows, split into the rotation and the ones kept on
-- alongside, and whether a tracker you picked yourself is on.
local function scan()
    local rotation, alongside, otherOn = {}, {}, false
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        local t = trackerFor(info)
        if t and addon.db[t.key] and usable(t) then
            local e = { index = i, id = info.spellID, active = info.active }
            if t.alongside then
                alongside[#alongside + 1] = e
            else
                rotation[#rotation + 1] = e
            end
        elseif info and info.active and info.spellID and info.spellID ~= owned
            and not (t and t.alongside) then
            otherOn = true
        end
    end
    return rotation, alongside, otherOn
end

local function busy()
    if InCombatLockdown() or UnitAffectingCombat("player") then return true end
    if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return true end
    -- No nodes in cities, inns or instances.
    if IsResting() or IsInInstance() then return true end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return true end
    if LootFrame and LootFrame:IsShown() then return true end
    local ok, onGCD = pcall(function()
        local cd = C_Spell.GetSpellCooldown(GCD)
        return cd and cd.startTime > 0 and cd.startTime + cd.duration > GetTime()
    end)
    return not ok or onGCD
end

-- Each switch is a cast with its own sound, so sound effects are muted around it.
local function unmute()
    if mutedSFX or addon.db.forever_autoTracking_unmute then
        SetCVar("Sound_EnableSFX", "1")
        mutedSFX = false
        addon.db.forever_autoTracking_unmute = nil
    end
end

local function mute()
    if GetCVar("Sound_EnableSFX") ~= "1" then return end
    SetCVar("Sound_EnableSFX", "0")
    mutedSFX = true
    -- Puts the sound back at the next login if a reload happens in between.
    addon.db.forever_autoTracking_unmute = true
    C_Timer.After(2.5, unmute)
end

local function switch(e)
    mute()
    owned = e.id
    C_Minimap.SetTracking(e.index, true)
end

local function tick()
    if busy() then return end
    local rotation, alongside, otherOn = scan()
    -- You picked something else yourself: leave it on.
    if otherOn then return end
    -- One cast per tick, the global cooldown blocks a second.
    for _, e in ipairs(alongside) do
        if not e.active then
            switch(e)
            return
        end
    end
    local n = #rotation
    if n == 0 then return end
    local current
    for i, e in ipairs(rotation) do
        if e.active then current = i end
    end
    if n == 1 then
        if not current then switch(rotation[1]) end
        return
    end
    switch(rotation[current and (current % n + 1) or 1])
end

function addon.MI_AutoTracking_SetEnabled()
    unmute()
    if ticker then ticker:Cancel() ticker = nil end
    if not addon.db.forever_autoTracking_enabled then return end
    ticker = C_Timer.NewTicker(addon.db.forever_autoTracking_delay, tick)
end
