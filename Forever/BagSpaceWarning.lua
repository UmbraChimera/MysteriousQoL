local _, addon = ...

-- Warns when a loot window opens and free bag space is running out. Forever only.
-- At a level 60 cap with classic bag sizes this is far easier to hit than on retail.

local HIDE_AFTER = 2

-- Clients without reagent bags report 4 equipped slots, so bag 5 is never queried
-- there and the reagent count stays at zero.
local REAGENT_BAG = Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
local NUM_BAGS    = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4

local hideTimer = nil

local bagFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_BagSpaceWarningFrame", {
    baseY    = 160,
    bounce   = 6,
    speed    = 3.0,
    fontSize = 30,
    color    = { 1, 0.5, 0.1, 1 },
    shadow   = { 3, -3 },
    width    = 600,
    height   = 90,
    strata   = "HIGH",
})

-- Returns free general-purpose slots, free reagent bag slots, and whether a reagent
-- bag is equipped at all. The two counts stay separate because neither bag can take
-- the other's drops: pooling them reports space a given item cannot actually use, so
-- a full reagent bag hides behind roomy normal bags and vice versa. Profession bags
-- are left out of both -they only accept their own trade goods.
local function freeSlots()
    local general, reagent, reagentSlots = 0, 0, 0
    for bag = 0, NUM_BAGS do
        if bag == REAGENT_BAG then
            reagentSlots = C_Container.GetContainerNumSlots(bag) or 0
            if reagentSlots > 0 then
                reagent = reagent + (C_Container.GetContainerNumFreeSlots(bag) or 0)
            end
        else
            local slots, bagType = C_Container.GetContainerNumFreeSlots(bag)
            if slots and (not bagType or bagType == 0) then
                general = general + slots
            end
        end
    end
    return general, reagent, reagentSlots > 0
end

-- "Bags are full!" / "1 bag slot left" / "3 bag slots left"
local function slotPhrase(free, noun, fullText)
    if free == 0 then
        return fullText
    elseif free == 1 then
        return "1 " .. noun .. " slot left"
    end
    return string.format("%d %s slots left", free, noun)
end

local function hide()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
    bagFrame.ResetBounce()
    bagFrame:Hide()
end

local function checkBagSpace()
    if not addon.db.forever_bagSpace_enabled then return end

    local threshold = addon.db.forever_bagSpace_threshold
    local general, reagent, hasReagentBag = freeSlots()

    -- Either count crossing the threshold is worth warning about on its own.
    local generalLow = general <= threshold
    local reagentLow = hasReagentBag and not addon.db.forever_bagSpace_ignoreReagent
        and reagent <= threshold

    if not generalLow and not reagentLow then
        hide()
        return
    end

    local parts = {}
    if generalLow then
        parts[#parts + 1] = slotPhrase(general, "bag", "Bags are full!")
    end
    if reagentLow then
        parts[#parts + 1] = slotPhrase(reagent, "reagent", "Reagent bag is full!")
    end
    bagFrame.text:SetText(table.concat(parts, "\n"))

    bagFrame.ResetBounce()
    bagFrame:Show()

    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(HIDE_AFTER, function()
        hideTimer = nil
        bagFrame:Hide()
    end)
end

local eventFrame = CreateFrame("Frame")
local registered = false

-- LOOT_READY fires before the loot window is populated and, unlike LOOT_OPENED,
-- still lands when auto-loot empties a corpse instantly. Nothing hides on
-- LOOT_CLOSED: with auto-loot (or Faster Auto-Loot) the close event arrives in the
-- same frame as the open, which hid the warning before it was ever drawn. The
-- timer is the only thing that dismisses it.
local function onEvent()
    checkBagSpace()
end

-- Called on load and whenever the setting changes.
function addon.MI_BagSpace_SetEnabled()
    if addon.db.forever_bagSpace_enabled then
        if registered then return end
        registered = true
        eventFrame:RegisterEvent("LOOT_READY")
        eventFrame:RegisterEvent("LOOT_OPENED")
        eventFrame:SetScript("OnEvent", onEvent)
    else
        if not registered then return end
        registered = false
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
        hide()
    end
end
