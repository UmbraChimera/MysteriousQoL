local addonName, addon = ...

-- Thin wrappers around WoW's native Settings API (no libraries required).
-- All settings are backed by addon.db (MysteriousQoLDB SavedVariables).
-- onChange : optional function(value) called after the value is written to addon.db.
addon.settings = {}

-- Creates a boolean checkbox in the given category.
-- key    : key in addon.db / addon.defaults
-- name   : display label shown in the panel
-- desc   : optional tooltip / description text shown below the control
function addon.settings.Checkbox(cat, key, name, desc, onChange)
    local function Get() return addon.db[key] end
    local function Set(value)
        addon.db[key] = value
        if onChange then onChange(value) end
    end
    local setting = Settings.RegisterProxySetting(
        cat,
        "MysteriousQoL_" .. key,
        Settings.VarType.Boolean,
        name,
        addon.defaults[key],
        Get, Set
    )
    Settings.CreateCheckbox(cat, setting, desc)
    return setting
end

-- Creates a string dropdown in the given category.
-- optionsFn : function() returning Settings.CreateControlTextContainer data
function addon.settings.Dropdown(cat, key, name, optionsFn, desc, onChange)
    local function Get() return addon.db[key] end
    local function Set(value)
        addon.db[key] = value
        if onChange then onChange(value) end
    end
    local setting = Settings.RegisterProxySetting(
        cat,
        "MysteriousQoL_" .. key,
        Settings.VarType.String,
        name,
        addon.defaults[key],
        Get, Set
    )
    Settings.CreateDropdown(cat, setting, optionsFn, desc)
    return setting
end

-- Creates a numeric slider in the given category.
-- range : { min=number, max=number, step=number }
function addon.settings.Slider(cat, key, name, range, desc, onChange)
    local function Get() return addon.db[key] end
    local function Set(value)
        addon.db[key] = value
        if onChange then onChange(value) end
    end
    local setting = Settings.RegisterProxySetting(
        cat,
        "MysteriousQoL_" .. key,
        Settings.VarType.Number,
        name,
        addon.defaults[key],
        Get, Set
    )
    local options = Settings.CreateSliderOptions(range.min, range.max, range.step)
    Settings.CreateSlider(cat, setting, options, desc)
    return setting
end
