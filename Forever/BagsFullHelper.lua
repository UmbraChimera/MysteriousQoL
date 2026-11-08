local _, addon = ...

-- When loot does not fit, offers the cheapest item in your bags to destroy and
-- loots in the same click. Forever only.
--
-- Triggered by the "inventory is full" error. With a loot window open it shows
-- what you would get; without one (a herb, a chest) it only makes room. Anything
-- better than grey takes a second click.

local PREFIX = "|cff00ccff[MysteriousQoL]|r "
local NUM_BAGS = NUM_BAG_SLOTS or 4

-- Never suggested: hearthstone, thieves' tools, profession tools.
local KEEP_ITEMS = {
    [6948] = true,  -- Hearthstone
    [5060] = true,  -- Thieves' Tools
    [2901] = true,  -- Mining Pick
    [7005] = true,  -- Skinning Knife
    [5956] = true,  -- Blacksmith Hammer
    [6219] = true,  -- Arclight Spanner
    [10498] = true, -- Gyromatic Micro-Adjustor
    [6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true, -- runed rods
    [6217] = true, [6338] = true, [11128] = true, [11144] = true, [16206] = true, -- rods
}

local CLASS_WEAPON, SUBCLASS_FISHING_POLE = 2, 20
local CLASS_RECIPE, CLASS_QUEST = 9, 12

local function formatMoney(copper)
    if not copper or copper <= 0 then return "|cff9d9d9dno value|r" end
    return GetCoinTextureString and GetCoinTextureString(copper) or (copper .. "c")
end

local function neverList()
    if type(addon.db.forever_bagsFull_never) ~= "table" then
        addon.db.forever_bagsFull_never = {}
    end
    return addon.db.forever_bagsFull_never
end

local function freeGeneralSlots()
    local free = 0
    for bag = 0, NUM_BAGS do
        local n, bagType = C_Container.GetContainerNumFreeSlots(bag)
        if n and (not bagType or bagType == 0) then free = free + n end
    end
    return free
end

local function sellPrice(link)
    local price = select(11, C_Item.GetItemInfo(link))
    return tonumber(price) or 0
end

local function isQuestItem(bag, slot)
    local info = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
    return info and (info.isQuestItem or info.questID) and true or false
end

-- Everything that may be destroyed, cheapest stack first.
local function findCandidates()
    local list = {}
    local never = neverList()
    local lowOnly = addon.db.forever_bagsFull_lowOnly
    for bag = 0, NUM_BAGS do
        local _, bagType = C_Container.GetContainerNumFreeSlots(bag)
        -- Profession bags only hold their own goods, so freeing them does not help.
        if not bagType or bagType == 0 then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local id = info and info.itemID
                if id and not info.hasNoValue and not info.isLocked and not never[id]
                    and not KEEP_ITEMS[id] and not isQuestItem(bag, slot) then
                    local _, _, quality, _, _, _, _, _, _, _, price, classID, subclassID =
                        C_Item.GetItemInfo(info.hyperlink)
                    quality = quality or info.quality or 1
                    price = tonumber(price) or 0
                    local skip = price <= 0 or quality >= 4
                        or classID == CLASS_RECIPE or classID == CLASS_QUEST
                        or (classID == CLASS_WEAPON and subclassID == SUBCLASS_FISHING_POLE)
                        or (lowOnly and quality > 1)
                    if not skip then
                        local count = info.stackCount or 1
                        list[#list + 1] = {
                            bag = bag, slot = slot, id = id, link = info.hyperlink,
                            icon = info.iconFileID, count = count, quality = quality,
                            value = price * count,
                        }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.value ~= b.value then return a.value < b.value end
        return a.id < b.id
    end)
    return list
end

-- The best thing still in the loot window: quest items and items with no sell
-- price first (they are usually why you are looting), then the most valuable.
local function bestLoot()
    local best
    for i = 1, GetNumLootItems() or 0 do
        if LootSlotHasItem(i) and GetLootSlotType(i) == Enum.LootSlotType.Item then
            local icon, name, qty, _, quality, _, isQuestItem, questID = GetLootSlotInfo(i)
            local link = GetLootSlotLink(i)
            local value = link and sellPrice(link) * (qty or 1) or 0
            local entry = {
                slot = i, link = link, name = name, icon = icon, count = qty or 1,
                quality = quality or 1, value = value,
                prio = (isQuestItem or questID or value <= 0) and true or false,
            }
            if not best or (entry.prio and not best.prio)
                or (entry.prio == best.prio and entry.value > best.value) then
                best = entry
            end
        end
    end
    return best
end

local frame
local candidates, index = {}, 1
local target -- loot entry, or nil when there is nothing to loot
local armed = false
local pendingLootSlot = nil

local function qualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function makeCard(parent, caption)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(170, 64)
    card.caption = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.caption:SetPoint("TOPLEFT", 0, 0)
    card.caption:SetText(caption)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(36, 36)
    card.icon:SetPoint("TOPLEFT", 0, -16)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = card:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    card.count:SetPoint("BOTTOMRIGHT", card.icon, "BOTTOMRIGHT", -1, 1)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 6, 0)
    card.name:SetWidth(126)
    card.name:SetJustifyH("LEFT")
    card.name:SetMaxLines(2)
    card.value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.value:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 6, 0)
    card.note = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.note:SetPoint("TOPLEFT", 0, -18)
    card.note:SetWidth(170)
    card.note:SetJustifyH("LEFT")
    card:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", GameTooltip_Hide)

    function card:SetItem(e)
        self.link = e.link
        self.icon:SetTexture(e.icon or 134400)
        self.count:SetText((e.count or 1) > 1 and e.count or "")
        local name = (e.link and e.link:match("%[(.-)%]")) or e.name or "?"
        self.name:SetText(name)
        self.name:SetTextColor(qualityColor(e.quality))
        self.value:SetText(formatMoney(e.value))
        self.icon:Show(); self.count:Show(); self.name:Show(); self.value:Show()
        self.note:Hide()
    end

    function card:SetNote(text)
        self.link = nil
        self.icon:Hide(); self.count:Hide(); self.name:Hide(); self.value:Hide()
        self.note:SetText(text)
        self.note:Show()
    end
    return card
end

local function paint()
    armed = false
    local c = candidates[index]
    if target then
        frame.gain:SetItem(target)
    else
        frame.gain:SetNote("Loot it again once there is room.")
    end
    local many = #candidates > 1
    frame.prev:SetShown(c ~= nil)
    frame.next:SetShown(c ~= nil)
    frame.prev:SetEnabled(many)
    frame.next:SetEnabled(many)
    frame.never:SetShown(c ~= nil)
    frame.counter:SetShown(c ~= nil)
    if c then
        frame.lose:SetItem(c)
        frame.counter:SetText(index .. "/" .. #candidates)
        frame.destroy:SetText(target and "Destroy & Loot" or "Destroy")
        frame.destroy:Show()
        if target and not target.prio and target.value < c.value then
            frame.sub:SetText("|cffffd27fThis loot is worth less than anything in your bags.|r")
        else
            frame.sub:SetText("Destroy a cheap item to make room.")
        end
    else
        frame.lose:SetNote("Nothing in your bags can be suggested. Quest items, recipes, tools and epics are kept.")
        frame.destroy:Hide()
        frame.sub:SetText("")
    end
end

local function hideHelper()
    if frame then frame:Hide() end
    armed = false
end

local function onDestroyClick()
    local c = candidates[index]
    if not c then return end
    -- Bags may have changed since the window opened.
    local info = C_Container.GetContainerItemInfo(c.bag, c.slot)
    if not info or info.hyperlink ~= c.link then
        addon.MI_BagsFull_Check(true)
        return
    end
    if (c.quality or 1) >= 1 and not armed then
        armed = true
        frame.destroy:SetText("Click again to destroy")
        return
    end
    ClearCursor()
    C_Container.PickupContainerItem(c.bag, c.slot)
    DeleteCursorItem()
    pendingLootSlot = target and target.slot or nil
    if not target then
        print(PREFIX .. "Destroyed " .. c.link .. " - loot it again.")
    end
    hideHelper()
end

local function createFrame()
    if frame then return end
    frame = CreateFrame("Frame", "MysteriousQoL_BagsFullFrame", UIParent, "BackdropTemplate")
    frame:SetSize(390, 150)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    frame:SetBackdropBorderColor(0.008, 0.486, 0.565, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Bags full!")
    frame.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.sub:SetPoint("TOPLEFT", 12, -30)
    frame.sub:SetWidth(340)
    frame.sub:SetJustifyH("LEFT")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function()
        pendingLootSlot = nil
        hideHelper()
    end)

    frame.lose = makeCard(frame, "Destroy:")
    frame.lose:SetPoint("TOPLEFT", 12, -48)
    frame.gain = makeCard(frame, "You get:")
    frame.gain:SetPoint("TOPLEFT", 208, -48)

    frame.next = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.next:SetSize(22, 18)
    frame.next:SetText(">")
    frame.next:SetPoint("TOPLEFT", 160, -46)
    frame.counter = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.counter:SetPoint("RIGHT", frame.next, "LEFT", -3, 0)
    frame.prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.prev:SetSize(22, 18)
    frame.prev:SetText("<")
    frame.prev:SetPoint("RIGHT", frame.counter, "LEFT", -3, 0)
    frame.prev:SetScript("OnClick", function()
        if #candidates > 0 then index = (index - 2) % #candidates + 1; paint() end
    end)
    frame.next:SetScript("OnClick", function()
        if #candidates > 0 then index = index % #candidates + 1; paint() end
    end)

    frame.never = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.never:SetSize(90, 20)
    frame.never:SetText("Never suggest")
    frame.never:SetPoint("BOTTOMLEFT", 12, 10)
    frame.never:SetScript("OnClick", function()
        local c = candidates[index]
        if not c then return end
        neverList()[c.id] = true
        print(PREFIX .. c.link .. " will not be suggested again.")
        addon.MI_BagsFull_Check(true)
    end)

    frame.destroy = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.destroy:SetSize(160, 22)
    frame.destroy:SetPoint("BOTTOMRIGHT", -12, 10)
    frame.destroy:SetScript("OnClick", onDestroyClick)
    frame:Hide()
end

-- keepPick: refresh the list but stay on the item you browsed to.
function addon.MI_BagsFull_Check(keepPick)
    if not addon.db.forever_bagsFull_enabled then return end
    if freeGeneralSlots() > 0 then
        hideHelper()
        return
    end
    createFrame()
    local lootOpen = LootFrame and LootFrame:IsShown()
    target = lootOpen and bestLoot() or nil

    local keep = keepPick and candidates[index]
    candidates, index = findCandidates(), 1
    if keep then
        for i, c in ipairs(candidates) do
            if c.bag == keep.bag and c.slot == keep.slot and c.link == keep.link then
                index = i
                break
            end
        end
    end
    paint()

    frame:ClearAllPoints()
    if lootOpen then
        frame:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 6, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    end
    frame:Show()
end

local ERRORS = {}
for _, key in ipairs({ "ERR_INV_FULL", "ERR_LOOT_NO_SPACE" }) do
    if type(_G[key]) == "string" then ERRORS[_G[key]] = true end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "UI_ERROR_MESSAGE" then
        local message = type(a2) == "string" and a2 or a1
        if ERRORS[message] then
            -- Let the loot window finish opening first.
            C_Timer.After(0.1, function() addon.MI_BagsFull_Check() end)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if pendingLootSlot then
            local slot = pendingLootSlot
            pendingLootSlot = nil
            if (GetNumLootItems() or 0) >= slot and LootSlotHasItem(slot) then
                LootSlot(slot)
                -- More loot may still not fit.
                C_Timer.After(0.4, function()
                    if LootFrame and LootFrame:IsShown() and bestLoot() then
                        addon.MI_BagsFull_Check()
                    end
                end)
            end
        elseif frame and frame:IsShown() then
            addon.MI_BagsFull_Check(true)
        end
    elseif event == "LOOT_CLOSED" then
        pendingLootSlot = nil
        if frame and frame:IsShown() and target then hideHelper() end
    end
end)

function addon.MI_BagsFull_SetEnabled()
    if addon.db.forever_bagsFull_enabled then
        eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
        eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        eventFrame:RegisterEvent("LOOT_CLOSED")
    else
        eventFrame:UnregisterAllEvents()
        pendingLootSlot = nil
        hideHelper()
    end
end
