local core = require("openmw.core")

local l10n = core.l10n("FollowerCommands_messages")

local messages = {}

local function pickRandomMessage(follower, messageType)
    local name = follower.type.records[follower.recordId].name
    local messageOptions = {}
    local i = 1
    while true do
        local msgKey = ("%s_%d"):format(messageType, i)
        local msg = l10n(msgKey, { name = name })
        if msgKey ~= msg then
            messageOptions[#messageOptions+1] = msg
        else
            break
        end
        i = i + 1
    end
    return messageOptions[math.random(#messageOptions)]
end

messages.show = function(player, follower, messageType)
    if type(follower) == "table" then
        follower = follower[math.random(#follower)]
    end
    local msg = pickRandomMessage(follower, messageType)
    player:sendEvent("ShowMessage", { message = msg })
end

return messages
