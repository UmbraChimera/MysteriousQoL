# Changelog

## 1.1.2
- Better minimap icon

## 1.1.1
- Added Vendor Sound
- Code Cleanup

## 1.1.0 -Settings Revamp & New Features
Major overhaul of the settings system, code cleanup, and several new features.

### New Features
- **Custom Settings UI** - replaced the native WoW Settings panel with a custom teal-themed settings frame. Accessed via `/mqol` or the minimap button.
- **Chat Copy Button** - adds a small "C" button to each chat frame. Click to open a window with selectable, copyable chat text.
- **Mail Reminder** - plays a sound on initial login if you have unread mail. Does not fire on `/reload` or zone transitions.
- **Skyriding Vigor Tracker** - shows a vigor charge bar and speed display while skyriding. Options for Second Wind overlay, Whirling Surge cooldown, speed text, and auto-hide when full and grounded.
- **Hide Alert Popups** - hides achievement, loot, and other alert notifications.
- **Hide Event Toasts** - hides event notifications.
- **Hide Talking Head** - hides the NPC talking head dialog frame.
- **Hide Zone Text** - hides the zone name popup when entering a new area.
- **Auto-Accept Quests** - automatically accepts quests from NPCs. Hold Alt to bypass.
- **Auto-Select Gossip** - automatically selects the gossip option when an NPC only has one. Hold Alt to bypass.
- **Auto Turn-In Quests** - automatically turns in completed quests. Only auto-selects reward if there is one or no choice. Hold Alt to bypass.
- **Auto-Slot Keystone** - automatically places your Mythic+ keystone when the Challenge Mode frame opens.
- **AH: Current Expansion Only** - automatically enables the Current Expansion filter when opening the Auction House.
- **Easy Item Destroy** - auto-fills the DELETE confirmation text so you can just click the button.
- **Faster Auto-Loot** - rapidly loots all items instead of waiting for the default loot animation.
- **Suppress Loot Warnings** - auto-confirms bind-on-pickup, loot roll, and trade timer removal dialogs.
- **Skip Queue Confirm** - auto-clicks Sign Up in the group finder application dialog. Hold Ctrl to see the dialog.
- **Max Camera Distance** - sets camera distance to maximum (2.6x zoom out) on login.
- **Release Protection** - blocks the release button in dungeons and raids. Hold Alt for 1 second to release.
- **Minimap Button** - toggleable minimap button with drag repositioning and right-click to hide.

### Improvements
- All settings options sorted alphabetically within each category.
- Shared bouncing reminder factory (`MI_CreateBouncingReminder`) eliminates duplicated frame boilerplate across all reminder modules.
- Removed all dead code from the old native Settings API (`RegisterSettings` functions, `Core/Settings.lua`).
- All addon functions follow `MI_` naming convention.
- Minimap button reduced in size for a cleaner look.
- Right-click minimap button to hide it; prints a chat reminder to use `/mqol` to re-enable.
- Chat copy uses WoW's `StripHyperlinks` for reliable text cleaning.

## 1.0.12
- Added **Repair Reminder** - shows a bouncing center-screen warning when any equipped gear drops to 50% durability (yellow).
- Added **Hide Social Button** - option to hide the Quick Join toast button near the chat window.
- Added addon icon properly this time.

## 1.0.11
- **Zoomies Sound** now plays while the speed buff is active and stops when it ends. Loops if the buff outlasts the sound file. Added Burning Rush (Warlock) support.
- Aspect of the Cheetah now tracks both the initial burst and lingering speed buff seamlessly.
- **Class Buff Reminder** now suppressed while flying (skyriding).
- **No Pet / Pet Idle Reminder** now supports Unholy Death Knights.

## 1.0.10
- Added **Overload Reminder** - shows a bouncing "USE OVERLOAD!" warning when you start mining or herbing with your Overload spell off cooldown. Supports both Midnight Mining and Herb Gathering.
- Added **Don't Release Reminder** now split into its own file under Reminders/.
- Refactored Reminders into separate files: BuffReminder, PetReminder, DeathReminder, OverloadReminder.
- Code cleanup: removed unnecessary nil guards, simplified animation resets.

## 1.0.9
- Added **Don't Release Reminder** - shows a large bouncing "Don't release you dolt!" message when you die in a raid instance while in a raid group.
- Added **Shame Sound** - plays a sound when you release spirit in a raid instance. Does not fire for healer rezzes.

## 1.0.8
- Added **Combat Reminders** - center-screen visual indicators for things you shouldn't forget:
  - **Class Buff Reminder** - pulsing icon when your class buff (Mark of the Wild, Arcane Intellect, Power Word: Fortitude, Battle Shout, Blessing of the Bronze, or Skyfury) is missing from you or any group member. Suppressed while dead, mounted, in a vehicle, or on a taxi.
  - **No Pet Reminder** - bouncing center-screen warning when you have no active pet (Warlocks, BM/Survival Hunters).
  - **Pet Idle Reminder** - bouncing center-screen warning when your pet is alive but not attacking while you're in combat.
- Auto Sell Greys now prints the total value of items sold to chat.

## 1.0.7
- Added **Vendor Automation** - automatically repairs gear and sells grey items when visiting a merchant.
  - **Auto Repair** - repairs all equipped items on merchant open, prints cost to chat.
  - **Use Guild Bank for Repairs** - optionally draws repair costs from the guild bank.
  - **Auto Sell Greys** - sells all poor-quality items on merchant open.

## 1.0.6
- Bug fixes and stability improvements.

## 1.0.5
- Added **Zoomies Sound** - plays a sound on Aspect of the Cheetah, Dash, or Divine Steed.
- Added **Roll Sound** - plays a random sound on Roll or Chi Torpedo.
- Added **Stealth Sound** - plays a sound on Stealth or Prowl.

## 1.0.4
- Added **Mouse Ring** - configurable ring drawn around the cursor. Options: size, class color tint, hide center dot, only in combat, only on right-click, cast progress ring.
- Added **Blink Sound** - plays a DBZ sound on Blink, Shimmer, or Shift.

## 1.0.3
- Bug fixes.

## 1.0.2
- Added **Bloodlust Sound** - plays a sound when Bloodlust/Heroism/Time Warp/Ancient Hysteria/Primal Rage/Fury of the Aspects is applied to you, detected via Sated-family debuffs.

## 1.0.1
- Added **Batman Teleport Sound** - plays the Batman theme when zoning in via hearthstone, mage portal, or toy.

## 1.0.0
- Initial release.
- Added **Owen Wilson Loot Sounds** - plays a random Owen Wilson "wow" clip when a loot window opens.
