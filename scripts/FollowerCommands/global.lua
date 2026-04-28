local customScripts = {
    lockpick = "scripts/FollowerCommands/customScripts/pickprobe.lua",
    untrap = "scripts/FollowerCommands/customScripts/pickprobe.lua",
    lootContainer = "scripts/FollowerCommands/customScripts/loot.lua",
    lootItem = "scripts/FollowerCommands/customScripts/loot.lua",
}

local function pausedAction(data)
    local script = customScripts[data.action]
    if data.follower:hasScript(script) then return end
    data.follower:addScript(script, data)
end

return {
    eventHandlers = {
        FollowerCommands_pausedAction = pausedAction,
    },
}