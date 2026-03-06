local addonName, addon = ...

-- Default values for all settings. Each feature owns its own keys.
addon.defaults = {
    -- Fun
    fun_owenWilson_enabled = false,
    fun_owenWilson_channel = "Master",
    fun_batman_enabled       = false,
    fun_batman_channel       = "Master",
    fun_bloodlust_enabled    = false,
    fun_bloodlust_sound      = "r2d2.ogg",
    fun_bloodlust_channel    = "Master",
    fun_blink_enabled        = false,
    fun_blink_channel        = "Master",
    fun_sneaky_enabled       = false,
    fun_sneaky_channel       = "Master",
    fun_rolling_enabled      = false,
    fun_rolling_channel      = "Master",
    fun_zoomies_enabled      = false,
    fun_zoomies_channel      = "Master",

    -- General
    vendor_autoRepair            = false,
    vendor_autoRepair_guildBank  = false,
    vendor_autoSell              = false,

    -- UI > Mouse Ring
    ui_mouseRing_enabled          = false,
    ui_mouseRing_size             = 70,
    ui_mouseRing_hideDot          = false,
    ui_mouseRing_onlyInCombat     = false,
    ui_mouseRing_onlyOnRightClick = false,
    ui_mouseRing_useClassColor    = false,
    ui_mouseRing_castProgress     = false,
}

-- Initialize the SavedVariables-backed DB, filling in any missing keys with defaults.
-- Called from ADDON_LOADED in MysteriousQoL.lua.
function addon:MI_InitDB()
    MysteriousQoLDB = MysteriousQoLDB or {}
    for k, v in pairs(self.defaults) do
        if MysteriousQoLDB[k] == nil then
            MysteriousQoLDB[k] = v
        end
    end
    self.db = MysteriousQoLDB
end
