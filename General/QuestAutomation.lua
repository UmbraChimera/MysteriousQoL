local _, addon = ...

-- Auto-accept, auto-turn-in quests, auto-select gossip options and skip the
-- flight master's chat. Hold Alt to bypass all of it.

local f = CreateFrame("Frame")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_ACCEPT_CONFIRM")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_GREETING")
f:RegisterEvent("GOSSIP_SHOW")

local PREFIX = "|cff00ccff[MysteriousQoL]|r "

-- Options that open a Blizzard window (bank, vendor, trainer and so on) are left
-- to the game. It already picks these itself when they are the only option, and
-- picking them from addon code opens the window tainted, which then gets
-- protected actions blocked ("blocked from an action only available to the
-- Blizzard UI"), e.g. when opening the bank.
local BANKER_ICON = 132050 -- Interface\GossipFrame\BankerGossipIcon
local TAXI_ICON   = 132057 -- Interface\GossipFrame\TaxiGossipIcon

-- Battleground marks. Quests that take them are left for you to turn in, since
-- the marks are worth more spent elsewhere.
local BG_MARKS = {
    [20558] = true, -- Warsong Gulch Mark of Honor
    [20559] = true, -- Arathi Basin Mark of Honor
    [20560] = true, -- Alterac Valley Mark of Honor
}

local function isServiceOption(option)
    return option.selectOptionWhenOnlyOption or option.icon == BANKER_ICON
end

local function skipTrivial()
    return addon.db.general_autoQuest_skipTrivial
end

local function isTrivial(questID)
    if not questID or questID == 0 then return false end
    return C_QuestLog.IsQuestTrivial and C_QuestLog.IsQuestTrivial(questID) or false
end

local function takesMarks()
    for i = 1, GetNumQuestItems() or 0 do
        local link = GetQuestItemLink("required", i)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id and BG_MARKS[id] then return true end
    end
    return false
end

-- Gossip window (C_GossipInfo). Turn-ins first, then new quests.
local function handleGossipQuests()
    if addon.db.general_autoQuestTurnIn then
        for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
            if quest.isComplete then
                C_GossipInfo.SelectActiveQuest(quest.questID)
                return true
            end
        end
    end
    if addon.db.general_autoQuestAccept then
        for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
            if not (skipTrivial() and quest.isTrivial) then
                C_GossipInfo.SelectAvailableQuest(quest.questID)
                return true
            end
        end
    end
    return false
end

-- The older quest greeting panel uses its own API. C_GossipInfo returns nothing
-- here, so these NPCs need the legacy calls.
local function handleGreetingQuests()
    if addon.db.general_autoQuestTurnIn then
        for i = 1, GetNumActiveQuests() or 0 do
            local _, isComplete = GetActiveTitle(i)
            if isComplete then
                SelectActiveQuest(i)
                return
            end
        end
    end
    if addon.db.general_autoQuestAccept then
        for i = 1, GetNumAvailableQuests() or 0 do
            local trivial = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
            if not (skipTrivial() and trivial) then
                SelectAvailableQuest(i)
                return
            end
        end
    end
end

-- A flight master with nothing else to do for you goes straight to the map.
-- Not when it has quests to give or take.
local function taxiOption()
    if #C_GossipInfo.GetAvailableQuests() > 0 then return nil end
    if #C_GossipInfo.GetActiveQuests() > 0 then return nil end
    local options = C_GossipInfo.GetOptions() or {}
    for _, option in ipairs(options) do
        if option.icon == TAXI_ICON then
            -- The game opens the map itself when this is the only option.
            if #options == 1 and option.selectOptionWhenOnlyOption then return nil end
            return option
        end
    end
end

f:SetScript("OnEvent", function(_, event)
    if IsAltKeyDown() then return end

    if event == "QUEST_DETAIL" then
        if not addon.db.general_autoQuestAccept then return end
        if QuestGetAutoAccept and QuestGetAutoAccept() then
            CloseQuest()
            return
        end
        if skipTrivial() and isTrivial(GetQuestID()) then return end
        AcceptQuest()
        return
    end

    if event == "QUEST_ACCEPT_CONFIRM" then
        if not addon.db.general_autoQuestAccept then return end
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
        return
    end

    if event == "QUEST_PROGRESS" then
        if not addon.db.general_autoQuestTurnIn then return end
        if IsQuestCompletable() then
            if takesMarks() then
                print(PREFIX .. "Not turned in automatically: this quest takes battleground marks.")
                return
            end
            CompleteQuest()
        end
        return
    end

    if event == "QUEST_COMPLETE" then
        if not addon.db.general_autoQuestTurnIn then return end
        local numChoices = GetNumQuestChoices()
        if numChoices <= 1 then
            GetQuestReward(numChoices)
        end
        return
    end

    if event == "QUEST_GREETING" then
        handleGreetingQuests()
        return
    end

    if event == "GOSSIP_SHOW" then
        if addon.db.general_autoFlightMap then
            local option = taxiOption()
            if option then
                C_GossipInfo.SelectOption(option.gossipOptionID)
                return
            end
        end

        if handleGossipQuests() then return end

        -- Auto gossip select (only option)
        if addon.db.general_autoGossipSelect then
            local options = C_GossipInfo.GetOptions()
            if options and #options == 1 and not isServiceOption(options[1]) then
                C_GossipInfo.SelectOption(options[1].gossipOptionID)
            end
        end
    end
end)
