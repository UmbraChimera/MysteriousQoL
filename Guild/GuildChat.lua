local _, addon = ...

-- Chat channels where we want to show alt's main name next to messages.
local CHAT_EVENTS = {
    "CHAT_MSG_GUILD",
    "CHAT_MSG_GUILD_OFFICER",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
}

local function StripRealm(name)
    return name and name:match("^([^%-]+)") or name
end

local function ChatFilter(_, event, msg, author, ...)
    if not addon.db.guild_alts_enabled then return end
    if not addon.db.guild_chat_showMain then return end

    local main = addon.MI_Guild_GetNickForChar(StripRealm(author))
        or addon.MI_Guild_GetNickForChar(author)
    if not main then return end

    return false, "|cff888888(" .. main .. ")|r " .. msg, author, ...
end

function addon.MI_GuildChat_Init()
    for _, event in ipairs(CHAT_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, ChatFilter)
    end
end
