local self = require("openmw.self")
local I = require("openmw.interfaces")
local core = require("openmw.core")
local anim = require("openmw.animation")
local types = require("openmw.types")

local isUntrapping
---@type GameObject
local target
local action
local player

local onUpdateFired = false
local success = false
local failure = false
local bestPickprobeQuality = 0

local inv = self.type.inventory(self)
local security = self.type.stats.skills.security(self)
local agility = self.type.stats.attributes.agility(self)
local luck = self.type.stats.attributes.luck(self)

local function pickBestPickprobe()
    local toolType = isUntrapping and types.Probe or types.Lockpick
    local pickprobes = inv:getAll(toolType)
    local worstCondition
    local bestPickprobe

    for _, pickprobe in ipairs(pickprobes) do
        local record = pickprobe.type.records[pickprobe.recordId]
        local itemData = pickprobe.type.itemData(pickprobe)

        local best = record.quality > bestPickprobeQuality
        local sameButWorn = record.quality == bestPickprobeQuality
            and (not worstCondition or itemData.condition < worstCondition)
        if best or sameButWorn then
            bestPickprobeQuality = record.quality
            worstCondition = itemData.condition
            bestPickprobe = pickprobe
        end
    end

    return bestPickprobe
end

local function tryPickprobing()
    I.AnimationController.playBlendedAnimation(
        "pickprobe",
        {
            startKey = 'start',
            stopKey = 'stop',
            priority = anim.PRIORITY.Scripted,
        }
    )

    local pickprobe = pickBestPickprobe()
    if not pickprobe then
        failure = true
        return
    end
    
    local record = pickprobe.type.records[pickprobe.recordId]
    local quality = record.quality
    local statMod = security.modified
        + agility.modified / 5
        + luck.modified / 10
    local lockLevel = target.type.getLockLevel(target)
    local chance = quality * statMod - lockLevel
    success = chance >= 100 or chance >= math.random(0, 100)

    core.sendGlobalEvent(
        'FollowerCommands_modifyPickprobeCondition',
        { actor = self, item = pickprobe, amount = -1 }
    )

    if success then
        if isUntrapping then
            core.sendGlobalEvent("FollowerCommands_untrap", target)
        else
            core.sendGlobalEvent("FollowerCommands_unlock", target)
        end
    end
end

local function onInit(data)
    action = data.action
    isUntrapping = data.action == "untrap"
    target = data.target
    player = data.player
end

local function onUpdate(dt)
    if onUpdateFired or I.AI.getActivePackage().type ~= "Follow" then
        return
    end

    onUpdateFired = true
    self:enableAI(false)
    tryPickprobing()
end

local function freeSelf()
    print("freee")
    self:enableAI(true)
    core.sendGlobalEvent(
        "FollowerCommands_detachScript",
        { follower = self, action = action }
    )
    player:sendEvent(
        "FollowerCommands_objectFreed",
        { target = target, follower = self, action = action }
    )
end

I.AnimationController.addTextKeyHandler(
    "pickprobe",
    function(groupname, key)
        if key ~= "stop" then return end
        if success then
            freeSelf()
            player:sendEvent("ShowMessage", { message = "Unlocked!" })
        elseif failure then
            freeSelf()
            player:sendEvent("ShowMessage", { message = "Sorry, couldn't unlock it." })
        else
            tryPickprobing()
        end
    end
)

local function onLoad(data)
    if not data then return end
    isUntrapping = data.isTrap or isUntrapping
    target = data.target or target
    action = data.action or action
    player = data.player or player
end

local function onSave()
    return {
        isTrap = isUntrapping,
        target = target,
        action = action,
        player = player,
    }
end

return {
    engineHandlers = {
        onInit = onInit,
        onUpdate = onUpdate,
        onLoad = onLoad,
        onSave = onSave,
    },
}
