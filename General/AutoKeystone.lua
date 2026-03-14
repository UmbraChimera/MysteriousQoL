local _, addon = ...

-- Automatically slots your Mythic+ keystone when the Challenge Mode frame opens.

local function SlotKeystone()
    if not addon.db.general_autoKeystone then return end
    if C_ChallengeMode.HasSlottedKeystone() then return end

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local classID, subClassID = select(6, C_Item.GetItemInfoInstant(info.itemID))
                -- classID 16 = Reagent (was 106 pre-DF), subClassID 13 = Keystone
                if classID == 16 and subClassID == 13 then
                    C_Container.PickupContainerItem(bag, slot)
                    if C_ChallengeMode.SlotKeystone then
                        C_ChallengeMode.SlotKeystone()
                    end
                    return
                end
            end
        end
    end
end

-- Wait for Blizzard_ChallengesUI to load, then hook the keystone frame
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_ChallengesUI" then
        f:UnregisterEvent("ADDON_LOADED")
        if ChallengesKeystoneFrame then
            ChallengesKeystoneFrame:HookScript("OnShow", SlotKeystone)
        end
    end
end)
