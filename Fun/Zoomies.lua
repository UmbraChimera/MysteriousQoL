local _, addon = ...

-- Plays a sound when the player uses a major speed ability.
-- When multiple sounds are available, convert SOUND to SOUND_DIR + dropdown (see Bloodlust.lua).

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Zoomies\\benny_hill.ogg"

-- Buffs detected via UNIT_AURA (sound loops while active, stops on removal).
-- Maps spell ID -> db key for the per-spell toggle.
local MI_ZOOM_BUFFS = {
    [186257] = "fun_zoomies_cheetah",  -- Aspect of the Cheetah (Hunter) - initial 90% burst
    [186258] = "fun_zoomies_cheetah",  -- Aspect of the Cheetah (Hunter) - lingering 30% speed
    [1850]   = "fun_zoomies_dash",     -- Dash                  (Druid)
    [190784] = "fun_zoomies_steed",    -- Divine Steed          (Paladin)
    [111400] = "fun_zoomies_rush",     -- Burning Rush          (Warlock)
}

local zoomPlaying = false
local zoomHandle = nil
local zoomTicker = nil
local pendingStop = nil

local function isSpellEnabled(spellID)
    local key = MI_ZOOM_BUFFS[spellID]
    return key and addon.db[key]
end

local function playZoom()
    zoomHandle = select(2, PlaySoundFile(SOUND, addon.db.fun_zoomies_channel))
end

local function startZoom()
    if pendingStop then pendingStop:Cancel(); pendingStop = nil end
    if zoomPlaying then return end
    zoomPlaying = true
    playZoom()
    if zoomTicker then zoomTicker:Cancel() end
    zoomTicker = C_Timer.NewTicker(1, function()
        if not zoomPlaying or not addon.db.fun_zoomies_enabled then
            if zoomTicker then zoomTicker:Cancel(); zoomTicker = nil end
            return
        end
        if zoomHandle and not C_Sound.IsPlaying(zoomHandle) then
            playZoom()
        end
    end)
end

-- 0.7s delay before stopping -some buffs briefly drop and reapply (e.g. Cheetah
-- transitions from burst to lingering phase), so we wait to avoid cutting the sound.
local function requestStop()
    if pendingStop then pendingStop:Cancel() end
    pendingStop = C_Timer.NewTimer(0.7, function()
        pendingStop = nil
        for id in pairs(MI_ZOOM_BUFFS) do
            if isSpellEnabled(id) and C_UnitAuras.GetPlayerAuraBySpellID(id) then return end
        end
        zoomPlaying = false
        if zoomTicker then zoomTicker:Cancel(); zoomTicker = nil end
        if zoomHandle then
            StopSound(zoomHandle)
            zoomHandle = nil
        end
    end)
end

local auraFrame = CreateFrame("Frame")
auraFrame:RegisterUnitEvent("UNIT_AURA", "player")
auraFrame:SetScript("OnEvent", function()
    if not addon.db.fun_zoomies_enabled then return end
    local anyActive = false
    for spellID in pairs(MI_ZOOM_BUFFS) do
        if isSpellEnabled(spellID) and C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            anyActive = true
            break
        end
    end
    if anyActive and not zoomPlaying then
        startZoom()
    elseif not anyActive and zoomPlaying then
        requestStop()
    end
end)
