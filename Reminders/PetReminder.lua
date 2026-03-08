local _, addon = ...

local sin               = math.sin
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsDeadOrGhost   = UnitIsDeadOrGhost

-- Hunter specs that require a pet (Beast Mastery = 253, Survival = 255)
local HUNTER_PET_SPECS = { [253] = true, [255] = true }

-- ── Suppression helper ─────────────────────────────────────────────────────────

local function isSuppressed()
    return UnitIsDeadOrGhost("player")
        or IsMounted()
        or UnitHasVehicleUI("player")
        or UnitOnTaxi("player")
end

-- ── Pet check helpers ──────────────────────────────────────────────────────────

local function isPetExpected()
    if addon.playerClass == "WARLOCK" then return true end
    if addon.playerClass == "HUNTER" then
        local specIndex = GetSpecialization()
        local specID = specIndex and GetSpecializationInfo(specIndex)
        return HUNTER_PET_SPECS[specID] == true
    end
    return false
end

-- Returns a message string if a pet warning should show, nil otherwise.
local function getPetMessage()
    if not isPetExpected() then return nil end
    if isSuppressed() then return nil end

    local petAlive = UnitExists("pet") and not UnitIsDeadOrGhost("pet")

    if not petAlive then
        if addon.db.combat_petReminder_enabled then
            return "No Pet"
        end
    elseif addon.db.combat_petIdleReminder_enabled
        and UnitAffectingCombat("player")
        and not UnitAffectingCombat("pet")
    then
        return "Pet Idle!"
    end

    return nil
end

-- ── Pet display frame (bouncing text) ──────────────────────────────────────────

local PET_BASE_Y = 155
local PET_BOUNCE = 6
local PET_SPEED  = 2.5

local petFrame = CreateFrame("Frame", "MysteriousQoL_PetReminderFrame", UIParent)
petFrame:SetSize(400, 50)
petFrame:SetPoint("CENTER", UIParent, "CENTER", 0, PET_BASE_Y)
petFrame:SetFrameStrata("MEDIUM")
petFrame:Hide()

local petText = petFrame:CreateFontString(nil, "OVERLAY")
petText:SetAllPoints()
petText:SetJustifyH("CENTER")
petText:SetJustifyV("MIDDLE")
petText:SetFont("Fonts\\FRIZQT__.TTF", 26, "THICKOUTLINE")
petText:SetTextColor(1, 0.2, 0.2, 1)
petText:SetShadowColor(0, 0, 0, 1)
petText:SetShadowOffset(2, -2)

local bounceT = 0
petFrame:SetScript("OnUpdate", function(self, elapsed)
    bounceT = bounceT + elapsed
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, PET_BASE_Y + sin(bounceT * PET_SPEED) * PET_BOUNCE)
end)

-- ── Update ─────────────────────────────────────────────────────────────────────

function addon.MI_PetReminder_Update()
    local petMsg = getPetMessage()
    if petMsg then
        petText:SetText(petMsg)
        petFrame:Show()
    else
        bounceT = 0
        petFrame:Hide()
    end
end

-- ── Settings ───────────────────────────────────────────────────────────────────

function addon.MI_PetReminder_RegisterSettings(cat, layout)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Pet"))
    addon.settings.Checkbox(
        cat, "combat_petReminder_enabled", "No Pet Reminder",
        "Shows a center-screen warning when you have no active pet (Warlock, Hunter BM/Survival).",
        function() addon.MI_PetReminder_Update() end
    )
    addon.settings.Checkbox(
        cat, "combat_petIdleReminder_enabled", "Pet Idle Reminder",
        "Shows a center-screen warning when your pet is alive but not attacking while you are in combat.",
        function() addon.MI_PetReminder_Update() end
    )
end
