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
    local rootCat,    rootLayout    = Settings.RegisterVerticalLayoutCategory(addonName)
    local generalCat, generalLayout = Settings.RegisterVerticalLayoutSubcategory(rootCat, "General")
    local uiCat,      uiLayout      = Settings.RegisterVerticalLayoutSubcategory(rootCat, "UI")
    local funCat,     funLayout     = Settings.RegisterVerticalLayoutSubcategory(rootCat, "Fun")

    -- Register per-feature settings into their category.
    -- Section headers use the layout object returned alongside the category.
    local function Header(layout, title)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
    end

    addon.MI_Vendor_RegisterSettings(generalCat)
    addon.MI_MouseRing_RegisterSettings(uiCat)

    Header(funLayout, "Owen Wilson")
    addon.MI_OwenWilson_RegisterSettings(funCat)
    Header(funLayout, "Batman")
    addon.MI_Batman_RegisterSettings(funCat)
    Header(funLayout, "Bloodlust")
    addon.MI_Bloodlust_RegisterSettings(funCat)
    Header(funLayout, "Blink")
    addon.MI_Blink_RegisterSettings(funCat)
    Header(funLayout, "Stealth")
    addon.MI_Sneaky_RegisterSettings(funCat)
    Header(funLayout, "Roll")
    addon.MI_Rolling_RegisterSettings(funCat)
    Header(funLayout, "Zoomies")
    addon.MI_Zoomies_RegisterSettings(funCat)

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
