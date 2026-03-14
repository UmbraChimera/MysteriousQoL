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
    fun_zoomies_cheetah      = true,
    fun_zoomies_dash         = true,
    fun_zoomies_steed        = true,
    fun_zoomies_rush         = true,
    fun_victory_enabled      = true,
    fun_victory_channel      = "Master",
    fun_vendorSound_enabled  = false,
    fun_vendorSound_channel  = "Master",
    -- Combat
    combat_buffReminder_enabled      = false,
    combat_petReminder_enabled       = false,
    combat_petIdleReminder_enabled   = false,
    combat_deathReminder_enabled     = false,
    combat_overloadReminder_enabled  = false,
    combat_repairReminder_enabled    = false,

    combat_deathReleaseProtection = false,
    combat_mailReminder_enabled  = false,

    -- General
    vendor_autoRepair            = false,
    vendor_autoRepair_guildBank  = false,
    vendor_autoSell              = false,
    general_fasterLoot           = false,
    general_suppressLootWarnings = false,
    general_easyDestroy          = false,
    general_autoKeystone         = false,
    general_skipQueueConfirm     = false,
    general_autoQuestAccept      = false,
    general_autoQuestTurnIn      = false,
    general_autoGossipSelect     = false,
    general_ahCurrentExpansion   = false,
    general_maxCameraDistance    = false,

    -- UI > Mouse Ring
    ui_mouseRing_enabled          = false,
    ui_mouseRing_size             = 30,
    ui_mouseRing_hideDot          = false,
    ui_mouseRing_onlyInCombat     = false,
    ui_mouseRing_onlyOnRightClick = false,
    ui_mouseRing_useClassColor    = false,
    ui_mouseRing_castProgress     = false,

    -- UI > Hide Elements
    ui_hideSocial_enabled         = false,
    ui_hideAlerts_enabled         = false,
    ui_hideTalkingHead_enabled    = false,
    ui_hideEventToasts_enabled    = false,
    ui_hideZoneText_enabled       = false,

    -- UI > Dragonriding
    ui_dragonriding_enabled       = false,
    ui_dragonriding_showSpeed     = true,
    ui_dragonriding_showSecondWind = true,
    ui_dragonriding_showWhirlingSurge = true,
    ui_dragonriding_hideGroundedFull  = false,
    ui_dragonriding_barWidth      = 36,
    ui_dragonriding_speedHeight   = 14,
    ui_dragonriding_chargeHeight  = 14,
    ui_dragonriding_gap           = 0,
    ui_dragonriding_posPoint      = "BOTTOM",
    ui_dragonriding_posX          = 0,
    ui_dragonriding_posY          = 200,

    -- UI > Chat Copy
    ui_chatCopy_enabled           = false,

    -- UI > Minimap Button
    ui_minimapButton_enabled      = true,
    ui_minimapButton_angle        = 220,
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

-- Shared factory for bouncing reminder frames used by multiple Reminders/ modules.
-- opts: { baseY, bounce, speed, fontSize, color, shadow, width, height, strata, text, icon, iconSize }
function addon.MI_CreateBouncingReminder(name, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(opts.width or 500, opts.height or 60)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, opts.baseY or 0)
    frame:SetFrameStrata(opts.strata or "MEDIUM")
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetFont("Fonts\\FRIZQT__.TTF", opts.fontSize or 26, "THICKOUTLINE")
    local c = opts.color or { 1, 0.2, 0.2, 1 }
    text:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    text:SetShadowColor(0, 0, 0, 1)
    local s = opts.shadow or { 2, -2 }
    text:SetShadowOffset(s[1], s[2])
    if opts.text then text:SetText(opts.text) end

    local icon
    if opts.icon then
        text:SetPoint("CENTER")
        icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(opts.iconSize or 36, opts.iconSize or 36)
        icon:SetPoint("RIGHT", text, "LEFT", -10, 0)
        icon:SetTexture(opts.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        text:SetAllPoints()
    end

    local bounceT = 0
    local baseY  = opts.baseY or 0
    local bounce = opts.bounce or 6
    local speed  = opts.speed or 2.5

    frame:SetScript("OnUpdate", function(self, elapsed)
        bounceT = bounceT + elapsed
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, baseY + math.sin(bounceT * speed) * bounce)
    end)

    frame.text = text
    frame.icon = icon
    frame.ResetBounce = function() bounceT = 0 end

    return frame
end
