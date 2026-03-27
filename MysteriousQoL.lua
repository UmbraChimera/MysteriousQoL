local addonName, addon = ...

-- AceConfig options table helpers
local function get(key)   return function()      return addon.db[key]        end end
local function set(key)   return function(_, v)  addon.db[key] = v           end end
local function setFn(key, fn)
    return function(_, v)
        addon.db[key] = v
        if fn then fn(v) end
    end
end
local function hidden(key) return function() return not addon.db[key] end end

local CHANNELS = {
    Master   = "Master",
    SFX      = "Sound Effects",
    Music    = "Music",
    Ambience = "Ambience",
    Dialog   = "Dialog",
}

-- Inline child group: appears below parent toggle, visually bordered/indented.
-- hidden_key: the db key whose value gates visibility (group shows when key is true).
local function childGroup(hidden_key, order, args)
    return {
        type   = "group",
        name   = "",
        inline = true,
        order  = order,
        hidden = hidden(hidden_key),
        args   = args,
    }
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    addon:MI_InitDB()
    addon.MI_SettingsUI_Init()

    addon._options = {
        type        = "group",
        name        = "MysteriousQoL",
        childGroups = "tab",
        args = {

            -- ----------------------------------------------------------------
            General = {
                type = "group", name = "General", order = 1,
                args = {
                    h_automation = { type = "header", name = "Automation", order = 1 },
                    general_ahCurrentExpansion = {
                        type = "toggle", width = "full", order = 2,
                        name = "AH: Current Expansion Only",
                        desc = "Automatically enables the Current Expansion filter when opening the Auction House.",
                        get = get("general_ahCurrentExpansion"), set = set("general_ahCurrentExpansion"),
                    },
                    general_autoQuestAccept = {
                        type = "toggle", width = "full", order = 3,
                        name = "Auto-Accept Quests",
                        desc = "Automatically accepts quests from NPCs. Hold Alt to bypass.",
                        get = get("general_autoQuestAccept"), set = set("general_autoQuestAccept"),
                    },
                    general_autoGossipSelect = {
                        type = "toggle", width = "full", order = 4,
                        name = "Auto-Select Gossip",
                        desc = "Automatically selects the gossip option when an NPC only has one. Hold Alt to bypass.",
                        get = get("general_autoGossipSelect"), set = set("general_autoGossipSelect"),
                    },
                    general_autoKeystone = {
                        type = "toggle", width = "full", order = 5,
                        name = "Auto-Slot Keystone",
                        desc = "Automatically places your Mythic+ keystone when the Challenge Mode frame opens.",
                        get = get("general_autoKeystone"), set = set("general_autoKeystone"),
                    },
                    general_autoQuestTurnIn = {
                        type = "toggle", width = "full", order = 6,
                        name = "Auto Turn-In Quests",
                        desc = "Automatically turns in completed quests. Only auto-selects reward if there is one or no choice. Hold Alt to bypass.",
                        get = get("general_autoQuestTurnIn"), set = set("general_autoQuestTurnIn"),
                    },
                    general_skipQueueConfirm = {
                        type = "toggle", width = "full", order = 7,
                        name = "Skip Queue Confirm",
                        desc = "Auto-clicks Sign Up in the group finder application dialog. Hold Ctrl to see the dialog.",
                        get = get("general_skipQueueConfirm"), set = set("general_skipQueueConfirm"),
                    },

                    h_camera = { type = "header", name = "Camera", order = 10 },
                    general_maxCameraDistance = {
                        type = "toggle", width = "full", order = 11,
                        name = "Max Camera Distance",
                        desc = "Sets camera distance to maximum (2.6x zoom out). Applied on login.",
                        get = get("general_maxCameraDistance"),
                        set = setFn("general_maxCameraDistance", function(v)
                            SetCVar("cameraDistanceMaxZoomFactor", v and 2.6 or 1.9)
                        end),
                    },

                    h_loot = { type = "header", name = "Loot", order = 20 },
                    general_easyDestroy = {
                        type = "toggle", width = "full", order = 21,
                        name = "Easy Item Destroy",
                        desc = "Auto-fills the DELETE confirmation text so you can just click the button.",
                        get = get("general_easyDestroy"), set = set("general_easyDestroy"),
                    },
                    general_fasterLoot = {
                        type = "toggle", width = "full", order = 22,
                        name = "Faster Auto-Loot",
                        desc = "Rapidly loots all items from a corpse instead of waiting for the default loot animation.",
                        get = get("general_fasterLoot"), set = set("general_fasterLoot"),
                    },
                    general_suppressLootWarnings = {
                        type = "toggle", width = "full", order = 23,
                        name = "Suppress Loot Warnings",
                        desc = "Auto-confirms bind-on-pickup, loot roll, and trade timer removal dialogs.",
                        get = get("general_suppressLootWarnings"), set = set("general_suppressLootWarnings"),
                    },

                    h_vendor = { type = "header", name = "Vendor", order = 30 },
                    vendor_autoRepair = {
                        type = "toggle", width = "full", order = 31,
                        name = "Auto Repair",
                        desc = "Automatically repairs all equipment when visiting a merchant. Hold Shift to skip.",
                        get = get("vendor_autoRepair"), set = set("vendor_autoRepair"),
                    },
                    vendor_autoRepair_opts = childGroup("vendor_autoRepair", 32, {
                        vendor_autoRepair_guildBank = {
                            type = "toggle", width = "full",
                            name = "Use Guild Bank for Repairs",
                            desc = "Prefer guild bank funds when auto-repairing, if available.",
                            get = get("vendor_autoRepair_guildBank"), set = set("vendor_autoRepair_guildBank"),
                        },
                    }),
                    vendor_autoSell = {
                        type = "toggle", width = "full", order = 33,
                        name = "Auto Sell Greys",
                        desc = "Automatically sells all grey (poor quality) items when visiting a merchant. Hold Shift to skip.",
                        get = get("vendor_autoSell"), set = set("vendor_autoSell"),
                    },
                },
            },

            -- ----------------------------------------------------------------
            UI = {
                type = "group", name = "UI", order = 2,
                args = {
                    h_chat = { type = "header", name = "Chat", order = 1 },
                    ui_chatCopy_enabled = {
                        type = "toggle", width = "full", order = 2,
                        name = "Chat Copy Button",
                        desc = "Adds a small copy button to each chat frame. Click to open a window with copyable chat text.",
                        get = get("ui_chatCopy_enabled"),
                        set = setFn("ui_chatCopy_enabled", function()
                            if addon.MI_ChatCopy_UpdateVisibility then addon.MI_ChatCopy_UpdateVisibility() end
                        end),
                    },

                    h_hide = { type = "header", name = "Hide Elements", order = 10 },
                    ui_hideAlerts_enabled = {
                        type = "toggle", width = "full", order = 11,
                        name = "Hide Alert Popups",
                        desc = "Hides achievement, loot, and other alert notifications.",
                        get = get("ui_hideAlerts_enabled"), set = set("ui_hideAlerts_enabled"),
                    },
                    ui_hideEventToasts_enabled = {
                        type = "toggle", width = "full", order = 12,
                        name = "Hide Event Toasts",
                        desc = "Hides event notifications.",
                        get = get("ui_hideEventToasts_enabled"), set = set("ui_hideEventToasts_enabled"),
                    },
                    ui_hideSocial_enabled = {
                        type = "toggle", width = "full", order = 13,
                        name = "Hide Social Button",
                        desc = "Hides the Quick Join toast button near the minimap.",
                        get = get("ui_hideSocial_enabled"),
                        set = setFn("ui_hideSocial_enabled", function()
                            if addon.MI_HideSocial_ApplySocial then addon.MI_HideSocial_ApplySocial() end
                        end),
                    },
                    ui_hideTalkingHead_enabled = {
                        type = "toggle", width = "full", order = 14,
                        name = "Hide Talking Head",
                        desc = "Hides the NPC talking head dialog frame.",
                        get = get("ui_hideTalkingHead_enabled"), set = set("ui_hideTalkingHead_enabled"),
                    },
                    ui_hideZoneText_enabled = {
                        type = "toggle", width = "full", order = 15,
                        name = "Hide Zone Text",
                        desc = "Hides the zone name popup when entering a new area.",
                        get = get("ui_hideZoneText_enabled"), set = set("ui_hideZoneText_enabled"),
                    },

                    h_minimap = { type = "header", name = "Minimap", order = 20 },
                    ui_minimapButton_enabled = {
                        type = "toggle", width = "full", order = 21,
                        name = "Show Minimap Button",
                        desc = "Toggles the MysteriousQoL minimap button.",
                        get = get("ui_minimapButton_enabled"),
                        set = setFn("ui_minimapButton_enabled", function(v)
                            if addon.MI_MinimapButton_SetShown then addon.MI_MinimapButton_SetShown(v) end
                        end),
                    },

                    h_mousering = { type = "header", name = "Mouse Ring", order = 30 },
                    ui_mouseRing_enabled = {
                        type = "toggle", width = "full", order = 31,
                        name = "Mouse Ring",
                        desc = "Shows a configurable ring around your cursor.",
                        get = get("ui_mouseRing_enabled"),
                        set = setFn("ui_mouseRing_enabled", function(v)
                            if addon.MI_MouseRing_SetEnabled then addon.MI_MouseRing_SetEnabled(v) end
                        end),
                    },
                    ui_mouseRing_opts = childGroup("ui_mouseRing_enabled", 32, {
                        ui_mouseRing_size = {
                            type = "range", width = "full", order = 1,
                            name = "Ring Size",
                            min = 20, max = 100, step = 1,
                            get = get("ui_mouseRing_size"),
                            set = setFn("ui_mouseRing_size", function()
                                if addon.MI_MouseRing_ApplyStyle then addon.MI_MouseRing_ApplyStyle() end
                            end),
                        },
                        ui_mouseRing_hideDot = {
                            type = "toggle", width = "full", order = 2,
                            name = "Hide Center Dot",
                            get = get("ui_mouseRing_hideDot"),
                            set = setFn("ui_mouseRing_hideDot", function()
                                if addon.MI_MouseRing_ApplyStyle then addon.MI_MouseRing_ApplyStyle() end
                            end),
                        },
                        ui_mouseRing_onlyInCombat = {
                            type = "toggle", width = "full", order = 3,
                            name = "Only Show In Combat",
                            get = get("ui_mouseRing_onlyInCombat"), set = set("ui_mouseRing_onlyInCombat"),
                        },
                        ui_mouseRing_onlyOnRightClick = {
                            type = "toggle", width = "full", order = 4,
                            name = "Only Show On Right-Click",
                            desc = "Ring is visible only while the right mouse button is held.",
                            get = get("ui_mouseRing_onlyOnRightClick"), set = set("ui_mouseRing_onlyOnRightClick"),
                        },
                        ui_mouseRing_useClassColor = {
                            type = "toggle", width = "full", order = 5,
                            name = "Use Class Color",
                            get = get("ui_mouseRing_useClassColor"),
                            set = setFn("ui_mouseRing_useClassColor", function()
                                if addon.MI_MouseRing_ApplyStyle then addon.MI_MouseRing_ApplyStyle() end
                            end),
                        },
                        ui_mouseRing_castProgress = {
                            type = "toggle", width = "full", order = 6,
                            name = "Show Cast Progress",
                            desc = "A ring sweeps along the outside to show cast or channel progress.",
                            get = get("ui_mouseRing_castProgress"), set = set("ui_mouseRing_castProgress"),
                        },
                    }),

                    h_skyriding = { type = "header", name = "Skyriding", order = 40 },
                    ui_dragonriding_enabled = {
                        type = "toggle", width = "full", order = 41,
                        name = "Skyriding Vigor Tracker",
                        desc = "Shows a vigor charge bar and speed display while skyriding.",
                        get = get("ui_dragonriding_enabled"),
                        set = setFn("ui_dragonriding_enabled", function(v)
                            if addon.MI_Dragonriding_SetEnabled then addon.MI_Dragonriding_SetEnabled(v) end
                        end),
                    },
                    ui_dragonriding_opts = childGroup("ui_dragonriding_enabled", 42, {
                        ui_dragonriding_showSpeed = {
                            type = "toggle", width = "full", order = 1,
                            name = "Show Speed Text",
                            desc = "Displays your forward speed as a number.",
                            get = get("ui_dragonriding_showSpeed"), set = set("ui_dragonriding_showSpeed"),
                        },
                        ui_dragonriding_showSecondWind = {
                            type = "toggle", width = "full", order = 2,
                            name = "Show Second Wind",
                            desc = "Shows Second Wind bonus charges as a lighter overlay.",
                            get = get("ui_dragonriding_showSecondWind"), set = set("ui_dragonriding_showSecondWind"),
                        },
                        ui_dragonriding_showWhirlingSurge = {
                            type = "toggle", width = "full", order = 3,
                            name = "Show Whirling Surge",
                            desc = "Shows the Whirling Surge cooldown icon next to the bar.",
                            get = get("ui_dragonriding_showWhirlingSurge"), set = set("ui_dragonriding_showWhirlingSurge"),
                        },
                        ui_dragonriding_hideGroundedFull = {
                            type = "toggle", width = "full", order = 4,
                            name = "Hide When Full + Grounded",
                            desc = "Hides the tracker when you have full vigor and are not gliding.",
                            get = get("ui_dragonriding_hideGroundedFull"), set = set("ui_dragonriding_hideGroundedFull"),
                        },
                    }),
                },
            },

            -- ----------------------------------------------------------------
            Reminders = {
                type = "group", name = "Reminders", order = 3,
                args = {
                    h_buff = { type = "header", name = "Class Buff", order = 1 },
                    combat_buffReminder_enabled = {
                        type = "toggle", width = "full", order = 2,
                        name = "Class Buff Reminder",
                        desc = "Shows a glowing icon when your class buff is missing from you or any group member.",
                        get = get("combat_buffReminder_enabled"),
                        set = setFn("combat_buffReminder_enabled", function()
                            if addon.MI_Reminders_RefreshState then addon.MI_Reminders_RefreshState() end
                        end),
                    },

                    h_death = { type = "header", name = "Death", order = 10 },
                    combat_deathReminder_enabled = {
                        type = "toggle", width = "full", order = 11,
                        name = "Don't Release Reminder",
                        desc = "Shows a large center-screen warning when you die in a raid instance to stop you releasing.",
                        get = get("combat_deathReminder_enabled"),
                        set = setFn("combat_deathReminder_enabled", function()
                            if addon.MI_Reminders_RefreshState then addon.MI_Reminders_RefreshState() end
                        end),
                    },
                    combat_deathReleaseProtection = {
                        type = "toggle", width = "full", order = 12,
                        name = "Release Protection",
                        desc = "Blocks the release button in dungeons and raids. Hold Alt for 1 second to release.",
                        get = get("combat_deathReleaseProtection"),
                        set = setFn("combat_deathReleaseProtection", function()
                            if addon.MI_Reminders_RefreshState then addon.MI_Reminders_RefreshState() end
                        end),
                    },

                    h_gathering = { type = "header", name = "Gathering", order = 20 },
                    combat_overloadReminder_enabled = {
                        type = "toggle", width = "full", order = 21,
                        name = "Overload Reminder",
                        desc = "Shows a warning when you begin mining or herbing and your Overload spell is off cooldown.",
                        get = get("combat_overloadReminder_enabled"),
                        set = setFn("combat_overloadReminder_enabled", function()
                            if addon.MI_Reminders_RefreshState then addon.MI_Reminders_RefreshState() end
                        end),
                    },

                    h_mail = { type = "header", name = "Mail", order = 30 },
                    combat_mailReminder_enabled = {
                        type = "toggle", width = "full", order = 31,
                        name = "Mail Reminder",
                        desc = "Plays a sound on login if you have unread mail. Only triggers on initial login, not reloads.",
                        get = get("combat_mailReminder_enabled"), set = set("combat_mailReminder_enabled"),
                    },

                    h_pet = { type = "header", name = "Pet", order = 40 },
                    combat_petReminder_enabled = {
                        type = "toggle", width = "full", order = 41,
                        name = "No Pet Reminder",
                        desc = "Shows a center-screen warning when you have no active pet (Warlock, Hunter BM/Survival, Unholy DK). Detects Grimoire of Sacrifice and no-pet talents.",
                        get = get("combat_petReminder_enabled"),
                        set = setFn("combat_petReminder_enabled", function()
                            if addon.MI_Reminders_RefreshState then addon.MI_Reminders_RefreshState() end
                        end),
                    },
                    combat_petIdleReminder_enabled = {
                        type = "toggle", width = "full", order = 42,
                        name = "Pet Idle Reminder",
                        desc = "Shows a center-screen warning when your pet is alive but not attacking while you are in combat.",
                        get = get("combat_petIdleReminder_enabled"),
                        set = setFn("combat_petIdleReminder_enabled", function()
                            if addon.MI_Reminders_RefreshState then addon.MI_Reminders_RefreshState() end
                        end),
                    },

                    h_repair = { type = "header", name = "Repair", order = 50 },
                    combat_repairReminder_enabled = {
                        type = "toggle", width = "full", order = 51,
                        name = "Repair Reminder",
                        desc = "Shows a center-screen warning when any equipped gear drops to 50% durability (yellow).",
                        get = get("combat_repairReminder_enabled"),
                        set = setFn("combat_repairReminder_enabled", function()
                            if addon.MI_Reminders_RefreshState then addon.MI_Reminders_RefreshState() end
                        end),
                    },

                    h_dive = { type = "header", name = "Hungering Presence", order = 60 },
                    combat_diveReminder_enabled = {
                        type = "toggle", width = "full", order = 61,
                        name = "Dive Reminder",
                        desc = "Shows a large DIVE warning while skyriding when debuff 1251978 is active.",
                        get = get("combat_diveReminder_enabled"),
                        set = setFn("combat_diveReminder_enabled", function()
                            if addon.MI_Reminders_RefreshState then addon.MI_Reminders_RefreshState() end
                        end),
                    },
                },
            },

            -- ----------------------------------------------------------------
            Fun = {
                type = "group", name = "Fun", order = 4,
                args = {
                    h_batman = { type = "header", name = "Batman", order = 1 },
                    fun_batman_enabled = {
                        type = "toggle", width = "full", order = 2,
                        name = "Batman Teleport Sound",
                        desc = "Plays batman.ogg when you teleport to a new zone via hearthstone, mage portal, or toy.",
                        get = get("fun_batman_enabled"), set = set("fun_batman_enabled"),
                    },
                    fun_batman_opts = childGroup("fun_batman_enabled", 3, {
                        fun_batman_channel = {
                            type = "select", width = "full", order = 1,
                            name = "Sound Channel",
                            values = CHANNELS,
                            get = get("fun_batman_channel"), set = set("fun_batman_channel"),
                        },
                    }),

                    h_blink = { type = "header", name = "Blink", order = 10 },
                    fun_blink_enabled = {
                        type = "toggle", width = "full", order = 11,
                        name = "Blink Sound",
                        desc = "Plays a DBZ sound when you use Blink or Shimmer (Mage) or Shift (Demon Hunter).",
                        get = get("fun_blink_enabled"), set = set("fun_blink_enabled"),
                    },
                    fun_blink_opts = childGroup("fun_blink_enabled", 12, {
                        fun_blink_channel = {
                            type = "select", width = "full", order = 1,
                            name = "Sound Channel",
                            values = CHANNELS,
                            get = get("fun_blink_channel"), set = set("fun_blink_channel"),
                        },
                    }),

                    h_bloodlust = { type = "header", name = "Bloodlust", order = 20 },
                    fun_bloodlust_enabled = {
                        type = "toggle", width = "full", order = 21,
                        name = "Bloodlust Sound",
                        desc = "Plays a sound when Bloodlust, Heroism, Time Warp, or any equivalent haste effect is applied to you.",
                        get = get("fun_bloodlust_enabled"), set = set("fun_bloodlust_enabled"),
                    },
                    fun_bloodlust_opts = childGroup("fun_bloodlust_enabled", 22, {
                        fun_bloodlust_sound = {
                            type = "select", width = "full", order = 1,
                            name = "Sound Choice",
                            values = { ["r2d2.ogg"] = "R2-D2", ["wei.ogg"] = "Wei" },
                            get = get("fun_bloodlust_sound"), set = set("fun_bloodlust_sound"),
                        },
                        fun_bloodlust_channel = {
                            type = "select", width = "full", order = 2,
                            name = "Sound Channel",
                            values = CHANNELS,
                            get = get("fun_bloodlust_channel"), set = set("fun_bloodlust_channel"),
                        },
                    }),

                    h_owenwilson = { type = "header", name = "Owen Wilson", order = 30 },
                    fun_owenWilson_enabled = {
                        type = "toggle", width = "full", order = 31,
                        name = "Owen Wilson Loot Sounds",
                        desc = "Plays a random Owen Wilson \"wow\" sound whenever a loot window opens.",
                        get = get("fun_owenWilson_enabled"), set = set("fun_owenWilson_enabled"),
                    },
                    fun_owenWilson_opts = childGroup("fun_owenWilson_enabled", 32, {
                        fun_owenWilson_channel = {
                            type = "select", width = "full", order = 1,
                            name = "Sound Channel",
                            desc = "Which audio channel to use for Owen Wilson sounds.",
                            values = CHANNELS,
                            get = get("fun_owenWilson_channel"), set = set("fun_owenWilson_channel"),
                        },
                    }),

                    h_roll = { type = "header", name = "Roll", order = 40 },
                    fun_rolling_enabled = {
                        type = "toggle", width = "full", order = 41,
                        name = "Roll Sound",
                        desc = "Plays a random sound when you use Roll or Chi Torpedo (Monk).",
                        get = get("fun_rolling_enabled"), set = set("fun_rolling_enabled"),
                    },
                    fun_rolling_opts = childGroup("fun_rolling_enabled", 42, {
                        fun_rolling_channel = {
                            type = "select", width = "full", order = 1,
                            name = "Sound Channel",
                            values = CHANNELS,
                            get = get("fun_rolling_channel"), set = set("fun_rolling_channel"),
                        },
                    }),

                    h_sneaky = { type = "header", name = "Stealth", order = 50 },
                    fun_sneaky_enabled = {
                        type = "toggle", width = "full", order = 51,
                        name = "Stealth Sound",
                        desc = "Plays a sound when you enter Stealth (Rogue) or Prowl (Druid).",
                        get = get("fun_sneaky_enabled"), set = set("fun_sneaky_enabled"),
                    },
                    fun_sneaky_opts = childGroup("fun_sneaky_enabled", 52, {
                        fun_sneaky_channel = {
                            type = "select", width = "full", order = 1,
                            name = "Sound Channel",
                            values = CHANNELS,
                            get = get("fun_sneaky_channel"), set = set("fun_sneaky_channel"),
                        },
                    }),

                    h_vendor = { type = "header", name = "Vendor", order = 60 },
                    fun_vendorSound_enabled = {
                        type = "toggle", width = "full", order = 61,
                        name = "Vendor Grey Sound",
                        desc = "Plays a money sound when grey items are sold, whether by the Auto-Sell option or the in-game Sell All Junk button.",
                        get = get("fun_vendorSound_enabled"), set = set("fun_vendorSound_enabled"),
                    },
                    fun_vendorSound_opts = childGroup("fun_vendorSound_enabled", 62, {
                        fun_vendorSound_channel = {
                            type = "select", width = "full", order = 1,
                            name = "Sound Channel",
                            values = CHANNELS,
                            get = get("fun_vendorSound_channel"), set = set("fun_vendorSound_channel"),
                        },
                    }),

                    h_zoomies = { type = "header", name = "Zoomies", order = 70 },
                    fun_zoomies_enabled = {
                        type = "toggle", width = "full", order = 71,
                        name = "Zoomies Sound",
                        desc = "Plays a sound when you use a major speed ability. Toggle individual spells below.",
                        get = get("fun_zoomies_enabled"), set = set("fun_zoomies_enabled"),
                    },
                    fun_zoomies_opts = childGroup("fun_zoomies_enabled", 72, {
                        fun_zoomies_cheetah = {
                            type = "toggle", width = "full", order = 1,
                            name = "|cffAAD372Aspect of the Cheetah|r",
                            desc = "Play zoomies for Aspect of the Cheetah (Hunter).",
                            get = get("fun_zoomies_cheetah"), set = set("fun_zoomies_cheetah"),
                        },
                        fun_zoomies_dash = {
                            type = "toggle", width = "full", order = 2,
                            name = "|cffFF7C0ADash|r",
                            desc = "Play zoomies for Dash (Druid).",
                            get = get("fun_zoomies_dash"), set = set("fun_zoomies_dash"),
                        },
                        fun_zoomies_steed = {
                            type = "toggle", width = "full", order = 3,
                            name = "|cffF48CBADivine Steed|r",
                            desc = "Play zoomies for Divine Steed (Paladin).",
                            get = get("fun_zoomies_steed"), set = set("fun_zoomies_steed"),
                        },
                        fun_zoomies_rush = {
                            type = "toggle", width = "full", order = 4,
                            name = "|cff8788EEBurning Rush|r",
                            desc = "Play zoomies for Burning Rush (Warlock).",
                            get = get("fun_zoomies_rush"), set = set("fun_zoomies_rush"),
                        },
                        fun_zoomies_channel = {
                            type = "select", width = "full", order = 5,
                            name = "Sound Channel",
                            values = CHANNELS,
                            get = get("fun_zoomies_channel"), set = set("fun_zoomies_channel"),
                        },
                    }),
                },
            },

            -- Guild module disabled
            -- Guild = { ... },
        },
    }

    addon.MI_SettingsUI_BuildTabs()

    -- Initialize minimap button
    addon.MI_MinimapButton_Init()

    -- Initialize features that need to be active on load
    addon.MI_MouseRing_Init()
    addon.MI_Dragonriding_Init()
    addon.MI_Reminders_Init()
    -- addon.MI_Guild_Init()  -- guild module disabled

    -- Apply CVars
    if addon.db.general_maxCameraDistance then
        SetCVar("cameraDistanceMaxZoomFactor", 2.6)
    end
end)

-- Slash command

SLASH_MYSTERIOUSQOL1 = "/mqol"
SlashCmdList["MYSTERIOUSQOL"] = function(msg)
    local cmd = msg and msg:lower() or ""
    if cmd == "guild" then
        if addon.MI_GuildPanel_Toggle then addon.MI_GuildPanel_Toggle() end
        return
    end
    if cmd == "syncdebug" then
        if addon.MI_GuildSync_ToggleDebug then addon.MI_GuildSync_ToggleDebug() end
        return
    end
    LibStub("AceConfigDialog-3.0"):Open("MysteriousQoL")
end
