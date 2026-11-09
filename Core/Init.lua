local _, addon = ...

local CURRENT_DB_VERSION = 1

local VALID_SOUND_CHANNELS = {
    Master   = true,
    SFX      = true,
    Music    = true,
    Ambience = true,
    Dialog   = true,
}

local VALID_BLOODLUST_SOUNDS = {
    ["r2d2.ogg"] = true,
    ["wei.ogg"]  = true,
}

local VALID_FRAME_POINTS = {
    TOPLEFT     = true,
    TOP         = true,
    TOPRIGHT    = true,
    LEFT        = true,
    CENTER      = true,
    RIGHT       = true,
    BOTTOMLEFT  = true,
    BOTTOM      = true,
    BOTTOMRIGHT = true,
}

-- Before 1.3 each feature had its own sound channel. When merging them into
-- one, the first one that isn't Master wins.
local LEGACY_SOUND_CHANNEL_KEYS = {
    "fun_owenWilson_channel",
    "fun_batman_channel",
    "fun_bloodlust_channel",
    "fun_blink_channel",
    "fun_sneaky_channel",
    "fun_rolling_channel",
    "fun_zoomies_channel",
    "fun_victory_channel",
    "fun_vendorSound_channel",
    "combat_petMissingSound_channel",
}

local OBSOLETE_GUILD_KEYS = {
    "guildData",
    "guild_alts_enabled",
    "guild_chat_showMain",
    "guild_log_enabled",
    "guild_log_maxEntries",
    "guild_sync_enabled",
    "guild_inactive_days",
    "guild_panel_scale",
}

-- Default values for all settings. Each feature owns its own keys.
addon.defaults = {
    -- Global
    sound_channel = "Master",

    -- Fun
    fun_owenWilson_enabled   = false,
    fun_batman_enabled       = false,
    fun_bloodlust_enabled    = false,
    fun_bloodlust_sound      = "r2d2.ogg",
    fun_blink_enabled        = false,
    fun_sneaky_enabled       = false,
    fun_rolling_enabled      = false,
    fun_zoomies_enabled      = false,
    fun_zoomies_cheetah      = true,
    fun_zoomies_dash         = true,
    fun_zoomies_steed        = true,
    fun_zoomies_rush         = true,
    fun_vendorSound_enabled  = false,
    fun_victory_enabled      = false,
    fun_mystGems_enabled     = true,
    fun_mystGems_flight      = true,
    fun_mystGems_best        = 0,
    fun_mystGems_muted       = false,
    -- Combat
    combat_buffReminder_enabled      = false,
    combat_sealReminder_enabled      = false,
    combat_petReminder_enabled       = false,
    combat_petIdleReminder_enabled   = false,
    combat_deathReminder_enabled     = false,
    combat_cheatDeathReminder_enabled = false,
    combat_overloadReminder_enabled  = false,
    combat_mulchReminder_enabled     = false,
    combat_repairReminder_enabled    = false,
    combat_repairReminder_pct        = 20,
    combat_readyCheck_enabled        = false,
    combat_diveReminder_enabled      = false,

    combat_mailReminder_enabled  = false,
    combat_petMissingSound_enabled = false,

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
    general_autoQuest_skipTrivial = true,
    general_autoFlightMap        = false,
    general_thankBuffs           = false,
    general_autoQuestTurnIn      = false,
    general_autoGossipSelect     = false,
    general_ahCurrentExpansion   = false,
    general_maxCameraDistance    = false,

    -- Forever only
    forever_bagSpace_enabled          = false,
    forever_bagSpace_threshold        = 4,
    forever_bagSpace_ignoreReagent    = false,
    forever_bagsFull_enabled          = false,
    forever_bagsFull_lowOnly          = false,
    forever_campfireReminder_enabled  = false,
    forever_rankUpgrade_enabled       = false,
    forever_plainsrunning_enabled     = false,
    forever_reagents_enabled          = false,
    forever_reagents_threshold        = 5,
    -- Per reagent warn-below; 0 uses forever_reagents_threshold
    forever_reagents_soulShard         = 0,
    forever_reagents_arcanePowder      = 0,
    forever_reagents_teleport          = 0,
    forever_reagents_portal            = 0,
    forever_reagents_candle            = 0,
    forever_reagents_divinity          = 0,
    forever_reagents_kings             = 0,
    forever_reagents_wild              = 0,
    forever_reagents_rebirth           = 0,
    forever_reagents_ankh              = 0,
    forever_reagents_flash             = 0,
    forever_reagents_blinding          = 0,

    -- Forever class buff reminders (Reminders > Buffs), all off by default
    forever_buff_motw                 = false,
    forever_buff_thorns               = false,
    forever_buff_thorns_bearOnly      = true,
    forever_buff_intellect            = false,
    forever_buff_mageArmor            = false,
    forever_buff_fortitude            = false,
    forever_buff_innerFire            = false,
    forever_buff_divineSpirit         = false,
    forever_buff_shadowProt           = false,
    forever_buff_righteousFury        = false,
    forever_buff_righteousFury_shieldOnly = true,
    forever_buff_blessing             = false,
    forever_buff_demonArmor           = false,
    forever_buff_lightningShield      = false,
    forever_buff_weaponImbue          = false,
    forever_buff_poisonMain           = false,
    forever_buff_poisonOff            = false,
    forever_buff_battleShout          = false,
    forever_buff_trueshot             = false,
    forever_buff_aspect               = false,

    -- UI > Gear
    ui_bagUpgrade_enabled         = false,
    ui_missingEnchant_enabled     = false,

    -- UI > Quests
    ui_questRewardCoin_enabled    = false,
    ui_questXP_enabled            = false,

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
    ui_hideErrors_enabled         = false,
    ui_hideErrors_keepImportant   = true,

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

    -- Settings panel accent: teal, red or gold
    settings_accent               = "teal",

    -- UI > Minimap Button
    ui_minimapButton_enabled      = true,
    ui_minimapButton_angle        = 220,

    settings_panel_scale          = 1.0,
    settings_debugAllClasses      = false,
    ui_welcomeShown               = false,
    ui_lastSeenVersion            = "",
}

local NUMBER_RULES = {
    forever_bagSpace_threshold        = { min = 1,  max = 20 },
    combat_repairReminder_pct         = { min = 5,  max = 90 },
    forever_reagents_threshold        = { min = 1,  max = 20 },
    forever_reagents_soulShard         = { min = 0,  max = 20 },
    forever_reagents_arcanePowder      = { min = 0,  max = 20 },
    forever_reagents_teleport          = { min = 0,  max = 20 },
    forever_reagents_portal            = { min = 0,  max = 20 },
    forever_reagents_candle            = { min = 0,  max = 20 },
    forever_reagents_divinity          = { min = 0,  max = 20 },
    forever_reagents_kings             = { min = 0,  max = 20 },
    forever_reagents_wild              = { min = 0,  max = 20 },
    forever_reagents_rebirth           = { min = 0,  max = 20 },
    forever_reagents_ankh              = { min = 0,  max = 20 },
    forever_reagents_flash             = { min = 0,  max = 20 },
    forever_reagents_blinding          = { min = 0,  max = 20 },
    ui_mouseRing_size             = { min = 20,    max = 100 },
    ui_dragonriding_barWidth      = { min = 8,     max = 200 },
    ui_dragonriding_speedHeight   = { min = 4,     max = 100 },
    ui_dragonriding_chargeHeight  = { min = 4,     max = 100 },
    ui_dragonriding_gap           = { min = 0,     max = 50 },
    ui_dragonriding_posX          = { min = -10000, max = 10000 },
    ui_dragonriding_posY          = { min = -10000, max = 10000 },
    ui_minimapButton_angle        = { min = -360,  max = 360 },
    settings_panel_scale          = { min = 0.6,   max = 2.0 },
}

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function migrateLegacySoundChannel(db)
    if VALID_SOUND_CHANNELS[db.sound_channel] and db.sound_channel ~= "Master" then return end

    local fallback = VALID_SOUND_CHANNELS[db.sound_channel] and db.sound_channel or nil
    for _, key in ipairs(LEGACY_SOUND_CHANNEL_KEYS) do
        local channel = db[key]
        if VALID_SOUND_CHANNELS[channel] then
            fallback = fallback or channel
            if channel ~= "Master" then
                db.sound_channel = channel
                return
            end
        end
    end
    db.sound_channel = fallback or "Master"
end

local function removeObsoleteKeys(db)
    for _, key in ipairs(LEGACY_SOUND_CHANNEL_KEYS) do
        db[key] = nil
    end
    for _, key in ipairs(OBSOLETE_GUILD_KEYS) do
        db[key] = nil
    end
end

local MIGRATIONS = {
    [1] = function(db)
        migrateLegacySoundChannel(db)
        removeObsoleteKeys(db)
    end,
}

local function getDBVersion(db)
    local version = db.dbVersion
    if not isFiniteNumber(version) or version < 0 or version % 1 ~= 0 then
        return 0
    end
    return version
end

local function runMigrations(db)
    local version = getDBVersion(db)
    if version < CURRENT_DB_VERSION then
        for nextVersion = version + 1, CURRENT_DB_VERSION do
            local migration = MIGRATIONS[nextVersion]
            if migration then migration(db) end
        end
        db.dbVersion = CURRENT_DB_VERSION
    end

    -- Always clean up old keys, a beta build may have set the version early.
    -- Don't lower the version if a newer build saved it.
    removeObsoleteKeys(db)
    if version <= CURRENT_DB_VERSION then
        db.dbVersion = CURRENT_DB_VERSION
    end
end

local function validateDB(db, defaults)
    for key, default in pairs(defaults) do
        if type(db[key]) ~= type(default) then
            db[key] = default
        end
    end

    if not VALID_SOUND_CHANNELS[db.sound_channel] then
        db.sound_channel = defaults.sound_channel
    end
    if not VALID_BLOODLUST_SOUNDS[db.fun_bloodlust_sound] then
        db.fun_bloodlust_sound = defaults.fun_bloodlust_sound
    end
    if not VALID_FRAME_POINTS[db.ui_dragonriding_posPoint] then
        db.ui_dragonriding_posPoint = defaults.ui_dragonriding_posPoint
    end

    for key, rule in pairs(NUMBER_RULES) do
        local value = db[key]
        if not isFiniteNumber(value) then
            value = defaults[key]
        end
        db[key] = clamp(value, rule.min, rule.max)
    end

    -- Camera distance from before the feature was turned on, nil until saved.
    local previous = db.general_maxCameraDistance_previous
    if previous ~= nil then
        if isFiniteNumber(previous) then
            db.general_maxCameraDistance_previous = clamp(previous, 1.0, 2.6)
        else
            db.general_maxCameraDistance_previous = nil
        end
    end
    if db.general_maxCameraDistance and db.general_maxCameraDistance_previous == nil then
        -- Old versions set 2.6 without saving what it was before.
        db.general_maxCameraDistance_previous = 1.9
    end
end

-- Sets up and checks the saved settings. Runs on ADDON_LOADED.
function addon:MI_InitDB()
    if type(MysteriousQoLDB) ~= "table" then
        MysteriousQoLDB = {}
    end
    runMigrations(MysteriousQoLDB)
    validateDB(MysteriousQoLDB, self.defaults)
    self.db = MysteriousQoLDB
end

-- Bouncing text used by the reminders.
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

-- Plays a sound when the player casts one of the given spell IDs.
-- opts: { dbKey, spellIDs (set: { [id] = true }), sounds (string or array of paths) }
function addon.MI_CreateSpellCastSound(opts)
    local sounds = opts.sounds
    local pickSound
    if type(sounds) == "table" then
        pickSound = function() return sounds[math.random(#sounds)] end
    else
        pickSound = function() return sounds end
    end

    local f = CreateFrame("Frame")
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    f:SetScript("OnEvent", function(_, _, _, _, spellID)
        if not addon.db[opts.dbKey] then return end
        if not opts.spellIDs[spellID] then return end
        PlaySoundFile(pickSound(), addon.db.sound_channel)
    end)
end
