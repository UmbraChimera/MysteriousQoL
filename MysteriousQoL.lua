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

    -- Debug: show every class's options in the panel, tagged with the class.
    local function showAllClasses()
        return addon.db.settings_debugAllClasses
    end
    local function classTag(className)
        if not showAllClasses() or not className then return "" end
        return " |cff888888(" .. className .. ")|r"
    end

    -- Options are sorted alphabetically within each heading by the panel, so
    -- the order below does not matter.
    UI.RegisterCategory("Settings", function()
        UI.Header("Addon")
        UI.Dropdown("sound_channel", "Sound Channel", channelOpts,
            "Audio channel used by every addon sound.")
        UI.Checkbox("ui_minimapButton_enabled", "Show Minimap Button",
            "Toggles the MysteriousQoL minimap button.",
            addon.MI_MinimapButton_SetShown)
        UI.Button("Reset Settings Panel", addon.MI_SettingsUI_ResetLayout)
        UI.Button("Guided Setup", function() addon.MI_Setup_Open() end)

        UI.Header("Debug")
        UI.Checkbox("settings_debugAllClasses", "Show All Classes",
            "Shows every class's options here, so you can check them without swapping characters. Only changes this panel.",
            function() UI.Rebuild() end)
    end)

    UI.RegisterCategory("General", function()
        UI.Header("Quests")
        UI.Checkbox("general_autoQuestAccept", "Auto-Accept Quests",
            "Automatically accepts quests from NPCs. Hold Alt to bypass.",
            nil,
            {
                { type = "checkbox", key = "general_autoQuest_skipTrivial", label = "Skip Grey Quests",
                  tooltip = "Don't auto-accept grey quests." },
            })
        UI.Checkbox("general_autoQuestTurnIn", "Auto Turn-In Quests",
            "Automatically turns in completed quests. Only auto-selects reward if there is one or no choice. Hold Alt to bypass.")
        UI.Checkbox("general_autoGossipSelect", "Auto-Select Gossip",
            "Automatically selects the gossip option when an NPC only has one. Hold Alt to bypass.")
        UI.Checkbox("general_autoFlightMap", "Skip Flight Master Chat",
            "Opens the flight map right away. Hold Alt to skip.")
        UI.Checkbox("ui_questRewardCoin_enabled", "Best Sell Price Reward",
            "Marks the quest reward that sells for the most.",
            addon.MI_QuestRewardCoin_Refresh)
        UI.Checkbox("ui_questXP_enabled", "Quest XP on Experience Bar",
            "Shows XP from finished quests on your XP bar.",
            addon.MI_QuestXP_SetEnabled)

        UI.Header("Automation")
        if addon.RETAIL then
            UI.Checkbox("general_ahCurrentExpansion", "AH: Current Expansion Only",
                "Automatically enables the Current Expansion filter when opening the Auction House.")
            UI.Checkbox("general_autoKeystone", "Auto-Slot Keystone",
                "Automatically places your Mythic+ keystone when the Challenge Mode frame opens.")
            UI.Checkbox("general_skipQueueConfirm", "Skip Queue Confirm",
                "Auto-clicks Sign Up in the group finder application dialog. Hold Ctrl to see the dialog.")
        end
        if addon.FOREVER then
            UI.Checkbox("forever_rankUpgrade_enabled", "Upgrade Spell Ranks on Bars",
                "When you learn a new rank of a spell, replaces lower ranks of it on your action bars. A lower rank you place back afterwards is left alone until the next rank.",
                addon.MI_SpellRankUpgrade_SetEnabled)
        end

        UI.Header("Loot")
        UI.Checkbox("general_fasterLoot", "Faster Auto-Loot",
            "Rapidly loots all items from a corpse instead of waiting for the default loot animation.")
        UI.Checkbox("general_suppressLootWarnings", "Suppress Loot Warnings",
            "Auto-confirms bind-on-pickup, loot roll, and trade timer removal dialogs.")

        UI.Header("Bags")
        UI.Checkbox("general_easyDestroy", "Easy Item Destroy",
            "Auto-fills the DELETE confirmation text so you can just click the button.")
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
            UI.Checkbox("forever_bagsFull_enabled", "Bags Full Helper",
                "When loot doesn't fit, offers your cheapest item to destroy.",
                addon.MI_BagsFull_SetEnabled,
                {
                    { type = "checkbox", key = "forever_bagsFull_lowOnly", label = "Only Grey And White Items",
                      tooltip = "Only suggest grey and white items." },
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

        if addon.FOREVER then
            UI.Header("Social")
            UI.Checkbox("general_thankBuffs", "Thank Buffers",
                "Sends /thank when a stranger buffs you.",
                addon.MI_BuffThanks_SetEnabled)
        end
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

        UI.Header("Camera")
        UI.Checkbox("general_maxCameraDistance", "Max Camera Distance",
            "Sets camera distance to maximum (2.6x zoom out). Your previous value is restored when disabled.",
            ApplyMaxCameraDistance)

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
            addon.MI_HideElements_ApplyErrors,
            {
                { type = "checkbox", key = "ui_hideErrors_keepImportant", label = "Keep Important Errors",
                  tooltip = "Still shows bags full and similar errors.",
                  onChange = addon.MI_HideElements_ApplyErrors },
            })
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

        UI.Header("Combat")
        if addon.RETAIL then
            UI.Checkbox("combat_buffReminder_enabled", "Class Buff Reminder",
                "Shows a glowing icon when your class buff is missing from you or any group member.",
                refreshReminders)
            UI.Checkbox("combat_deathReminder_enabled", "Don't Release Reminder",
                "Shows a large center-screen warning when you die in a raid instance to stop you releasing.",
                refreshReminders)
            UI.Checkbox("combat_cheatDeathReminder_enabled", "Cheat Death Reminder",
                "Plays an audio cue while in combat in an instance when Purgatory, Cheat Death, Cauterize, or Last Resort saves you.",
                refreshReminders)
            UI.Checkbox("combat_diveReminder_enabled", "Dive Reminder",
                "Shows a large DIVE warning while skyriding when debuff 1251978 is active.",
                refreshReminders)
            UI.Checkbox("combat_petReminder_enabled", "No Pet Reminder",
                "Shows a center-screen warning when you have no active pet (Warlock, Hunter BM/Survival, Unholy DK). Detects Grimoire of Sacrifice and no-pet talents.",
                refreshReminders)
            UI.Checkbox("combat_petIdleReminder_enabled", "Pet Idle Reminder",
                "Shows a center-screen warning when your pet is alive but not attacking while you are in combat.",
                refreshReminders)
            UI.Checkbox("combat_petMissingSound_enabled", "No Pet Sound",
                "Plays a baby murloc sound when you try to cast a pet ability without an active pet.")
            UI.Checkbox("combat_readyCheck_enabled", "Ready Check Preflight",
                "On a ready check, shows a personal checklist for durability, temporary weapon buffs, Well Fed, flask, and a Healthstone when a Warlock is in your group.",
                addon.MI_ReadyCheck_SetEnabled)
        end

        if addon.FOREVER and addon.MI_ClassBuffs_List then
            UI.Header("Buffs")
            -- Only paladins have seals.
            if select(2, UnitClass("player")) == "PALADIN" or showAllClasses() then
                UI.Checkbox("combat_sealReminder_enabled", "Seal Reminder" .. classTag("Paladin"),
                    "Shows your seal icon in combat when no seal is active.",
                    refreshReminders)
            end
            for _, buff in ipairs(addon.MI_ClassBuffs_List(showAllClasses())) do
                local children
                if buff.bearOnlyKey then
                    children = {
                        { type = "checkbox", key = buff.bearOnlyKey, label = "Bear Form Only",
                          tooltip = "Only remind you in Bear Form.", onChange = refreshReminders },
                    }
                elseif buff.shieldOnlyKey then
                    children = {
                        { type = "checkbox", key = buff.shieldOnlyKey, label = "Shield Only",
                          tooltip = "Only remind you with a shield equipped.", onChange = refreshReminders },
                    }
                end
                UI.Checkbox(buff.key, buff.label .. " Reminder" .. classTag(buff.class),
                    "Shows an icon when " .. buff.label .. " is missing, out of combat.",
                    refreshReminders, children)
            end
        end

        UI.Header("Upkeep")
        local reagents = addon.FOREVER and addon.MI_Reagents_List and addon.MI_Reagents_List(showAllClasses()) or {}
        if #reagents > 0 then
            -- One slider per reagent; 0 shows "Default" and follows Warn Below.
            local children = {
                { type = "slider", key = "forever_reagents_threshold", label = "Warn Below",
                  min = 1, max = 20, step = 1 },
            }
            for _, entry in ipairs(reagents) do
                children[#children + 1] = {
                    type = "slider", key = entry.key, label = entry.label .. classTag(entry.class),
                    min = 0, max = 20, step = 1, zeroText = "Default",
                    tooltip = "Default uses Warn Below.",
                }
            end
            UI.Checkbox("forever_reagents_enabled", "Reagent Reminder",
                "Warns when you are low on class reagents.",
                addon.MI_Reagents_SetEnabled, children)
        end
        if addon.FOREVER then
            UI.Checkbox("forever_campfireReminder_enabled", "Campfire Rest Reminder",
                "Prompts you to rest at a nearby campfire while levelling. Shows when Campfire Nearby is active but you have not taken Camp Benefits yet. Hidden at 60, in combat, and while dead.",
                refreshReminders)
        end
        UI.Checkbox("combat_mailReminder_enabled", "Mail Reminder",
            "Plays a sound on login if you have unread mail. Only triggers on initial login, not reloads.",
            addon.MI_MailReminder_SetEnabled)
        UI.Checkbox("combat_repairReminder_enabled", "Repair Reminder",
            "Warns when your gear drops to the set durability.",
            refreshReminders,
            {
                { type = "slider", key = "combat_repairReminder_pct", label = "Warn At %",
                  min = 5, max = 90, step = 5 },
            })

        if addon.RETAIL then
            UI.Header("Gathering")
            UI.Checkbox("combat_overloadReminder_enabled", "Overload Reminder",
                "Shows a warning when you begin mining or herbing and your Overload spell is off cooldown.",
                refreshReminders)
            UI.Checkbox("combat_mulchReminder_enabled", "Imbued Mulch Reminder",
                "Shows a warning when you begin herbing and Imbued Mulch is in your bags and off cooldown.",
                refreshReminders)
        end
    end)

    UI.RegisterCategory("Fun", function()
        UI.Header("Sounds")
        UI.Checkbox("fun_batman_enabled", "Batman Teleport Sound",
            "Plays the Batman sound when you teleport to a new zone via hearthstone, mage portal, or toy.")
        UI.Checkbox("fun_owenWilson_enabled", "Owen Wilson Loot Sounds",
            "Plays a random Owen Wilson \"wow\" sound whenever a loot window opens.")
        UI.Checkbox("fun_vendorSound_enabled", "Vendor Grey Sound",
            "Plays a money sound when grey items are sold, whether by the Auto-Sell option or the in-game Sell All Junk button.")
        if addon.FOREVER then
            UI.Checkbox("forever_plainsrunning_enabled", "Max Plainsrunning Sound",
                "Plays a sound when Plainsrunning (Tauren) reaches max stacks (30).",
                addon.MI_Plainsrunning_SetEnabled)
        end
        if addon.RETAIL then
            UI.Checkbox("fun_blink_enabled", "Blink Sound",
                "Plays a DBZ sound when you use Blink or Shimmer (Mage) or Shift (Demon Hunter).")
            UI.Checkbox("fun_bloodlust_enabled", "Bloodlust Sound",
                "Plays a sound in instances when Bloodlust, Heroism, Time Warp, or an equivalent haste effect is applied to you.",
                addon.MI_Bloodlust_SetEnabled,
                {
                    { type = "dropdown", key = "fun_bloodlust_sound", label = "Sound Choice",
                      options = {
                          { text = "R2-D2", value = "r2d2.ogg" },
                          { text = "Wei",   value = "wei.ogg" },
                      }},
                })
            UI.Checkbox("fun_rolling_enabled", "Roll Sound",
                "Plays a random sound when you use Roll or Chi Torpedo (Monk).")
            UI.Checkbox("fun_sneaky_enabled", "Stealth Sound",
                "Plays a sound when you enter Stealth (Rogue) or Prowl (Druid).")
            UI.Checkbox("fun_victory_enabled", "Encounter Victory Sound",
                "Plays a victory sound when you earn a tracked dungeon, raid, or Delve completion achievement inside an instance.",
                addon.MI_Victory_SetEnabled)
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

        UI.Header("Games")
        UI.Checkbox("fun_mystGems_enabled", "MystGems",
            "A match-3 gem game. Type /mqol gems to play.",
            addon.MI_MystGems_SetEnabled,
            {
                { type = "checkbox", key = "fun_mystGems_flight", label = "Open on Flight Paths",
                  tooltip = "Opens MystGems when you take a flight path and closes it when you land.",
                  onChange = addon.MI_MystGems_SetEnabled },
            })
    end)

    -- Initialize minimap button
    addon.MI_MinimapButton_Init()

    -- Initialize features that need to be active on load
    addon.MI_MouseRing_Init()
    addon.MI_GearIndicators_RefreshState()
    if addon.RETAIL then
        addon.MI_Dragonriding_Init()
        addon.MI_Zoomies_SetEnabled()
        addon.MI_Bloodlust_SetEnabled()
    end
    addon.MI_QuestXP_SetEnabled()
    if addon.FOREVER then
        addon.MI_BuffThanks_SetEnabled()
        addon.MI_BagSpace_SetEnabled()
        addon.MI_BagsFull_SetEnabled()
        addon.MI_Reagents_SetEnabled()
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
    -- /mqol setup opens the guided setup.
    if strtrim(msg or ""):lower() == "setup" and addon.MI_Setup_Open then
        addon.MI_Setup_Open()
        return
    end
    -- /mqol welcome opens the welcome popup again.
    if strtrim(msg or ""):lower() == "welcome" and addon.MI_Welcome_Show then
        addon.MI_Welcome_Show()
        return
    end
    -- /mqol gems toggles MystGems.
    if strtrim(msg or ""):lower() == "gems" and addon.MI_MystGems_Toggle then
        addon.MI_MystGems_Toggle()
        return
    end
    addon.customUI.Toggle()
end
