local _, addon = ...

-- Auto-accept, auto-turn-in quests, and auto-select gossip options.
-- Hold Alt to bypass all quest automation.

local f = CreateFrame("Frame")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_ACCEPT_CONFIRM")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_GREETING")
f:RegisterEvent("GOSSIP_SHOW")

f:SetScript("OnEvent", function(_, event)
    if IsAltKeyDown() then return end

    -- ── Auto Accept ──────────────────────────────────────────────────────────
    if event == "QUEST_DETAIL" then
        if not addon.db.general_autoQuestAccept then return end
        if QuestGetAutoAccept and QuestGetAutoAccept() then
            CloseQuest()
        else
            AcceptQuest()
        end
        return
    end

    if event == "QUEST_ACCEPT_CONFIRM" then
        if not addon.db.general_autoQuestAccept then return end
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
        return
    end

    -- ── Auto Turn-In ─────────────────────────────────────────────────────────
    if event == "QUEST_PROGRESS" then
        if not addon.db.general_autoQuestTurnIn then return end
        if IsQuestCompletable() then
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

    -- ── Greeting / Gossip ────────────────────────────────────────────────────
    if event == "QUEST_GREETING" or event == "GOSSIP_SHOW" then
        -- Try turn-in first (completed quests take priority)
        if addon.db.general_autoQuestTurnIn then
            for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
                if quest.isComplete then
                    C_GossipInfo.SelectActiveQuest(quest.questID)
                    return
                end
            end
        end

        -- Then try accept (available quests)
        if addon.db.general_autoQuestAccept then
            for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
                C_GossipInfo.SelectAvailableQuest(quest.questID)
                return
            end
        end

        -- Auto gossip select (first option)
        if addon.db.general_autoGossipSelect and event == "GOSSIP_SHOW" then
            local options = C_GossipInfo.GetOptions()
            if options and #options == 1 then
                C_GossipInfo.SelectOption(options[1].gossipOptionID)
            end
        end
    end
end)
