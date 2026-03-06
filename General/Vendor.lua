local _, addon = ...

-- Auto-repair and auto-sell greys when a merchant window opens.

local floor  = math.floor
local concat = table.concat

local PREFIX = "|cff00ccff[MysteriousQoL]|r "

local function formatMoney(copper)
    local g = floor(copper / 10000)
    local s = floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return concat(parts, " ")
end

local vendorFrame = CreateFrame("Frame")
vendorFrame:RegisterEvent("MERCHANT_SHOW")
vendorFrame:SetScript("OnEvent", function()
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
            C_MerchantFrame.SellAllJunkItems()
        end
    end)
end)

-- ── Settings ──────────────────────────────────────────────────────────────────

function addon.MI_Vendor_RegisterSettings(vendorCat)
    addon.settings.Checkbox(
        vendorCat, "vendor_autoRepair", "Auto Repair",
        "Automatically repairs all equipment when visiting a merchant."
    )
    addon.settings.Checkbox(
        vendorCat, "vendor_autoRepair_guildBank", "Use Guild Bank for Repairs",
        "Prefer guild bank funds when auto-repairing, if available."
    )
    addon.settings.Checkbox(
        vendorCat, "vendor_autoSell", "Auto Sell Greys",
        "Automatically sells all grey (poor quality) items when visiting a merchant."
    )
end
