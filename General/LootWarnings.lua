local _, addon = ...

-- Auto-confirms loot roll, bind-on-pickup, and trade timer removal dialogs.

local f = CreateFrame("Frame")
f:RegisterEvent("CONFIRM_LOOT_ROLL")
f:RegisterEvent("CONFIRM_DISENCHANT_ROLL")
f:RegisterEvent("LOOT_BIND_CONFIRM")
f:RegisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")
f:RegisterEvent("MAIL_LOCK_SEND_ITEMS")

f:SetScript("OnEvent", function(_, event, ...)
    if not addon.db.general_suppressLootWarnings then return end

    if event == "CONFIRM_LOOT_ROLL" or event == "CONFIRM_DISENCHANT_ROLL" then
        local id, roll = ...
        ConfirmLootRoll(id, roll)
        StaticPopup_Hide("CONFIRM_LOOT_ROLL")
    elseif event == "LOOT_BIND_CONFIRM" then
        local slot = ...
        ConfirmLootSlot(slot)
        StaticPopup_Hide("LOOT_BIND")
    elseif event == "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL" then
        SellCursorItem()
    elseif event == "MAIL_LOCK_SEND_ITEMS" then
        local slot = ...
        RespondMailLockSendItem(slot, true)
    end
end)
