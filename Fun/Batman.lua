local _, addon = ...

-- Plays batman.ogg when you teleport to a new zone (hearthstone, mage portal, toys, etc.).
-- Walking or flying across a zone boundary produces no loading screen, so it is ignored.
-- Death + release also triggers a loading screen, so that case is filtered out separately.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Batman\\batman.ogg"

local PlaySoundFile = PlaySoundFile

local didLoadingScreen = false
local didDie          = false

local events = {}

function events.LOADING_SCREEN_ENABLED()
    didLoadingScreen = true
end

function events.PLAYER_DEAD()
    didDie = true
end

function events.PLAYER_UNGHOST()
    -- Player has fully resurrected; clear the flag so a subsequent
    -- teleport (e.g. ress-sickness skip hearthstone) can still trigger.
    didDie = false
end

function events.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUI)
    if didLoadingScreen
        and not isInitialLogin
        and not isReloadingUI
        and not didDie
        and addon.db.fun_batman_enabled
    then
        PlaySoundFile(SOUND, addon.db.fun_batman_channel)
    end
    didLoadingScreen = false
end

local f = CreateFrame("Frame")
f:RegisterEvent("LOADING_SCREEN_ENABLED")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_UNGHOST")
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
