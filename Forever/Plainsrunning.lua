local _, addon = ...

-- Plays a sound when Plainsrunning (Tauren racial) reaches max stacks. Forever only.
--
-- The aura is found by name, so this needs an English client. Plainsrunning
-- doesn't stack in combat or instances, and auras are secret in combat, so the
-- check is skipped there.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Plainsrunning\\birb.ogg"
local AURA_NAME = "Plainsrunning"
local MAX_STACKS = 30
-- Dropping below this fades the sound out and lets it play again at max.
local REARM_BELOW = 25
local FADE_MS = 1500

local spellID
local played = false
local handle

-- Returns nil when the aura can't be read.
local function getStacks()
    local aura
    if spellID then
        aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    else
        aura = C_UnitAuras.GetAuraDataBySpellName("player", AURA_NAME, "HELPFUL")
    end
    if not aura then return 0 end
    if issecretvalue(aura.applications) then return nil end
    spellID = spellID or aura.spellId
    return aura.applications or 0
end

local function isPlaying()
    return handle and C_Sound.IsPlaying(handle)
end

local function fadeOut()
    if handle then
        StopSound(handle, FADE_MS)
        handle = nil
    end
end

local function onAura()
    if UnitAffectingCombat("player") then return end
    local stacks = getStacks()
    if not stacks then return end
    if stacks >= MAX_STACKS then
        if not played and not isPlaying() then
            played = true
            handle = select(2, PlaySoundFile(SOUND, addon.db.sound_channel or "Master"))
        end
        return
    end
    if stacks < REARM_BELOW then
        played = false
        fadeOut()
    end
end

local auraFrame = CreateFrame("Frame")
auraFrame:SetScript("OnEvent", onAura)

function addon.MI_Plainsrunning_SetEnabled()
    if addon.db.forever_plainsrunning_enabled then
        auraFrame:RegisterUnitEvent("UNIT_AURA", "player")
    else
        auraFrame:UnregisterAllEvents()
        fadeOut()
    end
end
