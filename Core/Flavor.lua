local _, addon = ...

-- Client flavor detection. Loaded before every other file so modules and the
-- settings UI can gate themselves.
--
-- WoW: Forever (internal codename "Camelot") runs the Mainline API set but
-- reports interface 16001, so the common retail test `tocversion >= 100000`
-- reports false there and drops addons into Classic code paths. Neither does
-- WOW_PROJECT_ID help -Forever reports WOW_PROJECT_MAINLINE just like retail.
-- Match the 16xxx range explicitly instead.

local FOREVER_MIN = 16000
local FOREVER_MAX = 20000

local _, _, _, tocversion = GetBuildInfo()

addon.FOREVER = tocversion >= FOREVER_MIN and tocversion < FOREVER_MAX
addon.RETAIL  = not addon.FOREVER

addon.FLAVOR = addon.FOREVER and "Forever" or "Retail"
