local _, addon = ...

-- Thin shim: the actual settings are defined as an AceConfig options table in
-- MysteriousQoL.lua. This file exists to preserve the MI_SettingsUI_Init /
-- MI_SettingsUI_BuildTabs call sites and to expose addon.customUI.Toggle.

function addon.MI_SettingsUI_Init()
    addon.customUI = {
        Toggle = function()
            LibStub("AceConfigDialog-3.0"):Open("MysteriousQoL")
        end,
    }
end

function addon.MI_SettingsUI_BuildTabs()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("MysteriousQoL", addon._options)
end
