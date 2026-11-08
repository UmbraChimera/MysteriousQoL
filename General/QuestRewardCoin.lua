local _, addon = ...

-- Puts a gold coin on the quest reward choice that sells for the most, in the
-- quest giver window and the quest log. Only when there are two or more choices.

local COIN = "Interface\\MoneyFrame\\UI-GoldIcon"

local function rewardButtons()
    local list = {}
    for _, holder in ipairs({ QuestInfoRewardsFrame, MapQuestInfoRewardsFrame }) do
        if holder and holder.RewardButtons then
            for _, button in ipairs(holder.RewardButtons) do
                list[#list + 1] = button
            end
        end
    end
    return list
end

-- Sell value of a choice, or nil plus true when the item is not cached yet.
local function choiceValue(index, fromLog)
    local link, count
    if fromLog then
        link = GetQuestLogItemLink("choice", index)
        count = select(3, GetQuestLogChoiceInfo(index))
    else
        link = GetQuestItemLink("choice", index)
        count = select(3, GetQuestItemInfo("choice", index))
    end
    if not link then return nil, true end
    local price = select(11, C_Item.GetItemInfo(link))
    if price == nil then return nil, true end
    return (tonumber(price) or 0) * math.max(1, tonumber(count) or 1)
end

local retried = false

local function markCoins()
    local enabled = addon.db and addon.db.ui_questRewardCoin_enabled
    local fromLog = QuestInfoFrame and QuestInfoFrame.questLog
    local choices, best, missing = {}, 0, false

    for _, button in ipairs(rewardButtons()) do
        if enabled and button:IsShown() and button.type == "choice" then
            local value, wait = choiceValue(button:GetID(), fromLog)
            if wait then missing = true end
            if value then
                choices[#choices + 1] = { button = button, value = value }
                if value > best then best = value end
            end
        end
        if button.mqolCoin then button.mqolCoin:Hide() end
    end

    if #choices >= 2 and best > 0 then
        for _, choice in ipairs(choices) do
            if choice.value == best then
                local button = choice.button
                local coin = button.mqolCoin
                if not coin then
                    coin = button:CreateTexture(nil, "OVERLAY", nil, 7)
                    coin:SetSize(14, 14)
                    coin:SetTexture(COIN)
                    button.mqolCoin = coin
                end
                local icon = button.Icon or button
                coin:ClearAllPoints()
                coin:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -1)
                coin:Show()
            end
        end
    end

    -- Item data that was not loaded yet: try once more a moment later.
    if missing and not retried then
        retried = true
        C_Timer.After(0.5, markCoins)
    else
        retried = false
    end
end

if QuestInfo_Display then
    hooksecurefunc("QuestInfo_Display", function()
        -- Run after the game has laid out the reward buttons.
        C_Timer.After(0, markCoins)
    end)
end

function addon.MI_QuestRewardCoin_Refresh()
    markCoins()
end
