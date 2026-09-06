local _, addon = ...

-- Automatically slots your Mythic+ keystone when the Challenge Mode frame opens.

local function SlotKeystone()
    if not addon.db or not addon.db.general_autoKeystone then return end
    if C_ChallengeMode.HasSlottedKeystone() then return end

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and C_Item.IsItemKeystoneByID(info.itemID) then
                C_Container.PickupContainerItem(bag, slot)
                C_ChallengeMode.SlotKeystone()
                return
            end
        end
    end
end

local hooked = false

local function HookKeystoneFrame()
    if hooked or not ChallengesKeystoneFrame then return end
    hooked = true
    ChallengesKeystoneFrame:HookScript("OnShow", SlotKeystone)

    -- The Blizzard UI may have loaded and opened before this addon was enabled.
    if ChallengesKeystoneFrame:IsShown() then
        C_Timer.After(0, SlotKeystone)
    end
end

-- Hook immediately when possible, otherwise wait for Blizzard_ChallengesUI.
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_ChallengesUI" then
        f:UnregisterEvent("ADDON_LOADED")
        HookKeystoneFrame()
    end
end)

local _, challengesLoaded = C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI")
if challengesLoaded then
    HookKeystoneFrame()
else
    f:RegisterEvent("ADDON_LOADED")
end
