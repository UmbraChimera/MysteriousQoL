local _, addon = ...

local DIVE_DEBUFF = 1251978

local function isSkyriding()
    if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return false end
    local _, canGlide = C_PlayerInfo.GetGlidingInfo()
    return canGlide == true
end

local function shouldShowDive()
    if not addon.db.combat_diveReminder_enabled then return false end
    if not isSkyriding() then return false end
    return C_UnitAuras.GetPlayerAuraBySpellID(DIVE_DEBUFF) ~= nil
end

-- ── Display frame ──────────────────────────────────────────────────────────

local diveFrame = addon.MI_CreateBouncingReminder("MysteriousQoL_DiveReminderFrame", {
    baseY    = 60,
    bounce   = 10,
    speed    = 4.0,
    fontSize = 56,
    color    = { 0.2, 0.8, 1, 1 },
    shadow   = { 3, -3 },
    width    = 400,
    height   = 90,
    strata   = "HIGH",
    text     = "DIVE",
})

-- ── Update ───────────────────────────────────────────────────────────────────

function addon.MI_DiveReminder_Update()
    if shouldShowDive() then
        diveFrame:Show()
    else
        diveFrame.ResetBounce()
        diveFrame:Hide()
    end
end
