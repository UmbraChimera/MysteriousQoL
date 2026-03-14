local _, addon = ...

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Vendor\\money.ogg"

-- Hook SellAllJunkItems to catch both our auto-sell and the in-game button.
hooksecurefunc(C_MerchantFrame, "SellAllJunkItems", function()
    if not addon.db.fun_vendorSound_enabled then return end
    PlaySoundFile(SOUND, addon.db.fun_vendorSound_channel)
end)
