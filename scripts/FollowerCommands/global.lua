local consts = require("scripts.FollowerCommands.utils.consts")
local Item = require("openmw.types").Item

local function pausedAction(data)
    local script = consts.customScripts[data.action]
    if data.follower:hasScript(script) then return end
    data.follower:addScript(script, data)
end

local function detachScript(data)
    local script = consts.customScripts[data.action]
    if data.follower:hasScript(script) then
        data.follower:removeScript(script)
    end
end

local function onModifyPickprobeCondition(data)
    local itemData = Item.itemData(data.item)
    itemData.condition = math.min(data.item.type.record(data.item).maxCondition, math.max(0, itemData.condition + data.amount))

    -- Force unequip broken items
    if data.actor and itemData.condition <= 0 then
        data.actor:sendEvent('Unequip', {item = data.item})
        data.item:remove(1)
    end
end

local function unlock(obj)
    obj.type.unlock(obj)
end

local function untrap(obj)
    obj.type.setTrapSpell(obj)
end

return {
    eventHandlers = {
        FollowerCommands_pausedAction = pausedAction,
        FollowerCommands_detachScript = detachScript,
        FollowerCommands_modifyPickprobeCondition = onModifyPickprobeCondition,
        FollowerCommands_unlock = unlock,
        FollowerCommands_untrap = untrap,
    },
}
