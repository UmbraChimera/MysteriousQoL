local _, addon = ...

-- Plays batman.ogg when you teleport to a new zone (hearthstone, mage portal, toys, etc.).
-- Walking or flying across a zone boundary produces no loading screen, so it is ignored.
-- Death + release also triggers a loading screen; UnitIsDeadOrGhost filters that out.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Batman\\batman.ogg"

local PlaySoundFile      = PlaySoundFile
local UnitIsDeadOrGhost  = UnitIsDeadOrGhost

local didLoadingScreen = false

local events = {}

function events.LOADING_SCREEN_ENABLED()
    didLoadingScreen = true
end

function events.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUI)
    if didLoadingScreen
        and not isInitialLogin
        and not isReloadingUI
        and not UnitIsDeadOrGhost("player")
        and addon.db.fun_batman_enabled
    then
        PlaySoundFile(SOUND, addon.db.fun_batman_channel)
    end
    didLoadingScreen = false
end

local f = CreateFrame("Frame")
f:RegisterEvent("LOADING_SCREEN_ENABLED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, ...) events[event](...) end)

function addon.MI_Batman_RegisterSettings(funCat)
    addon.settings.Checkbox(
        funCat,
        "fun_batman_enabled",
        "Batman Teleport Sound",
        "Plays batman.ogg when you teleport to a new zone via hearthstone, mage portal, or toy. Does not trigger on walk/fly zone transitions or death."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_batman_channel",
        "Batman Sound Channel",
        addon.settings.GetChannelOptions,
        "Which audio channel to use for the Batman sound."
    )
end
