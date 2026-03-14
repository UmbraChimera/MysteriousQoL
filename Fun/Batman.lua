local _, addon = ...

-- Plays batman.ogg when you teleport to a new zone (hearthstone, mage portal, toys, etc.).
-- Walking or flying across a zone boundary produces no loading screen, so it is ignored.
-- Death + release also triggers a loading screen; UnitIsDeadOrGhost filters that out.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Batman\\batman.ogg"

local didLoadingScreen = false

local f = CreateFrame("Frame")
f:RegisterEvent("LOADING_SCREEN_ENABLED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, isInitialLogin, isReloadingUI)
    if event == "LOADING_SCREEN_ENABLED" then
        didLoadingScreen = true

    elseif event == "PLAYER_ENTERING_WORLD" then
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
end)
