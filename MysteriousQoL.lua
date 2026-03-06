local addonName, addon = ...

-- ── Initialization ──────────────────────────────────────────────────────────

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    addon:MI_InitDB()

    -- Build the native Settings panel.
    -- Each subcategory maps to a feature group (Fun, UI, Combat, …).
    local rootCat    = Settings.RegisterVerticalLayoutCategory(addonName)
    local generalCat = Settings.RegisterVerticalLayoutSubcategory(rootCat, "General")
    local uiCat      = Settings.RegisterVerticalLayoutSubcategory(rootCat, "UI")
    local funCat     = Settings.RegisterVerticalLayoutSubcategory(rootCat, "Fun")

    -- Register per-feature settings into their category.
    addon.MI_Vendor_RegisterSettings(generalCat)
    addon.MI_MouseRing_RegisterSettings(uiCat)
    addon.MI_OwenWilson_RegisterSettings(funCat)
    addon.MI_Batman_RegisterSettings(funCat)
    addon.MI_Bloodlust_RegisterSettings(funCat)
    addon.MI_Blink_RegisterSettings(funCat)
    addon.MI_Sneaky_RegisterSettings(funCat)

    Settings.RegisterAddOnCategory(rootCat)
    addon.settingsRootCatID = rootCat:GetID()

    -- Initialize features that need to be active on load.
    addon.MI_MouseRing_Init()
end)

-- ── Slash command ────────────────────────────────────────────────────────────

SLASH_MYSTERIOUSQOL1 = "/mqol"
SlashCmdList["MYSTERIOUSQOL"] = function()
    if addon.settingsRootCatID then
        Settings.OpenToCategory(addon.settingsRootCatID)
    end
end
