local _, addon = ...

-- Item-level hints only: these do not rank stats, set bonuses, or weapon setups.
local slotsByEquipLoc = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_RANGED = { 16 },
    INVTYPE_RANGEDRIGHT = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
}
local armorByClass = {
    WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4,
    HUNTER = 3, SHAMAN = 3, EVOKER = 3,
    ROGUE = 2, MONK = 2, DRUID = 2, DEMONHUNTER = 2,
    PRIEST = 1, MAGE = 1, WARLOCK = 1,
}
-- Midnight permanent enchants, plus tailoring/leatherworking leg enhancements.
-- Shields and caster off-hands cannot receive weapon enchants.
local enchantSlots = {
    [1] = "HeadSlot", [3] = "ShoulderSlot", [5] = "ChestSlot",
    [7] = "LegsSlot", [8] = "FeetSlot", [11] = "Finger0Slot",
    [12] = "Finger1Slot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot",
}
local weaponEnchantTypes = {
    INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true,
}
local frame = CreateFrame("Frame")
local arrows, overlays, hookedContainers = {}, {}, {}
local requestedItems = {}
local queued, paperDollHooked = false, false

-- requestedItems: true while loading, false once the load came back.
local function itemReady(itemID)
    if C_Item.IsItemDataCachedByID(itemID) then return true end
    if requestedItems[itemID] == nil then
        requestedItems[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return false
end

local function equippedLevel(slot)
    local itemID = GetInventoryItemID("player", slot)
    if not itemID then return 0 end
    if not itemReady(itemID) then return nil end
    return C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot))
end

-- Class and equipped gear, read once per bag instead of once per slot.
local gear = { levels = {} }
local bagLoc = ItemLocation:CreateEmpty()

local function readGear()
    local mainLink = GetInventoryItemLink("player", 16)
    local offLink = GetInventoryItemLink("player", 17)
    gear.armor = armorByClass[select(2, UnitClass("player"))]
    gear.offLink = offLink
    gear.mainType = mainLink and select(4, C_Item.GetItemInfoInstant(mainLink))
    gear.offType = offLink and select(4, C_Item.GetItemInfoInstant(offLink))
    wipe(gear.levels)
end

-- nil when the item isn't cached yet.
local function gearLevel(slot)
    local level = gear.levels[slot]
    if level == nil then
        level = equippedLevel(slot) or false
        gear.levels[slot] = level
    end
    return level or nil
end

local function isUpgrade(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or info.isFiltered or not info.itemID or not itemReady(info.itemID) then return false end
    if not C_PlayerInfo.CanUseItem(info.itemID) then return false end
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(info.itemID)
    local slots = slotsByEquipLoc[equipLoc]
    if not slots then return false end
    if classID == 4 and subclassID >= 1 and subclassID <= 4 and equipLoc ~= "INVTYPE_CLOAK"
        and subclassID ~= gear.armor then return false end
    bagLoc:SetBagAndSlot(bag, slot)
    local level = C_Item.GetCurrentItemLevel(bagLoc)
    if not level or level <= 0 then return false end
    local baseline
    for _, equippedSlot in ipairs(slots) do
        local current = gearLevel(equippedSlot)
        if current == nil then return false end -- don't treat uncached gear as empty
        baseline = baseline and math.min(baseline, current) or current
    end
    if equipLoc == "INVTYPE_WEAPON" and gear.offType == "INVTYPE_WEAPON" then
        local offLevel = gearLevel(17)
        if offLevel == nil then return false end
        baseline = math.min(baseline, offLevel)
    elseif equipLoc == "INVTYPE_2HWEAPON" and gear.offLink then
        local offLevel = gearLevel(17)
        if offLevel == nil then return false end
        -- With two two-handers it can replace either one. Otherwise it
        -- replaces both hands, so it has to beat both.
        if gear.mainType == "INVTYPE_2HWEAPON" and gear.offType == "INVTYPE_2HWEAPON" then
            baseline = math.min(baseline, offLevel)
        else
            baseline = math.max(baseline, offLevel)
        end
    elseif slots[1] == 17 and not gear.offLink and gear.mainType == "INVTYPE_2HWEAPON" then
        baseline = gearLevel(16)
        if baseline == nil then return false end
    end
    return level > baseline
end

-- Only the backpack and equipped bags. Forever reuses these container frames for
-- bank bags. Calling Blizzard's Lua bag methods from addon code taints the bank
-- panel's state (bankType), and from then on clicking any bag item - eating,
-- equipping - is "blocked from an action only available to the Blizzard UI"
-- until a reload. So this only uses built-in frame methods (GetID, IsShown) and
-- plain field reads, never the container/button mixin methods.
local function isPlayerBagID(id)
    return id and id >= 0 and id <= (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5)
end

local function isPlayerBag(container)
    return isPlayerBagID(container:GetID())
end

local function updateBag(container)
    if not addon.db or not addon.db.ui_bagUpgrade_enabled or not container:IsShown() then return end
    if not isPlayerBag(container) or type(container.Items) ~= "table" then return end
    readGear()
    for _, button in ipairs(container.Items) do
        -- The combined bag holds buttons from every bag, so prefer the button's own bag.
        local bag = button.bagID or container:GetID()
        local show = button:IsShown() and isPlayerBagID(bag) and isUpgrade(bag, button:GetID())
        local arrow = arrows[button]
        if show and not arrow then
            arrow = button:CreateTexture(nil, "OVERLAY", nil, 7)
            arrow:SetAtlas("bags-greenarrow")
            arrow:SetSize(24, 24)
            arrow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            arrows[button] = arrow
        end
        if arrow then arrow:SetShown(show) end
    end
end

-- Missing-enchant highlighting is retail only for now. Forever's enchantable slots
-- differ (back, wrist and hands are enchantable, rings are not) and only matter at
-- the level 60 cap, so the slot list needs redoing before this is turned back on.
local function enchantsEnabled()
    return addon.RETAIL and addon.db and addon.db.ui_missingEnchant_enabled
end

local function missingEnchant(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return false end
    if slot == 16 or slot == 17 then
        local _, _, _, equipLoc, _, _, subclassID = C_Item.GetItemInfoInstant(link)
        if not weaponEnchantTypes[equipLoc] or subclassID == 19 then return false end -- Wands.
    end
    local enchant = link:match("item:%d+:(%d*):")
    -- Missing/unavailable links are unknown, never a missing-enchant warning.
    return enchant ~= nil and (enchant == "" or tonumber(enchant) == 0)
end

local function updatePaperDoll()
    for slot, name in pairs(enchantSlots) do
        local button = _G["Character" .. name]
        if button then
            local show = enchantsEnabled() and missingEnchant(slot)
            local overlay = overlays[button]
            if show and not overlay then
                overlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
                overlay:SetColorTexture(1, 0, 0, 0.38)
                overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
                overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
                overlays[button] = overlay
            end
            if overlay then overlay:SetShown(show == true) end
        end
    end
end

local function refresh()
    queued = false
    if not addon.db then return end
    -- Clear first so reused/removed bag buttons cannot retain old upgrade hints.
    for _, arrow in pairs(arrows) do arrow:Hide() end
    if addon.db.ui_bagUpgrade_enabled then
        local containers = { ContainerFrameCombinedBags }
        for i = 1, (NUM_CONTAINER_FRAMES or 13) do
            containers[#containers + 1] = _G["ContainerFrame" .. i]
        end
        for _, container in ipairs(containers) do
            if container.UpdateItems and isPlayerBag(container) then
                if not hookedContainers[container] then
                    hookedContainers[container] = true
                    container:HookScript("OnShow", function(self) updateBag(self) end)
                    hooksecurefunc(container, "UpdateItems", updateBag)
                    if container.UpdateSearchResults then
                        hooksecurefunc(container, "UpdateSearchResults", updateBag)
                    end
                end
                updateBag(container)
            end
        end
    end
    if enchantsEnabled() and not paperDollHooked and PaperDollItemSlotButton_Update then
        paperDollHooked = true
        hooksecurefunc("PaperDollItemSlotButton_Update", updatePaperDoll)
    end
    updatePaperDoll()
end

local function queueRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0, refresh)
end

function addon.MI_GearIndicators_RefreshState()
    frame:UnregisterAllEvents()
    if addon.db.ui_bagUpgrade_enabled or enchantsEnabled() then
        -- No BAG_UPDATE_DELAYED: open bags call UpdateItems on their own, and that's hooked.
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED",
            "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "ITEM_DATA_LOAD_RESULT",
            "PLAYER_LEVEL_UP", "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED" }) do
            frame:RegisterEvent(event)
        end
    end
    refresh()
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
    -- Only items we asked for, not every tooltip or chat link.
    if event == "ITEM_DATA_LOAD_RESULT" then
        if not requestedItems[arg1] then return end
        requestedItems[arg1] = false
    end
    queueRefresh()
end)
