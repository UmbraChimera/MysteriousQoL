local addonName, addon = ...

local UI = addon.customUI
local channelOpts = {
    { text = "Master",        value = "Master" },
    { text = "Sound Effects", value = "SFX" },
    { text = "Music",         value = "Music" },
    { text = "Ambience",      value = "Ambience" },
    { text = "Dialog",        value = "Dialog" },
}

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

        UI.Header("Automation")
        UI.Checkbox("general_ahCurrentExpansion", "AH: Current Expansion Only",
            "Automatically enables the Current Expansion filter when opening the Auction House.")
        UI.Checkbox("general_autoQuestAccept", "Auto-Accept Quests",
            "Automatically accepts quests from NPCs. Hold Alt to bypass.")
        UI.Checkbox("general_autoGossipSelect", "Auto-Select Gossip",
            "Automatically selects the gossip option when an NPC only has one. Hold Alt to bypass.")
        UI.Checkbox("general_autoKeystone", "Auto-Slot Keystone",
            "Automatically places your Mythic+ keystone when the Challenge Mode frame opens.")
        UI.Checkbox("general_autoQuestTurnIn", "Auto Turn-In Quests",
            "Automatically turns in completed quests. Only auto-selects reward if there is one or no choice. Hold Alt to bypass.")
        UI.Checkbox("general_skipQueueConfirm", "Skip Queue Confirm",
            "Auto-clicks Sign Up in the group finder application dialog. Hold Ctrl to see the dialog.")

        UI.Header("Camera")
        UI.Checkbox("general_maxCameraDistance", "Max Camera Distance",
            "Sets camera distance to maximum (2.6x zoom out). Applied on login.",
            function(v)
                if v then
                    SetCVar("cameraDistanceMaxZoomFactor", 2.6)
                else
                    SetCVar("cameraDistanceMaxZoomFactor", 1.9)
                end
            end)

        UI.Header("Loot")
        UI.Checkbox("general_easyDestroy", "Easy Item Destroy",
            "Auto-fills the DELETE confirmation text so you can just click the button.")
        UI.Checkbox("general_fasterLoot", "Faster Auto-Loot",
            "Rapidly loots all items from a corpse instead of waiting for the default loot animation.")
        UI.Checkbox("general_suppressLootWarnings", "Suppress Loot Warnings",
            "Auto-confirms bind-on-pickup, loot roll, and trade timer removal dialogs.")

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
        UI.Header("Chat")
        UI.Checkbox("ui_chatCopy_enabled", "Chat Copy Button",
            "Adds a small copy button to each chat frame. Click to open a window with copyable chat text.",
            addon.MI_ChatCopy_UpdateVisibility)

        UI.Header("Hide Elements")
        UI.Checkbox("ui_hideAlerts_enabled", "Hide Alert Popups",
            "Hides achievement, loot, and other alert notifications.")
        UI.Checkbox("ui_hideErrors_enabled", "Hide Error Messages",
            "Hides the red UI error text (e.g. \"You don't have a pet.\", \"Out of range.\", \"Spell is not ready yet.\").",
            addon.MI_HideElements_ApplyErrors)
        UI.Checkbox("ui_hideEventToasts_enabled", "Hide Event Toasts",
            "Hides event notifications.")
        UI.Checkbox("ui_hideSocial_enabled", "Hide Social Button",
            "Hides the Quick Join toast button near the minimap.",
            addon.MI_HideElements_ApplySocial)
        UI.Checkbox("ui_hideTalkingHead_enabled", "Hide Talking Head",
            "Hides the NPC talking head dialog frame.")
        UI.Checkbox("ui_hideZoneText_enabled", "Hide Zone Text",
            "Hides the zone name popup when entering a new area.")

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
                { type = "checkbox", key = "ui_mouseRing_onlyInCombat", label = "Only Show In Combat" },
                { type = "checkbox", key = "ui_mouseRing_onlyOnRightClick", label = "Only Show On Right-Click",
                  tooltip = "Ring is visible only while the right mouse button is held." },
                { type = "checkbox", key = "ui_mouseRing_useClassColor", label = "Use Class Color",
                  onChange = addon.MI_MouseRing_ApplyStyle },
                { type = "checkbox", key = "ui_mouseRing_castProgress", label = "Show Cast Progress",
                  tooltip = "A ring sweeps along the outside to show cast or channel progress." },
            })

        UI.Header("Skyriding")
        UI.Checkbox("ui_dragonriding_enabled", "Skyriding Vigor Tracker",
            "Shows a vigor charge bar and speed display while skyriding.",
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
    end)

    UI.RegisterCategory("Reminders", function()
        UI.Header("Class Buff")
        local refreshReminders = addon.MI_Reminders_RefreshState

        UI.Checkbox("combat_buffReminder_enabled", "Class Buff Reminder",
            "Shows a glowing icon when your class buff is missing from you or any group member.",
            refreshReminders)

        UI.Header("Death")
        UI.Checkbox("combat_deathReminder_enabled", "Don't Release Reminder",
            "Shows a large center-screen warning when you die in a raid instance to stop you releasing.",
            refreshReminders)
        UI.Checkbox("combat_cheatDeathReminder_enabled", "Cheat Death Reminder",
            "Shows a warning while in combat in an instance when Purgatory, Cheat Death, or Cauterize saves you.",
            refreshReminders)

        UI.Header("Gathering")
        UI.Checkbox("combat_overloadReminder_enabled", "Overload Reminder",
            "Shows a warning when you begin mining or herbing and your Overload spell is off cooldown.",
            refreshReminders)
        UI.Checkbox("combat_mulchReminder_enabled", "Imbued Mulch Reminder",
            "Shows a warning when you begin herbing and Imbued Mulch is in your bags and off cooldown.",
            refreshReminders)

        UI.Header("Mail")
        UI.Checkbox("combat_mailReminder_enabled", "Mail Reminder",
            "Plays a sound on login if you have unread mail. Only triggers on initial login, not reloads.")

        UI.Header("Pet")
        UI.Checkbox("combat_petReminder_enabled", "No Pet Reminder",
            "Shows a center-screen warning when you have no active pet (Warlock, Hunter BM/Survival, Unholy DK). Detects Grimoire of Sacrifice and no-pet talents.",
            refreshReminders)
        UI.Checkbox("combat_petIdleReminder_enabled", "Pet Idle Reminder",
            "Shows a center-screen warning when your pet is alive but not attacking while you are in combat.",
            refreshReminders)
        UI.Checkbox("combat_petMissingSound_enabled", "No Pet Sound",
            "Plays a baby murloc sound when you try to cast a pet ability without an active pet.")

        UI.Header("Repair")
        UI.Checkbox("combat_repairReminder_enabled", "Repair Reminder",
            "Shows a center-screen warning when any equipped gear drops to 50% durability (yellow).",
            refreshReminders)

        UI.Header("Hungering Presence")
        UI.Checkbox("combat_diveReminder_enabled", "Dive Reminder",
            "Shows a large DIVE warning while skyriding when debuff 1251978 is active.",
            refreshReminders)
    end)

    UI.RegisterCategory("Fun", function()
        UI.Header("Batman")
        UI.Checkbox("fun_batman_enabled", "Batman Teleport Sound",
            "Plays batman.ogg when you teleport to a new zone via hearthstone, mage portal, or toy.")

        UI.Header("Blink")
        UI.Checkbox("fun_blink_enabled", "Blink Sound",
            "Plays a DBZ sound when you use Blink or Shimmer (Mage) or Shift (Demon Hunter).")

        UI.Header("Bloodlust")
        UI.Checkbox("fun_bloodlust_enabled", "Bloodlust Sound",
            "Plays a sound when Bloodlust, Heroism, Time Warp, or any equivalent haste effect is applied to you.",
            nil,
            {
                { type = "dropdown", key = "fun_bloodlust_sound", label = "Sound Choice",
                  options = {
                      { text = "R2-D2", value = "r2d2.ogg" },
                      { text = "Wei",   value = "wei.ogg" },
                  }},
            })

        UI.Header("Owen Wilson")
        UI.Checkbox("fun_owenWilson_enabled", "Owen Wilson Loot Sounds",
            "Plays a random Owen Wilson \"wow\" sound whenever a loot window opens.")

        UI.Header("Roll")
        UI.Checkbox("fun_rolling_enabled", "Roll Sound",
            "Plays a random sound when you use Roll or Chi Torpedo (Monk).")

        UI.Header("Stealth")
        UI.Checkbox("fun_sneaky_enabled", "Stealth Sound",
            "Plays a sound when you enter Stealth (Rogue) or Prowl (Druid).")

        UI.Header("Vendor")
        UI.Checkbox("fun_vendorSound_enabled", "Vendor Grey Sound",
            "Plays a money sound when grey items are sold, whether by the Auto-Sell option or the in-game Sell All Junk button.")

        UI.Header("Zoomies")
        UI.Checkbox("fun_zoomies_enabled", "Zoomies Sound",
            "Plays a sound when you use a major speed ability. Toggle individual spells below.",
            nil,
            {
                { type = "checkbox", key = "fun_zoomies_cheetah",
                  label = "|cffAAD372Aspect of the Cheetah|r",
                  tooltip = "Play zoomies for Aspect of the Cheetah (Hunter)." },
                { type = "checkbox", key = "fun_zoomies_dash",
                  label = "|cffFF7C0ADash|r",
                  tooltip = "Play zoomies for Dash (Druid)." },
                { type = "checkbox", key = "fun_zoomies_steed",
                  label = "|cffF48CBADivine Steed|r",
                  tooltip = "Play zoomies for Divine Steed (Paladin)." },
                { type = "checkbox", key = "fun_zoomies_rush",
                  label = "|cff8788EEBurning Rush|r",
                  tooltip = "Play zoomies for Burning Rush (Warlock)." },
            })
    end)

    -- Build sidebar tabs now that categories are registered
    addon.MI_SettingsUI_BuildTabs()

    -- Initialize minimap button
    addon.MI_MinimapButton_Init()

    -- Initialize features that need to be active on load
    addon.MI_MouseRing_Init()
    addon.MI_Dragonriding_Init()
    addon.MI_Reminders_Init()
    -- Apply CVars
    if addon.db.general_maxCameraDistance then
        SetCVar("cameraDistanceMaxZoomFactor", 2.6)
    end
end)

-- Slash command

SLASH_MYSTERIOUSQOL1 = "/mqol"
SlashCmdList["MYSTERIOUSQOL"] = function()
    addon.customUI.Toggle()
end
