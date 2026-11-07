local addonName, addon = ...

local UI = addon.customUI
local channelOpts = {
    { text = "Master",        value = "Master" },
    { text = "Sound Effects", value = "SFX" },
    { text = "Music",         value = "Music" },
    { text = "Ambience",      value = "Ambience" },
    { text = "Dialog",        value = "Dialog" },
}

local CAMERA_DISTANCE_CVAR = "cameraDistanceMaxZoomFactor"
local MAX_CAMERA_DISTANCE = 2.6

local function ApplyMaxCameraDistance(enabled)
    if enabled then
        if addon.db.general_maxCameraDistance_previous == nil then
            local previous = tonumber(GetCVar(CAMERA_DISTANCE_CVAR))
            if previous then
                addon.db.general_maxCameraDistance_previous = previous
            end
        end
        SetCVar(CAMERA_DISTANCE_CVAR, MAX_CAMERA_DISTANCE)
        return
    end

    local previous = tonumber(addon.db.general_maxCameraDistance_previous)
    if previous then
        SetCVar(CAMERA_DISTANCE_CVAR, previous)
    end
    addon.db.general_maxCameraDistance_previous = nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    addon:MI_InitDB()

    -- Build custom settings frame
    addon.MI_SettingsUI_Init()

    UI.RegisterCategory("General", function()
        UI.Header("Settings")
        UI.Dropdown("sound_channel", "Sound Channel", channelOpts,
            "Audio channel used by every addon sound.")
        UI.Checkbox("ui_minimapButton_enabled", "Show Minimap Button",
            "Toggles the MysteriousQoL minimap button.",
            addon.MI_MinimapButton_SetShown)
        UI.Button("Reset Settings Panel", addon.MI_SettingsUI_ResetLayout)

        UI.Header("Automation")
        if addon.RETAIL then
            UI.Checkbox("general_ahCurrentExpansion", "AH: Current Expansion Only",
                "Automatically enables the Current Expansion filter when opening the Auction House.")
        end
        UI.Checkbox("general_autoQuestAccept", "Auto-Accept Quests",
            "Automatically accepts quests from NPCs. Hold Alt to bypass.")
        UI.Checkbox("general_autoGossipSelect", "Auto-Select Gossip",
            "Automatically selects the gossip option when an NPC only has one. Hold Alt to bypass.")
        if addon.RETAIL then
            UI.Checkbox("general_autoKeystone", "Auto-Slot Keystone",
                "Automatically places your Mythic+ keystone when the Challenge Mode frame opens.")
        end
        UI.Checkbox("general_autoQuestTurnIn", "Auto Turn-In Quests",
            "Automatically turns in completed quests. Only auto-selects reward if there is one or no choice. Hold Alt to bypass.")
        if addon.FOREVER then
            UI.Checkbox("forever_rankUpgrade_enabled", "Upgrade Spell Ranks on Bars",
                "When you learn a new rank of a spell, replaces lower ranks of it on your action bars. A lower rank you place back afterwards is left alone until the next rank.",
                addon.MI_SpellRankUpgrade_SetEnabled)
        end
        if addon.RETAIL then
            UI.Checkbox("general_skipQueueConfirm", "Skip Queue Confirm",
                "Auto-clicks Sign Up in the group finder application dialog. Hold Ctrl to see the dialog.")
        end

        UI.Header("Camera")
        UI.Checkbox("general_maxCameraDistance", "Max Camera Distance",
            "Sets camera distance to maximum (2.6x zoom out). Your previous value is restored when disabled.",
            ApplyMaxCameraDistance)

        UI.Header("Loot")
        UI.Checkbox("general_easyDestroy", "Easy Item Destroy",
            "Auto-fills the DELETE confirmation text so you can just click the button.")
        UI.Checkbox("general_fasterLoot", "Faster Auto-Loot",
            "Rapidly loots all items from a corpse instead of waiting for the default loot animation.")
        UI.Checkbox("general_suppressLootWarnings", "Suppress Loot Warnings",
            "Auto-confirms bind-on-pickup, loot roll, and trade timer removal dialogs.")
        if addon.FOREVER then
            UI.Checkbox("forever_bagSpace_enabled", "Bag Space Warning",
                "Warns when a loot window opens and you are nearly out of bag space. Normal bags and the reagent bag are counted separately; profession bags are ignored.",
                addon.MI_BagSpace_SetEnabled,
                {
                    { type = "slider", key = "forever_bagSpace_threshold", label = "Warn At Or Below",
                      min = 1, max = 20, step = 1 },
                    { type = "checkbox", key = "forever_bagSpace_ignoreReagent", label = "Ignore Reagent Bag",
                      tooltip = "Only warn about normal bag space. The reagent bag is never checked." },
                })
        end

        UI.Header("Vendor")
        UI.Checkbox("vendor_autoRepair", "Auto Repair",
            "Automatically repairs all equipment when visiting a merchant. Hold Shift to skip.",
            nil,
            {
                { type = "checkbox", key = "vendor_autoRepair_guildBank",
                  label = "Use Guild Bank for Repairs",
                  tooltip = "Prefer guild bank funds when auto-repairing, if available." },
            })
        UI.Checkbox("vendor_autoSell", "Auto Sell Greys",
            "Automatically sells all grey (poor quality) items when visiting a merchant. Hold Shift to skip.")
    end)

    UI.RegisterCategory("UI", function()
        UI.Header("Gear")
        UI.Checkbox("ui_bagUpgrade_enabled", "Bag Upgrade Arrows",
            "Shows a green arrow at the bottom right of higher item-level gear in Blizzard's bags. Compares rings and trinkets with the lower equipped slot. Uses your class's primary armor type. Item level only; does not evaluate stats, set bonuses, or weapon combinations.",
            addon.MI_GearIndicators_RefreshState)

        if addon.RETAIL then
            UI.Checkbox("ui_missingEnchant_enabled", "Missing Enchant Highlights",
                "Tints equipped items red in your character window when missing a permanent enchant. Checks Midnight head, shoulders, chest, legs, boots, rings, and weapons. Includes leg armor/spellthread; excludes shields, caster off-hands, and wands. Does not judge enchant quality or temporary oils.",
                addon.MI_GearIndicators_RefreshState)
        end

        UI.Header("Chat")
        UI.Checkbox("ui_chatCopy_enabled", "Chat Copy Button",
            "Adds a small copy button to each chat frame. Click to open a window with copyable chat text.",
            addon.MI_ChatCopy_UpdateVisibility)

        UI.Header("Hide Elements")
        UI.Checkbox("ui_hideAlerts_enabled", "Hide Alert Popups",
            "Hides achievement, loot, and other alert notifications.",
            addon.MI_HideElements_ApplyAlerts)
        UI.Checkbox("ui_hideErrors_enabled", "Hide Error Messages",
            "Hides the red UI error text (e.g. \"You don't have a pet.\", \"Out of range.\", \"Spell is not ready yet.\").",
            addon.MI_HideElements_ApplyErrors)
        -- Kept on Forever: Battle.net friend notifications may route through the
        -- event toast system, so this is not dead there until that is confirmed.
        UI.Checkbox("ui_hideEventToasts_enabled", "Hide Event Toasts",
            "Hides event notifications.",
            addon.MI_HideElements_ApplyEventToasts)
        -- Quick Join and the talking head frame do not exist in Forever.
        if addon.RETAIL then
            UI.Checkbox("ui_hideSocial_enabled", "Hide Social Button",
                "Hides the Quick Join toast button near the minimap.",
                addon.MI_HideElements_ApplySocial)
            UI.Checkbox("ui_hideTalkingHead_enabled", "Hide Talking Head",
                "Hides the NPC talking head dialog frame.",
                addon.MI_HideElements_ApplyTalkingHead)
        end
        UI.Checkbox("ui_hideZoneText_enabled", "Hide Zone Text",
            "Hides the zone name popup when entering a new area.",
            addon.MI_HideElements_ApplyZoneText)

        UI.Header("Mouse Ring")
        UI.Checkbox("ui_mouseRing_enabled", "Mouse Ring",
            "Shows a configurable ring around your cursor.",
            addon.MI_MouseRing_SetEnabled,
            {
                { type = "slider", key = "ui_mouseRing_size", label = "Ring Size",
                  min = 20, max = 100, step = 1,
                  onChange = addon.MI_MouseRing_ApplyStyle },
                { type = "checkbox", key = "ui_mouseRing_hideDot", label = "Hide Center Dot",
                  onChange = addon.MI_MouseRing_ApplyStyle },
                { type = "checkbox", key = "ui_mouseRing_onlyInCombat", label = "Only Show In Combat",
                  onChange = addon.MI_MouseRing_RefreshVisibility },
                { type = "checkbox", key = "ui_mouseRing_onlyOnRightClick", label = "Only Show On Right-Click",
                  tooltip = "Ring is visible only while the right mouse button is held." },
                { type = "checkbox", key = "ui_mouseRing_useClassColor", label = "Use Class Color",
                  onChange = addon.MI_MouseRing_ApplyStyle },
                { type = "checkbox", key = "ui_mouseRing_castProgress", label = "Show Cast Progress",
                  tooltip = "A ring sweeps along the outside to show cast or channel progress." },
            })

        if addon.RETAIL then
            UI.Header("Skyriding")
            UI.Checkbox("ui_dragonriding_enabled", "Skyriding Vigor Tracker",
                "Shows a vigor charge bar and speed display while skyriding. Hold Alt and drag the tracker to move it.",
                addon.MI_Dragonriding_SetEnabled,
                {
                    { type = "checkbox", key = "ui_dragonriding_showSpeed", label = "Show Speed Text",
                      tooltip = "Displays your forward speed as a number." },
                    { type = "checkbox", key = "ui_dragonriding_showSecondWind", label = "Show Second Wind",
                      tooltip = "Shows Second Wind bonus charges as a lighter overlay." },
                    { type = "checkbox", key = "ui_dragonriding_showWhirlingSurge", label = "Show Whirling Surge",
                      tooltip = "Shows the Whirling Surge cooldown icon next to the bar." },
                    { type = "checkbox", key = "ui_dragonriding_hideGroundedFull", label = "Hide When Full + Grounded",
                      tooltip = "Hides the tracker when you have full vigor and are not gliding." },
                })
        end
    end)

    UI.RegisterCategory("Reminders", function()
        local refreshReminders = addon.MI_Reminders_RefreshState

        if addon.RETAIL then
            UI.Header("Class Buff")
            UI.Checkbox("combat_buffReminder_enabled", "Class Buff Reminder",
                "Shows a glowing icon when your class buff is missing from you or any group member.",
                refreshReminders)

            UI.Header("Death")
            UI.Checkbox("combat_deathReminder_enabled", "Don't Release Reminder",
                "Shows a large center-screen warning when you die in a raid instance to stop you releasing.",
                refreshReminders)
            UI.Checkbox("combat_cheatDeathReminder_enabled", "Cheat Death Reminder",
                "Plays an audio cue while in combat in an instance when Purgatory, Cheat Death, Cauterize, or Last Resort saves you.",
                refreshReminders)

            UI.Header("Gathering")
            UI.Checkbox("combat_overloadReminder_enabled", "Overload Reminder",
                "Shows a warning when you begin mining or herbing and your Overload spell is off cooldown.",
                refreshReminders)
            UI.Checkbox("combat_mulchReminder_enabled", "Imbued Mulch Reminder",
                "Shows a warning when you begin herbing and Imbued Mulch is in your bags and off cooldown.",
                refreshReminders)

            UI.Header("Hungering Presence")
            UI.Checkbox("combat_diveReminder_enabled", "Dive Reminder",
                "Shows a large DIVE warning while skyriding when debuff 1251978 is active.",
                refreshReminders)
        end

        if addon.FOREVER then
            UI.Header("Campfire")
            UI.Checkbox("forever_campfireReminder_enabled", "Campfire Rest Reminder",
                "Prompts you to rest at a nearby campfire while levelling. Shows when Campfire Nearby is active but you have not taken Camp Benefits yet. Hidden at 60, in combat, and while dead.",
                refreshReminders)

            -- Only paladins have seals.
            if select(2, UnitClass("player")) == "PALADIN" then
                UI.Header("Seal")
                UI.Checkbox("combat_sealReminder_enabled", "Seal Reminder",
                    "Shows a glowing seal icon when you are in combat without any seal active. Hidden while dead, mounted or on a taxi.",
                    refreshReminders)
            end
        end

        UI.Header("Mail")
        UI.Checkbox("combat_mailReminder_enabled", "Mail Reminder",
            "Plays a sound on login if you have unread mail. Only triggers on initial login, not reloads.",
            addon.MI_MailReminder_SetEnabled)

        if addon.RETAIL then
            UI.Header("Pet")
            UI.Checkbox("combat_petReminder_enabled", "No Pet Reminder",
                "Shows a center-screen warning when you have no active pet (Warlock, Hunter BM/Survival, Unholy DK). Detects Grimoire of Sacrifice and no-pet talents.",
                refreshReminders)
            UI.Checkbox("combat_petIdleReminder_enabled", "Pet Idle Reminder",
                "Shows a center-screen warning when your pet is alive but not attacking while you are in combat.",
                refreshReminders)
            UI.Checkbox("combat_petMissingSound_enabled", "No Pet Sound",
                "Plays a baby murloc sound when you try to cast a pet ability without an active pet.")

            UI.Header("Ready Check")
            UI.Checkbox("combat_readyCheck_enabled", "Ready Check Preflight",
                "On a ready check, shows a personal checklist for durability, temporary weapon buffs, Well Fed, flask, and a Healthstone when a Warlock is in your group.",
                addon.MI_ReadyCheck_SetEnabled)
        end

        UI.Header("Repair")
        UI.Checkbox("combat_repairReminder_enabled", "Repair Reminder",
            "Shows a center-screen warning when any equipped gear drops to 50% durability (yellow).",
            refreshReminders)
    end)

    UI.RegisterCategory("Fun", function()
        UI.Header("Batman")
        UI.Checkbox("fun_batman_enabled", "Batman Teleport Sound",
            "Plays batman.ogg when you teleport to a new zone via hearthstone, mage portal, or toy.")

        if addon.RETAIL then
            UI.Header("Blink")
            UI.Checkbox("fun_blink_enabled", "Blink Sound",
                "Plays a DBZ sound when you use Blink or Shimmer (Mage) or Shift (Demon Hunter).")
        end

        if addon.RETAIL then
            UI.Header("Bloodlust")
            UI.Checkbox("fun_bloodlust_enabled", "Bloodlust Sound",
                "Plays a sound in instances when Bloodlust, Heroism, Time Warp, or an equivalent haste effect is applied to you.",
                nil,
                {
                    { type = "dropdown", key = "fun_bloodlust_sound", label = "Sound Choice",
                      options = {
                          { text = "R2-D2", value = "r2d2.ogg" },
                          { text = "Wei",   value = "wei.ogg" },
                      }},
                })
        end

        UI.Header("MystGems")
        UI.Checkbox("fun_mystGems_enabled", "MystGems",
            "A match-3 gem game. Type /mqol gems to play.",
            addon.MI_MystGems_SetEnabled,
            {
                { type = "checkbox", key = "fun_mystGems_flight", label = "Open on Flight Paths",
                  tooltip = "Opens MystGems when you take a flight path and closes it when you land.",
                  onChange = addon.MI_MystGems_SetEnabled },
            })

        UI.Header("Owen Wilson")
        UI.Checkbox("fun_owenWilson_enabled", "Owen Wilson Loot Sounds",
            "Plays a random Owen Wilson \"wow\" sound whenever a loot window opens.")

        if addon.FOREVER then
            UI.Header("Plainsrunning")
            UI.Checkbox("forever_plainsrunning_enabled", "Max Plainsrunning Sound",
                "Plays a sound when Plainsrunning (Tauren) reaches max stacks (30).",
                addon.MI_Plainsrunning_SetEnabled)
        end

        if addon.RETAIL then
            UI.Header("Roll")
            UI.Checkbox("fun_rolling_enabled", "Roll Sound",
                "Plays a random sound when you use Roll or Chi Torpedo (Monk).")
        end

        if addon.RETAIL then
            UI.Header("Stealth")
            UI.Checkbox("fun_sneaky_enabled", "Stealth Sound",
                "Plays a sound when you enter Stealth (Rogue) or Prowl (Druid).")
        end

        UI.Header("Vendor")
        UI.Checkbox("fun_vendorSound_enabled", "Vendor Grey Sound",
            "Plays a money sound when grey items are sold, whether by the Auto-Sell option or the in-game Sell All Junk button.")

        if addon.RETAIL then
            UI.Header("Victory")
            UI.Checkbox("fun_victory_enabled", "Encounter Victory Sound",
                "Plays a victory sound when you earn a tracked dungeon, raid, or Delve completion achievement inside an instance.",
                addon.MI_Victory_SetEnabled)
        end

        if addon.RETAIL then
            UI.Header("Zoomies")
            UI.Checkbox("fun_zoomies_enabled", "Zoomies Sound",
                "Plays a sound when you use a major speed ability. Toggle individual spells below.",
                addon.MI_Zoomies_SetEnabled,
                {
                    { type = "checkbox", key = "fun_zoomies_cheetah",
                      label = "|cffAAD372Aspect of the Cheetah|r",
                      tooltip = "Play zoomies for Aspect of the Cheetah (Hunter).",
                      onChange = addon.MI_Zoomies_SetEnabled },
                    { type = "checkbox", key = "fun_zoomies_dash",
                      label = "|cffFF7C0ADash|r",
                      tooltip = "Play zoomies for Dash (Druid).",
                      onChange = addon.MI_Zoomies_SetEnabled },
                    { type = "checkbox", key = "fun_zoomies_steed",
                      label = "|cffF48CBADivine Steed|r",
                      tooltip = "Play zoomies for Divine Steed (Paladin).",
                      onChange = addon.MI_Zoomies_SetEnabled },
                    { type = "checkbox", key = "fun_zoomies_rush",
                      label = "|cff8788EEBurning Rush|r",
                      tooltip = "Play zoomies for Burning Rush (Warlock).",
                      onChange = addon.MI_Zoomies_SetEnabled },
                })
        end

    end)

    -- Build sidebar tabs now that categories are registered
    addon.MI_SettingsUI_BuildTabs()

    -- Initialize minimap button
    addon.MI_MinimapButton_Init()

    -- Initialize features that need to be active on load
    addon.MI_MouseRing_Init()
    addon.MI_GearIndicators_RefreshState()
    if addon.RETAIL then
        addon.MI_Dragonriding_Init()
    end
    if addon.FOREVER then
        addon.MI_BagSpace_SetEnabled()
        addon.MI_SpellRankUpgrade_SetEnabled()
        addon.MI_Plainsrunning_SetEnabled()
    end
    addon.MI_Reminders_Init()
    if addon.RETAIL then
        addon.MI_ReadyCheck_Init()
    end
    addon.MI_MailReminder_Init()
    addon.MI_MystGems_SetEnabled()
    -- Apply CVars
    if addon.db.general_maxCameraDistance then
        ApplyMaxCameraDistance(true)
    end
end)

-- Slash command

SLASH_MYSTERIOUSQOL1 = "/mqol"
SlashCmdList["MYSTERIOUSQOL"] = function(msg)
    -- /mqol gems toggles MystGems.
    if strtrim(msg or ""):lower() == "gems" and addon.MI_MystGems_Toggle then
        addon.MI_MystGems_Toggle()
        return
    end
    addon.customUI.Toggle()
end
