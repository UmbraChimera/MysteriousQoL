local addonName, addon = ...

-- Quest XP: shades the part of the experience bar your finished quests will
-- fill when you turn them in, and lists them in the bar's tooltip.

local MAX_TOOLTIP_LINES = 10
local PILL = "Interface\\AddOns\\" .. addonName .. "\\Assets\\UI\\Pill"
local COLOR = { 1, 0.82, 0.25, 0.45 }

-- cap: rounded end used when the shade reaches the bar's rounded right end.
local marker, cap, hookedHolder, tooltipHooked
local pendingUpdate = false
local queueUpdate

-- Total XP of every finished quest in the log. Fills list with { title, xp }.
local function finishedQuestXP(list)
    local total, count = 0, 0
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and C_QuestLog.IsComplete(info.questID) then
            local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(info.questID) or 0
            if xp and xp > 0 then
                total = total + xp
                count = count + 1
                if list then list[#list + 1] = { info.title or "?", xp } end
            end
        end
    end
    return total, count
end

-- The experience bar is one of the status tracking bars; it is the one with
-- the rested (exhaustion) tick.
local function findXPBar()
    if MainMenuExpBar then return MainMenuExpBar, MainMenuExpBar end
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
                            "StatusTrackingBarManager" }) do
        local container = _G[name]
        if container and container.GetChildren then
            for _, child in ipairs({ container:GetChildren() }) do
                if child.ExhaustionTick or child.ExhaustionLevelFillBar then
                    local bar = child.StatusBar or child
                    if bar.GetMinMaxValues then return bar, child end
                end
            end
        end
    end
end

local function atMaxLevel()
    if IsPlayerAtEffectiveMaxLevel then return IsPlayerAtEffectiveMaxLevel() end
    return (UnitXPMax("player") or 0) <= 0
end

local function fmt(n)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

local function addTooltipLines()
    if not addon.db.ui_questXP_enabled or atMaxLevel() then return end
    if not GameTooltip:IsShown() or GameTooltip.mqolQuestXP then return end
    local quests = {}
    local total, count = finishedQuestXP(quests)
    if count == 0 then return end
    GameTooltip.mqolQuestXP = true

    local cur, max = UnitXP("player"), UnitXPMax("player")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format("Finished quests: %d", count), 1, 0.82, 0.25)
    local pct = max > 0 and string.format(" (%d%%)", math.floor(total / max * 100 + 0.5)) or ""
    GameTooltip:AddLine("Turn in for +" .. fmt(total) .. " XP" .. pct, 1, 1, 1)
    if cur + total >= max then
        GameTooltip:AddLine("That is enough to level up.", 0.2, 1, 0.2)
    end
    table.sort(quests, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(MAX_TOOLTIP_LINES, #quests) do
        GameTooltip:AddDoubleLine("  " .. quests[i][1], fmt(quests[i][2]),
            0.85, 0.85, 0.85, 0.85, 0.85, 0.85)
    end
    GameTooltip:Show()
end

local function hookTooltip(holder, bar)
    if not tooltipHooked then
        tooltipHooked = true
        GameTooltip:HookScript("OnHide", function(tip) tip.mqolQuestXP = nil end)
    end
    if hookedHolder == holder then return end
    hookedHolder = holder
    -- Only frames that already show a tooltip. Giving another frame an OnEnter
    -- would let it take the mouse from the bar.
    for _, frame in ipairs({ holder, bar }) do
        if frame and frame.GetScript and frame:GetScript("OnEnter") then
            frame:HookScript("OnEnter", function() C_Timer.After(0, addTooltipLines) end)
            break
        end
    end
end

local function update()
    pendingUpdate = false
    if not addon.db.ui_questXP_enabled or atMaxLevel() then
        if marker then marker:Hide() end
        if cap then cap:Hide() end
        return
    end
    local bar, holder = findXPBar()
    if not bar then return end
    hookTooltip(holder, bar)

    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not marker or marker:GetParent() ~= bar then
        if marker then marker:Hide() end
        if cap then cap:Hide() end
        marker = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        marker:SetColorTexture(unpack(COLOR))
        -- The right half of the pill shape: a half-circle end.
        cap = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        cap:SetTexture(PILL)
        cap:SetTexCoord(0.5, 1, 0, 1)
        cap:SetVertexColor(unpack(COLOR))
        if fill then
            -- Draw just above the fill, under the bar's frame art, and clip
            -- with the fill's own masks so it keeps inside the rounded ends.
            local layer, sublevel = fill:GetDrawLayer()
            for _, tex in ipairs({ marker, cap }) do
                tex:SetDrawLayer(layer, math.min(7, (sublevel or 0) + 1))
                if fill.GetNumMaskTextures then
                    for i = 1, fill:GetNumMaskTextures() do
                        local mask = fill:GetMaskTexture(i)
                        if mask then tex:AddMaskTexture(mask) end
                    end
                end
            end
        end
        -- Edit Mode can resize the bar.
        bar:HookScript("OnSizeChanged", queueUpdate)
    end

    local total = finishedQuestXP()
    local cur, max = UnitXP("player"), UnitXPMax("player")
    local width = bar:GetWidth() or 0
    if total <= 0 or max <= 0 or width <= 0 then
        marker:Hide()
        cap:Hide()
        return
    end
    local x1 = width * math.min(1, cur / max)
    local x2 = width * math.min(1, (cur + total) / max)
    -- Same height as the fill, which can sit inside the bar frame.
    local top, bottom = 0, 0
    if fill and fill:GetTop() and bar:GetTop() then
        top = fill:GetTop() - bar:GetTop()
        bottom = fill:GetBottom() - bar:GetBottom()
    end
    local height = (bar:GetHeight() or 0) + bottom - top

    -- Near the bar's right end, finish with a rounded cap so the square
    -- corners do not poke past the bar's rounded end.
    local capWidth = height / 2
    local useCap = capWidth > 0 and x2 > width - capWidth and x2 - x1 > capWidth
    local bodyEnd = useCap and (width - capWidth) or x2

    marker:ClearAllPoints()
    marker:SetPoint("TOPLEFT", bar, "TOPLEFT", x1, top)
    marker:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x1, bottom)
    marker:SetWidth(math.max(1, bodyEnd - x1))
    marker:Show()

    if useCap then
        cap:ClearAllPoints()
        cap:SetPoint("TOPLEFT", marker, "TOPRIGHT", 0, 0)
        cap:SetPoint("BOTTOMLEFT", marker, "BOTTOMRIGHT", 0, 0)
        cap:SetWidth(capWidth)
        cap:Show()
    else
        cap:Hide()
    end
end

-- QUEST_LOG_UPDATE fires in bursts.
queueUpdate = function()
    if pendingUpdate then return end
    pendingUpdate = true
    C_Timer.After(0.3, update)
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", queueUpdate)

function addon.MI_QuestXP_SetEnabled()
    if addon.db.ui_questXP_enabled then
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterEvent("QUEST_LOG_UPDATE")
        f:RegisterEvent("PLAYER_XP_UPDATE")
        f:RegisterEvent("PLAYER_LEVEL_UP")
        f:RegisterEvent("UPDATE_EXHAUSTION")
        f:RegisterEvent("DISPLAY_SIZE_CHANGED")
        f:RegisterEvent("UI_SCALE_CHANGED")
        queueUpdate()
    else
        f:UnregisterAllEvents()
        if marker then marker:Hide() end
        if cap then cap:Hide() end
    end
end
