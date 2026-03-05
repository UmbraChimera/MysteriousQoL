local addonName, addon = ...

-- Plays batman.mp3 when you teleport to a new zone (hearthstone, mage portal, toys, etc.).
-- Walking or flying across a zone boundary produces no loading screen, so it is ignored.
-- Death + release also triggers a loading screen, so that case is filtered out separately.

local SOUND = "Interface\\AddOns\\MysteriousQoL\\Sounds\\Batman\\batman.mp3"

local didLoadingScreen = false
local didDie          = false

local f = CreateFrame("Frame")
f:RegisterEvent("LOADING_SCREEN_ENABLED")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_UNGHOST")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, isInitialLogin, isReloadingUI)
    if event == "LOADING_SCREEN_ENABLED" then
        didLoadingScreen = true

    elseif event == "PLAYER_DEAD" then
        didDie = true

    elseif event == "PLAYER_UNGHOST" then
        -- Player has fully resurrected; clear the flag so a subsequent
        -- teleport (e.g. ress-sickness skip hearthstone) can still trigger.
        didDie = false

    elseif event == "PLAYER_ENTERING_WORLD" then
        if didLoadingScreen
            and not isInitialLogin
            and not isReloadingUI
            and not didDie
        then
            if addon.db and addon.db.fun_batman_enabled then
                PlaySoundFile(SOUND, addon.db.fun_batman_channel or "Master")
            end
        end
        didLoadingScreen = false
    end
end)

function addon.MI_Batman_RegisterSettings(funCat)
    local function GetChannelOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("Master",   "Master")
        container:Add("SFX",      "Sound Effects")
        container:Add("Music",    "Music")
        container:Add("Ambience", "Ambience")
        container:Add("Dialog",   "Dialog")
        return container:GetData()
    end

    addon.settings.Checkbox(
        funCat,
        "fun_batman_enabled",
        "Batman Teleport Sound",
        "Plays batman.mp3 when you teleport to a new zone via hearthstone, mage portal, or toy. Does not trigger on walk/fly zone transitions or death."
    )
    addon.settings.Dropdown(
        funCat,
        "fun_batman_channel",
        "Batman Sound Channel",
        GetChannelOptions,
        "Which audio channel to use for the Batman sound."
    )
end
