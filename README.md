# MysteriousQoL

MysteriousQoL is a personal World of Warcraft Retail add-on with independently toggleable quality-of-life features.

## Getting Started

Open settings with `/mqol` or by clicking the minimap button. Settings and saved frame positions are account-wide, so changes made on one character apply to your other characters too.

Use the **Changelog** button at the bottom-left of the settings sidebar to view recent updates in game.

## General

**Automation**
- **AH: Current Expansion Only** - automatically enables the Current Expansion filter when opening the Auction House.
- **Auto-Accept Quests** - automatically accepts quests from NPCs. Hold Alt to bypass.
- **Auto-Select Gossip** - automatically selects the gossip option when an NPC only has one. Hold Alt to bypass.
- **Auto-Slot Keystone** - automatically places your Mythic+ keystone when the Challenge Mode frame opens.
- **Auto Turn-In Quests** - automatically turns in completed quests. Only auto-selects reward if there is one or no choice. Hold Alt to bypass.
- **Skip Queue Confirm** - auto-clicks Sign Up in the group finder application dialog. Hold Ctrl to see the dialog.

**Camera**
- **Max Camera Distance** - sets camera distance to maximum (2.6x zoom out) and restores your prior CVar value when disabled.

**Loot**
- **Easy Item Destroy** - auto-fills the DELETE confirmation text so you can just click the button.
- **Faster Auto-Loot** - rapidly loots all items instead of waiting for the default loot animation.
- **Suppress Loot Warnings** - auto-confirms bind-on-pickup, loot roll, and trade timer removal dialogs.

**Vendor**
- **Auto Repair** - automatically repairs all equipment when visiting a merchant. Optionally uses guild bank funds. Hold Shift to skip.
- **Auto Sell Greys** - automatically sells all grey (Poor quality) items when visiting a merchant. Hold Shift to skip.

## UI

- **Bag Upgrade Arrows** - marks equippable items in your bags with a green arrow when they have a higher item level than what you are wearing. Rings and trinkets compare against your lower-equipped item. The arrow is a quick item-level comparison, not a recommendation about stats or set bonuses.
- **Missing Enchant Highlights** - optional red tint on equipped items in the character window when missing a permanent enchant. Checks Midnight head, shoulders, chest, legs (armor kits/spellthread), boots, rings, and weapons; excludes shields, caster off-hands, and wands. Checks presence only, not enchant quality, temporary oils, or sockets. Uses Midnight's slot list even for older gear.
- **Chat Copy Button** - adds a small copy button to each chat frame. Click to open a window with selectable, copyable chat text.
- **Hide Alert Popups** - hides achievement, loot, and other alert notifications.
- **Hide Error Messages** - hides the red UI error text (e.g. "You don't have a pet.", "Out of range.", "Spell is not ready yet.").
- **Hide Event Toasts** - hides event notifications.
- **Hide Social Button** - hides the Quick Join toast button near the minimap.
- **Hide Talking Head** - hides the NPC talking head dialog frame.
- **Hide Zone Text** - hides the zone name popup when entering a new area.
- **Minimap Button** - toggleable minimap button. Left-click opens settings, right-click opens a menu, drag to reposition. Auto-swaps to a pride icon during June.
- **Mouse Ring** - configurable ring around your cursor. Options: size, class color, hide center dot, only in combat, only on right-click, cast progress.
- **Skyriding Vigor Tracker** - shows a vigor charge bar and speed display while skyriding. The tracker is mouse-transparent during normal play; hold Alt and left-drag to move it. Options cover Second Wind, Whirling Surge, speed text, and auto-hide when full and grounded.

## Reminders

- **Class Buff Reminder** - pulsing icon when your class buff is missing from you or any group member. Suppressed while dead, mounted, flying, in a vehicle, or on a taxi.
- **Cheat Death Reminder** - plays a sound when Purgatory, Cheat Death, Cauterize, or Last Resort saves you. Only active in combat inside an instance.
- **Dive Reminder** - shows a large DIVE warning while skyriding with Hungering Presence active.
- **Don't Release Reminder** - large bouncing warning when you die in a raid instance to prevent accidental release.
- **Imbued Mulch Reminder** - bouncing warning when you start herbing and Imbued Mulch is in your bags and off cooldown. Never shows inside instances.
- **Mail Reminder** - plays a sound on initial login if you have unread mail.
- **No Pet Reminder** - bouncing warning when you have no active pet (Warlock, Hunter BM/Survival, Unholy DK). Detects Grimoire of Sacrifice and no-pet talents.
- **No Pet Sound** - plays a random baby murloc sound when you try to cast a pet ability without an active pet (e.g. Kill Command).
- **Overload Reminder** - bouncing warning when you start mining or herbing with Overload off cooldown. Never shows inside instances.
- **Pet Idle Reminder** - bouncing warning when your pet is alive but not attacking while you are in combat.
- **Repair Reminder** - bouncing warning when any equipped gear drops to 50% durability.
- **Ready Check Preflight** - optional, draggable personal popup on ready checks for durability above 75%, temporary weapon buffs, Well Fed or Hearty Well Fed, a Midnight flask, and standard or Demonic Healthstones when a Warlock is in the group. It also confirms that at least one connected group member has Soulstone. It stays open until dismissed and never changes your ready-check response.

## Fun

All addon sounds use one shared configurable audio channel (Master, SFX, Music, Ambience, Dialog).

- **Batman Teleport Sound** - plays the Batman theme when you zone in via hearthstone, mage portal, or toy.
- **Blink Sound** - plays a DBZ sound on Blink/Shimmer (Mage) or Shift (Demon Hunter).
- **Bloodlust Sound** - plays a sound when Bloodlust/Heroism/Time Warp or equivalent is applied while you are inside an instance. Sound choice configurable (R2-D2 or Wei).
- **Owen Wilson Loot Sounds** - plays a random Owen Wilson "wow" clip when a loot window opens.
- **Roll Sound** - plays a random sound on Roll or Chi Torpedo (Monk).
- **Stealth Sound** - plays a sound on Stealth (Rogue) or Prowl (Druid).
- **Vendor Sound** - plays a money sound when grey items are sold.
- **Victory Sound** - optional achievement victory sound for a small set of achievements earned inside instances; disabled by default.
- **Zoomies Sound** - plays a sound on major speed abilities: Aspect of the Cheetah, Dash, Divine Steed, Burning Rush. Individual spells toggleable.
