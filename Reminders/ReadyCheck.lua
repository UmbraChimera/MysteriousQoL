local _, addon = ...

-- Personal-only ready-check preflight. This never changes the native ready
-- check response and deliberately does not inspect or report on other players.
local DURABILITY_THRESHOLD = 0.75
local SOULSTONE_SPELL_ID = 20707
local HEALTHSTONE_ITEM_IDS = {
    [5512] = true,  -- Healthstone
    [36891] = true, -- Demonic Healthstone
    [224464] = true, -- Demonic Healthstone (Midnight)
}

-- Midnight Season 1 flask aura spell IDs. Food buffs share the "Well Fed"
-- aura name, so that check is intentionally name-based until Blizzard exposes
-- a stable food category API.
local FLASK_AURAS = {
    [1235108] = true, -- Flask of the Magisters
    [1235110] = true, -- Flask of the Blood Knights
    [1235111] = true, -- Flask of the Shattered Sun
}

local WELL_FED_AURAS = {
    [1284650] = true, -- Hearty Well Fed (Midnight)
    [1233724] = true, -- Hearty Well Fed (Midnight feast)
    [462187] = true,  -- Hearty Well Fed (legacy hearty food)
}

local weaponEquipLocs = {
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

local function hasAuraBySpellID(spellID)
    if C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellID) ~= nil
    end
    return C_UnitAuras.GetUnitAuraBySpellID("player", spellID, "HELPFUL") ~= nil
end

local function hasWellFed()
    if C_UnitAuras.GetAuraDataBySpellName("player", "Well Fed", "HELPFUL") then return true end
    for spellID in pairs(WELL_FED_AURAS) do
        if hasAuraBySpellID(spellID) then return true end
    end
    return false
end

local function hasFlask()
    for spellID in pairs(FLASK_AURAS) do
        if hasAuraBySpellID(spellID) then return true end
    end
    return false
end

local function equippedWeapon(slot)
    local itemID = GetInventoryItemID("player", slot)
    if not itemID then return false end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    return weaponEquipLocs[equipLoc] == true
end

local function missingWeaponBuffs()
    local getEnchantInfo = C_Item and C_Item.GetWeaponEnchantInfo or GetWeaponEnchantInfo
    if not getEnchantInfo then return nil end
    local hasMain, _, _, _, hasOff = getEnchantInfo()
    local missing = {}
    if equippedWeapon(16) and not hasMain then missing[#missing + 1] = "Main-Hand Weapon Buff" end
    if equippedWeapon(17) and not hasOff then missing[#missing + 1] = "Off-Hand Weapon Buff" end
    return missing
end

local function lowestDurability()
    local lowest = 1
    for slot = 1, 19 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            lowest = math.min(lowest, current / maximum)
        end
    end
    return lowest
end

local function groupHasWarlock()
    local _, playerClass = UnitClass("player")
    if playerClass == "WARLOCK" then return true end
    local count = GetNumGroupMembers()
    if count == 0 then return false end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) then
            local _, class = UnitClass(unit)
            if class == "WARLOCK" then return true end
        end
    end
    return false
end

local function groupHasSoulstone()
    if hasAuraBySpellID(SOULSTONE_SPELL_ID) then return true end
    local count = GetNumGroupMembers()
    if count == 0 then return false end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsConnected(unit)
            and C_UnitAuras.GetUnitAuraBySpellID(unit, SOULSTONE_SPELL_ID) then
            return true
        end
    end
    return false
end

local function hasHealthstoneInBags()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and HEALTHSTONE_ITEM_IDS[info.itemID] then return true end
        end
    end
    return false
end

local function collectProblems()
    local problems = {}
    local durability = lowestDurability()
    if durability <= DURABILITY_THRESHOLD then
        problems[#problems + 1] = format("Gear Durability (%d%%)", durability * 100)
    end

    local missingWeapons = missingWeaponBuffs()
    if missingWeapons then
        for _, problem in ipairs(missingWeapons) do problems[#problems + 1] = problem end
    end

    if not hasWellFed() then problems[#problems + 1] = "Well Fed" end
    if not hasFlask() then problems[#problems + 1] = "Flask" end
    if groupHasWarlock() and not hasHealthstoneInBags() then
        problems[#problems + 1] = "Healthstone" 
    end
    if groupHasWarlock() and not groupHasSoulstone() then
        problems[#problems + 1] = "Soulstone on a Group Member"
    end
    return problems
end

local BAR_TEXTURE = [[Interface\Buttons\WHITE8x8]]
local popup = CreateFrame("Frame", "MysteriousQoL_ReadyCheckPopup", UIParent, "BackdropTemplate")
popup:SetSize(460, 220)
popup:SetPoint("CENTER", UIParent, "CENTER", 0, 125)
popup:SetFrameStrata("DIALOG")
popup:SetFrameLevel(200)
popup:SetClampedToScreen(true)
popup:SetMovable(true)
popup:EnableMouse(true)
popup:RegisterForDrag("LeftButton")
popup:SetScript("OnDragStart", popup.StartMoving)
popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
popup:SetBackdrop({
    bgFile = BAR_TEXTURE,
    edgeFile = BAR_TEXTURE,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
popup:SetBackdropColor(0.045, 0.05, 0.06, 0.98)
popup:SetBackdropBorderColor(0.008, 0.486, 0.565, 0.8)
popup:Hide()
table.insert(UISpecialFrames, "MysteriousQoL_ReadyCheckPopup")

local header = popup:CreateTexture(nil, "ARTWORK")
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(48)
header:SetColorTexture(0.025, 0.11, 0.13, 1)

local accent = popup:CreateTexture(nil, "OVERLAY")
accent:SetPoint("TOPLEFT", 1, -1)
accent:SetPoint("TOPRIGHT", -1, -1)
accent:SetHeight(3)

local title = popup:CreateFontString(nil, "OVERLAY")
title:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
title:SetPoint("TOPLEFT", 18, -13)
title:SetTextColor(1, 1, 1, 1)
title:SetText("READY CHECK PREFLIGHT")

local status = popup:CreateFontString(nil, "OVERLAY")
status:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

local details = popup:CreateFontString(nil, "OVERLAY")
details:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
details:SetPoint("TOPLEFT", 22, -69)
details:SetPoint("TOPRIGHT", -22, -69)
details:SetTextColor(0.92, 0.94, 0.96, 1)
details:SetJustifyH("LEFT")
details:SetJustifyV("TOP")

local hint = popup:CreateFontString(nil, "OVERLAY")
hint:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
hint:SetPoint("BOTTOMLEFT", 18, 12)
hint:SetTextColor(0.48, 0.55, 0.58, 1)
hint:SetText("Drag to move - Close with Esc or X")

local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -3, -4)
close:SetScript("OnClick", function() popup:Hide() end)

local function showPreflight()
    if not addon.db.combat_readyCheck_enabled then return end
    local problems = collectProblems()
    if #problems == 0 then
        accent:SetColorTexture(0.16, 0.78, 0.36, 1)
        status:SetTextColor(0.30, 0.92, 0.49, 1)
        status:SetText("ALL CHECKS PASSED")
        details:SetText("Your gear, buffs, and consumables are ready.")
    else
        accent:SetColorTexture(0.94, 0.27, 0.27, 1)
        status:SetTextColor(1, 0.48, 0.48, 1)
        status:SetText(format("%d %s NEED%s ATTENTION", #problems, #problems == 1 and "ITEM" or "ITEMS", #problems == 1 and "S" or ""))
        details:SetText("|cffff6b6b-|r  " .. table.concat(problems, "\n|cffff6b6b-|r  "))
    end
    popup:Show()
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "READY_CHECK" then
        -- Let the game finish updating transient aura/inventory state first.
        C_Timer.After(0, showPreflight)
    end
end)

function addon.MI_ReadyCheck_SetEnabled()
    if addon.db.combat_readyCheck_enabled then
        eventFrame:RegisterEvent("READY_CHECK")
    else
        eventFrame:UnregisterAllEvents()
        popup:Hide()
    end
end

function addon.MI_ReadyCheck_Init()
    addon.MI_ReadyCheck_SetEnabled()
end
