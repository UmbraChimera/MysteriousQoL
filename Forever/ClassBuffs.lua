local _, addon = ...

-- Class buff reminders for Forever. Out of combat, shows an icon for each
-- picked buff you know but do not have. Buff auras are hidden from addons in
-- combat, so nothing shows there.
--
-- Buffs are matched by name, so every rank counts. "spells" are the ones you
-- cast (rank 1 IDs; you must know one), "also" are other buffs that count,
-- like the group versions.
--
-- Weapon entries (poisons, shaman imbues) check the temporary enchant on
-- that weapon slot instead of your buffs. "minLevel" stands in for "spells"
-- where there is no spell to know (rogues get poisons at 20).

local BUFFS = {
    DRUID = {
        { key = "forever_buff_motw", label = "Mark of the Wild", spells = { 1126 }, also = { 21849 } },
        { key = "forever_buff_thorns", label = "Thorns", spells = { 467 },
          bearOnlyKey = "forever_buff_thorns_bearOnly" },
    },
    MAGE = {
        { key = "forever_buff_intellect", label = "Arcane Intellect", spells = { 1459 }, also = { 23028 } },
        { key = "forever_buff_mageArmor", label = "Frost, Ice or Mage Armor", spells = { 168, 7302, 6117 } },
    },
    PRIEST = {
        { key = "forever_buff_fortitude", label = "Power Word: Fortitude", spells = { 1243 }, also = { 21562 } },
        { key = "forever_buff_innerFire", label = "Inner Fire", spells = { 588 } },
        { key = "forever_buff_divineSpirit", label = "Divine Spirit", spells = { 14752 }, also = { 27681 } },
        { key = "forever_buff_shadowProt", label = "Shadow Protection", spells = { 976 }, also = { 27683 } },
    },
    PALADIN = {
        { key = "forever_buff_righteousFury", label = "Righteous Fury", spells = { 25780 },
          shieldOnlyKey = "forever_buff_righteousFury_shieldOnly" },
        { key = "forever_buff_blessing", label = "Blessing", spells = { 19740, 19742, 20217, 20911 },
          also = { 25782, 25894, 25898, 25916, 25918 } },
    },
    WARLOCK = {
        { key = "forever_buff_demonArmor", label = "Demon Skin or Armor", spells = { 687, 706 } },
    },
    SHAMAN = {
        { key = "forever_buff_lightningShield", label = "Lightning Shield", spells = { 324 } },
        -- Rockbiter, Flametongue, Frostbrand, Windfury
        { key = "forever_buff_weaponImbue", label = "Weapon Imbue", weapon = 16,
          spells = { 8017, 8024, 8033, 8232 } },
    },
    ROGUE = {
        { key = "forever_buff_poisonMain", label = "Main Hand Poison", weapon = 16,
          minLevel = 20, iconItem = 6947 },
        { key = "forever_buff_poisonOff", label = "Off Hand Poison", weapon = 17,
          minLevel = 20, iconItem = 6947 },
    },
    WARRIOR = {
        { key = "forever_buff_battleShout", label = "Battle Shout", spells = { 6673 } },
    },
    HUNTER = {
        { key = "forever_buff_trueshot", label = "Trueshot Aura", spells = { 19506 } },
        -- Hawk, Monkey, Cheetah, Beast, Wild
        { key = "forever_buff_aspect", label = "Aspect", spells = { 13165, 13163, 5118, 13161, 20043 } },
    },
}

local BEAR_FORMS = { [5] = true, [8] = true } -- Bear, Dire Bear

local function classBuffs()
    return BUFFS[addon.playerClass or select(2, UnitClass("player"))] or {}
end

local CLASS_NAMES = {
    DRUID = "Druid", MAGE = "Mage", PRIEST = "Priest", PALADIN = "Paladin", WARLOCK = "Warlock",
    SHAMAN = "Shaman", WARRIOR = "Warrior", HUNTER = "Hunter", ROGUE = "Rogue",
}

-- For the settings panel: this class's buffs, or every class's with all set
-- (debug). Each entry is the buff plus class (English class name).
function addon.MI_ClassBuffs_List(all)
    local out = {}
    local own = addon.playerClass or select(2, UnitClass("player"))
    for class, list in pairs(BUFFS) do
        if all or class == own then
            for _, buff in ipairs(list) do
                out[#out + 1] = setmetatable({ class = CLASS_NAMES[class] }, { __index = buff })
            end
        end
    end
    return out
end

function addon.MI_ClassBuffs_AllKeys()
    local keys = {}
    for _, list in pairs(BUFFS) do
        for _, buff in ipairs(list) do keys[#keys + 1] = buff.key end
    end
    return keys
end

-- Names can be nil right after login, so nothing is cached until all resolve.
local nameCache = {}
local function namesFor(buff)
    if nameCache[buff.key] then return nameCache[buff.key] end
    local names, complete = {}, true
    for _, list in ipairs({ buff.spells, buff.also or {} }) do
        for _, id in ipairs(list) do
            local name = C_Spell.GetSpellName(id)
            if name then names[name] = true else complete = false end
        end
    end
    if complete then nameCache[buff.key] = names end
    return names
end

-- The spell ID you know (for the icon), true for level-gated entries, or nil.
local function knows(buff)
    if buff.minLevel then
        return UnitLevel("player") >= buff.minLevel or nil
    end
    for _, id in ipairs(buff.spells) do
        if IsPlayerSpell(id) then return id end
    end
end

local OFF_HAND_WEAPONS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }

-- A weapon in that slot that can take a poison or imbue.
local function hasWeapon(slot)
    local id = GetInventoryItemID("player", slot)
    if not id then return false end
    if slot == 16 then return true end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(id)
    return OFF_HAND_WEAPONS[equipLoc] or false
end

local function hasWeaponEnchant(slot)
    local hasMain, _, _, _, hasOff = GetWeaponEnchantInfo()
    if slot == 16 then return hasMain and true or false end
    return hasOff and true or false
end

local function iconFor(buff, known)
    if buff.iconItem then return C_Item.GetItemIconByID(buff.iconItem) end
    return C_Spell.GetSpellTexture(known)
end

local function hasShield()
    local id = GetInventoryItemID("player", 17)
    if not id then return false end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(id)
    return equipLoc == "INVTYPE_SHIELD"
end

-- Names of every buff on you, or nil if any are hidden.
local function currentBuffs()
    local names = {}
    for i = 1, 40 do
        if C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret
            and C_Secrets.ShouldUnitAuraIndexBeSecret("player", i, "HELPFUL") then
            return nil
        end
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        names[aura.name] = true
    end
    return names
end

local function suppressed()
    return UnitAffectingCombat("player") or UnitIsDeadOrGhost("player")
        or UnitOnTaxi("player") or IsMounted() or IsResting()
end

-- Icons to show, one per missing buff.
local function missingBuffs()
    local list = classBuffs()
    if #list == 0 or suppressed() then return {} end
    local have = currentBuffs()
    if not have then return {} end
    local missing = {}
    for _, buff in ipairs(list) do
        local known = addon.db[buff.key] and knows(buff) or nil
        local wanted = known ~= nil
        if wanted and buff.weapon then
            wanted = hasWeapon(buff.weapon)
        end
        if wanted and buff.bearOnlyKey and addon.db[buff.bearOnlyKey] then
            wanted = BEAR_FORMS[GetShapeshiftFormID() or 0] or false
        end
        if wanted and buff.shieldOnlyKey and addon.db[buff.shieldOnlyKey] then
            wanted = hasShield()
        end
        if wanted then
            local found = false
            if buff.weapon then
                found = hasWeaponEnchant(buff.weapon)
            else
                for name in pairs(namesFor(buff)) do
                    if have[name] then found = true break end
                end
            end
            if not found then missing[#missing + 1] = iconFor(buff, known) end
        end
    end
    return missing
end

-- A row of pulsing icons above the seal reminder.
local ICON_SIZE, GAP = 40, 6
local row = CreateFrame("Frame", "MysteriousQoL_ClassBuffsFrame", UIParent)
row:SetSize(ICON_SIZE, ICON_SIZE)
row:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
row:SetFrameStrata("MEDIUM")
row:Hide()

local pulse = row:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.4)
fade:SetDuration(0.6)

local icons = {}
local function icon(i)
    if not icons[i] then
        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icons[i] = tex
    end
    return icons[i]
end

function addon.MI_ClassBuffs_Update()
    local missing = addon.FOREVER and missingBuffs() or {}
    for _, tex in ipairs(icons) do tex:Hide() end
    if #missing == 0 then
        pulse:Stop()
        row:SetAlpha(1)
        row:Hide()
        return
    end
    local total = #missing * ICON_SIZE + (#missing - 1) * GAP
    row:SetWidth(total)
    for i, texture in ipairs(missing) do
        local tex = icon(i)
        tex:SetTexture(texture)
        tex:ClearAllPoints()
        tex:SetPoint("LEFT", (i - 1) * (ICON_SIZE + GAP), 0)
        tex:Show()
    end
    if not row:IsShown() then
        row:Show()
        pulse:Play()
    end
end
