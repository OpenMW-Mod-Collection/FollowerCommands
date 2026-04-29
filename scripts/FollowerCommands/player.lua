local storage = require('openmw.storage')
local self = require("openmw.self")
local I = require("openmw.interfaces")
local input = require("openmw.input")
local async = require("openmw.async")
local camera = require("openmw.camera")
local types = require("openmw.types")
local nearby = require("openmw.nearby")
local anim = require("openmw.animation")
local core = require("openmw.core")

require("scripts.FollowerCommands.utils.dependencies")
local camUtil = require("scripts.FollowerCommands.utils.camera")
local consts = require("scripts.FollowerCommands.utils.consts")
local followerPicker = require("scripts.FollowerCommands.utils.followerPicker")

local settings = storage.playerSection("SettingsFollowerCommands_settings")
local settingsCommands = storage.playerSection("SettingsFollowerCommands_commands")

CheckDependency(
    self,
    "Follower Commands",
    "FollowerDetectionUtil.omwscripts",
    I.FollowerDetectionUtil,
    0,
    I.FollowerDetectionUtil and I.FollowerDetectionUtil.version or -1
)

local lastCommand
local occupiedObjects = {}
local occupiedFollowers = {}

local function playCommandAnim()
    local animKey = settings:get("animationVariant") == "kcommand_random"
        and "kcommand0" .. tostring(math.random(1, 4))
        or settings:get("animationVariant")
    I.AnimationController.playBlendedAnimation(
        animKey,
        {
            startKey = 'start',
            stopKey = 'stop',
            ---@diagnostic disable-next-line: assign-type-mismatch
            priority = {
                [anim.BONE_GROUP.LeftArm] = anim.PRIORITY.Scripted,
                [anim.BONE_GROUP.Torso] = anim.PRIORITY.Scripted,
            },
            autoDisable = true,
            blendMask = anim.BLEND_MASK.LeftArm
                + anim.BLEND_MASK.Torso
                + anim.BLEND_MASK.RightArm
                + anim.BLEND_MASK.LowerBody,
            speed = 1
        }
    )
end

local function resetAiPackages(follower)
    follower:sendEvent(
        "StartAIPackage",
        {
            type = "Follow",
            target = self,
        }
    )
end

local function commandCombat(followers, target)
    lastCommand = consts.actions.kill
    local pkg = {
        type = "Combat",
        target = target
    }
    for _, actor in ipairs(followers) do
        actor:sendEvent("StartAIPackage", pkg)
    end
end

local function commandTravel(followers, pos)
    lastCommand = consts.actions.travel
    local pkg = {
        type = "Travel",
        destPosition = nearby.findNearestNavMeshPosition(pos),
        cancelOther = false,
    }
    for _, follower in ipairs(followers) do
        resetAiPackages(follower)
        follower:sendEvent("StartAIPackage", pkg)
    end
end

local function commandLockpick(followers, obj)
    lastCommand = consts.actions.lockpick
    local selectedFollower, bestScore = followerPicker.pickprobe(followers, types.Lockpick)

    if bestScore == 0 then
        self:sendEvent("ShowMessage", { message = "Seems like no one has any lockpicks." })
        return
    end

    local unlockChance = bestScore - obj.type.getLockLevel(obj)
    if unlockChance < settingsCommands:get("minUnlockChance") then
        self:sendEvent("ShowMessage", { message = "Seems like teh lock is too complex." })
        return
    end

    occupiedObjects[obj.id] = true
    occupiedFollowers[selectedFollower.id] = true
    local destPos = nearby.findNearestNavMeshPosition(obj.position)
    self:sendEvent("ShowMessage", { message = "Sure, I'll unlock it." })
    resetAiPackages(selectedFollower)
    selectedFollower:sendEvent(
        "StartAIPackage",
        {
            type = "Travel",
            destPosition = destPos,
            cancelOther = false,
        }
    )
    core.sendGlobalEvent(
        "FollowerCommands_pausedAction",
        {
            action   = "lockpick",
            target   = obj,
            follower = selectedFollower,
            destPos  = destPos,
            player   = self,
        }
    )
end

local function commandUntrap(followers, obj)


    lastCommand = consts.actions.untrap
end

input.registerTriggerHandler(
    consts.commandTriggerKey,
    async:callback(function()
        playCommandAnim()

        -- filtering followers
        local followerList = I.FollowerDetectionUtil.getFollowerList()
        if not followerList or not next(followerList) then return end

        local myFollowers = {}
        for _, state in pairs(followerList) do
            local isMyFollower = state.leader and state.leader.id == self.id
                or state.superLeader and state.superLeader.id == self.id
            if isMyFollower and not occupiedFollowers[state.actor.id] then
                myFollowers[#myFollowers + 1] = state.actor
            end
        end
        if not next(myFollowers) then return end

        -- raycast
        local pos, v = camUtil.getCameraDirData(camera.getPosition(), false)
        local dist = settings:get("maxDistance")
        local destPos = (pos + v * dist)
        local cast = nearby.castRay(pos, destPos, { ignore = { table.unpack(myFollowers), self } })
        if not cast.hitPos then return end

        local obj = cast.hitObject
        if not obj then
            commandTravel(myFollowers, cast.hitPos)
            return
        elseif occupiedObjects[obj.id]
            or not obj:isValid()
            or obj.type.records[obj.recordId].mwscript
        then
            return
        end

        -- determining the action
        local isLockable    = types.Lockable.objectIsInstance(obj)
        local isActor       = types.Actor.objectIsInstance(obj)
        local isDead        = isActor and types.Actor.isDead(obj)

        local isOwned       = true -- tmp
        local unlockOwned   = not isOwned or settingsCommands:get("unlockOwned")
        local lootOwned     = not isOwned or settingsCommands:get("lootOwned")

        local hitAliveActor = isActor and not isDead
        local hitLocked     = isLockable and types.Lockable.isLocked(obj)
        local hitTrapped    = isLockable and types.Lockable.getTrapSpell(obj)
        local hitContainer  = types.Container.objectIsInstance(obj) or isDead
        local hitItem       = types.Item.objectIsInstance(obj)

        local isIllegal     =
            (hitTrapped or hitContainer and not unlockOwned)
            or (hitItem or hitContainer and not lootOwned)

        if hitAliveActor then
            commandCombat(myFollowers, obj)
        elseif hitLocked then
            commandLockpick(myFollowers, obj)
        elseif hitTrapped then

        elseif hitContainer then

        elseif hitItem then

        elseif isIllegal then
            self:sendEvent("ShowMessage", { message = "Sorry m8, it's illegal." })
        else
            commandTravel(myFollowers, cast.hitPos)
        end
    end)
)

return {
    eventHandlers = {
        FollowerCommands_objectFreed = function(data)
            occupiedObjects[data.target.id] = nil
            occupiedFollowers[data.follower.id] = nil
        end
    }
}

-- I.AnimationController.addTextKeyHandler(
--     "",
--     function(groupname, key)
--         print(groupname, key)
--     end
-- )
