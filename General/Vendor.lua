local _, addon = ...

-- Auto-repair and auto-sell greys when a merchant window opens.

local PREFIX = "|cff00ccff[MysteriousQoL]|r "

local function formatMoney(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

local vendorFrame = CreateFrame("Frame")
vendorFrame:RegisterEvent("MERCHANT_SHOW")
vendorFrame:SetScript("OnEvent", function()
    -- Hold Shift to skip auto-repair and auto-sell.
    if IsShiftKeyDown() then return end

    -- Small delay to ensure merchant data is fully loaded.
    C_Timer.After(0.3, function()
        if not MerchantFrame:IsShown() then return end

        -- Auto Repair
        if addon.db.vendor_autoRepair and CanMerchantRepair() then
            local cost = GetRepairAllCost()
            if cost and cost > 0 then
                local useGuild = addon.db.vendor_autoRepair_guildBank and CanGuildBankRepair()
                RepairAllItems(useGuild)
                PlaySound(SOUNDKIT.ITEM_REPAIR)
                local msg = "Repaired for " .. formatMoney(cost)
                if useGuild then msg = msg .. " (guild bank)" end
                print(PREFIX .. msg)
            end
        end

        -- Auto Sell Greys
        if addon.db.vendor_autoSell and C_MerchantFrame.IsSellAllJunkEnabled() then
            local total = 0
            for bag = 0, NUM_BAG_SLOTS do
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    if info and info.quality == Enum.ItemQuality.Poor then
                        local sellPrice = select(11, C_Item.GetItemInfo(info.hyperlink))
                        if sellPrice and sellPrice > 0 then
                            total = total + sellPrice * info.stackCount
                        end
                    end
                end
            end
            C_MerchantFrame.SellAllJunkItems()
            if total > 0 then
                print(PREFIX .. "Sold greys for " .. formatMoney(total))
            end
        end
    end)
end)
