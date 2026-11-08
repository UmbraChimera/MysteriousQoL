local _, addon = ...

-- Reagent reminder for Forever. Warns when you are low on a reagent for a
-- spell you know: on login, when entering an instance, when your party fills
-- up to 5, and at a vendor. Item and spell IDs are from Wowhead's Forever
-- database ("Reagent for" on each item).
--
-- Each reagent has its own warn-below setting; 0 means use the overall one.
-- "ranks" is a list of { spell, item } in rank order. The highest rank you
-- know decides which item is checked, so Rebirth asks for the seed your top
-- rank uses.

local PREFIX = "|cff00ccff[MysteriousQoL]|r "
local SHOW_FOR = 5

local REAGENTS = {
    WARLOCK = {
        { key = "forever_reagents_soulShard", label = "Soul Shard",
          ranks = { { 697, 6265 }, { 6201, 6265 }, { 693, 6265 } } },
    },
    MAGE = {
        { key = "forever_reagents_arcanePowder", label = "Arcane Powder",
          ranks = { { 23028, 17020 } } },
        { key = "forever_reagents_teleport", label = "Rune of Teleportation",
          ranks = { { 3561, 17031 }, { 3562, 17031 }, { 3563, 17031 }, { 3565, 17031 },
                    { 3566, 17031 }, { 3567, 17031 } } },
        { key = "forever_reagents_portal", label = "Rune of Portals",
          ranks = { { 10059, 17032 }, { 11416, 17032 }, { 11417, 17032 }, { 11418, 17032 },
                    { 11419, 17032 }, { 11420, 17032 } } },
    },
    PRIEST = {
        { key = "forever_reagents_candle", label = "Holy or Sacred Candle",
          ranks = { { 21562, 17028 }, { 21564, 17029 } } },
    },
    PALADIN = {
        { key = "forever_reagents_divinity", label = "Symbol of Divinity",
          ranks = { { 19752, 17033 } } },
        { key = "forever_reagents_kings", label = "Symbol of Kings",
          ranks = { { 25782, 21177 }, { 25894, 21177 }, { 25898, 21177 } } },
    },
    DRUID = {
        { key = "forever_reagents_wild", label = "Wild Berries or Thornroot",
          ranks = { { 21849, 17021 }, { 21850, 17026 } } },
        { key = "forever_reagents_rebirth", label = "Rebirth Seed",
          ranks = { { 20484, 17034 }, { 20739, 17035 }, { 20742, 17036 },
                    { 20747, 17037 }, { 20748, 17038 } } },
    },
    SHAMAN = {
        { key = "forever_reagents_ankh", label = "Ankh",
          ranks = { { 20608, 17030 } } },
    },
    ROGUE = {
        { key = "forever_reagents_flash", label = "Flash Powder",
          ranks = { { 1856, 5140 }, { 1857, 5140 } } },
        { key = "forever_reagents_blinding", label = "Blinding Powder",
          ranks = { { 2094, 5530 } } },
    },
}

local CLASS_NAMES = {
    WARLOCK = "Warlock", MAGE = "Mage", PRIEST = "Priest", PALADIN = "Paladin",
    DRUID = "Druid", SHAMAN = "Shaman", ROGUE = "Rogue",
}

local function itemFor(entry)
    local item
    for _, pair in ipairs(entry.ranks) do
        if IsPlayerSpell(pair[1]) then item = pair[2] end
    end
    return item
end

local function thresholdFor(entry)
    local own = addon.db[entry.key]
    if own and own > 0 then return own end
    return addon.db.forever_reagents_threshold
end

local frame = addon.MI_CreateBouncingReminder("MysteriousQoL_ReagentReminderFrame", {
    baseY    = 220,
    bounce   = 6,
    speed    = 3.0,
    fontSize = 26,
    color    = { 1, 0.5, 0.1, 1 },
    shadow   = { 3, -3 },
    width    = 600,
    height   = 90,
    strata   = "HIGH",
})

local hideTimer

local function check()
    if not addon.db.forever_reagents_enabled then return end
    local list = REAGENTS[select(2, UnitClass("player"))]
    if not list then return end

    local lines = {}
    for _, entry in ipairs(list) do
        local item = itemFor(entry)
        if item then
            local count = C_Item.GetItemCount(item)
            if count < thresholdFor(entry) then
                local name = C_Item.GetItemNameByID(item) or entry.label
                lines[#lines + 1] = string.format("Low on %s (%d)", name, count)
            end
        end
    end
    if #lines == 0 then return end

    for _, line in ipairs(lines) do print(PREFIX .. line) end
    frame.text:SetText(table.concat(lines, "\n"))
    frame.ResetBounce()
    frame:Show()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(SHOW_FOR, function()
        hideTimer = nil
        frame:Hide()
    end)
end

local partySize = 0
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, isLogin, isReload)
    if event == "PLAYER_ENTERING_WORLD" then
        partySize = GetNumGroupMembers()
        -- Item names can still be loading right after a loading screen.
        if isLogin or (not isReload and IsInInstance()) then
            C_Timer.After(3, check)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        local size = IsInRaid() and 0 or GetNumGroupMembers()
        if size == 5 and partySize < 5 then check() end
        partySize = size
    elseif event == "MERCHANT_SHOW" then
        check()
    end
end)

function addon.MI_Reagents_SetEnabled()
    if addon.db.forever_reagents_enabled then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("GROUP_ROSTER_UPDATE")
        events:RegisterEvent("MERCHANT_SHOW")
        partySize = GetNumGroupMembers()
    else
        events:UnregisterAllEvents()
        frame:Hide()
    end
end

-- For the settings panel: this class's reagents, or every class's with all
-- set (debug). Each has key, label and class (English class name).
function addon.MI_Reagents_List(all)
    local out = {}
    local own = select(2, UnitClass("player"))
    for class, list in pairs(REAGENTS) do
        if all or class == own then
            for _, entry in ipairs(list) do
                out[#out + 1] = { key = entry.key, label = entry.label, class = CLASS_NAMES[class] }
            end
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

function addon.MI_Reagents_AllKeys()
    local keys = {}
    for _, list in pairs(REAGENTS) do
        for _, entry in ipairs(list) do keys[#keys + 1] = entry.key end
    end
    return keys
end
