local self = require("openmw.self")
local I = require("openmw.interfaces")
local core = require("openmw.core")
local anim = require("openmw.animation")

local destPos = "tmp"
local isTrap
local onUpdateFired = false

local function equipBestPickprobe()
    
end

local function tryPickprobing()
    
end

local function onInit(data)
    destPos = data.destPos
    isTrap = data.action == "untrap"
end

local function onUpdate(dt)
    if onUpdateFired
        or destPos == "tmp"
        or I.AI.getActiveTarget("Travel") == destPos
    then
        return
    end

    onUpdateFired = true
    self:enableAI(false)
    I.AnimationController.playBlendedAnimation(
        "pickprobe",
        {
            startKey = 'start',
            stopKey = 'stop',
            priority = anim.PRIORITY.Scripted,
        }
    )
end

I.AnimationController.addTextKeyHandler(
    "pickprobe",
    function (groupname, key)
        if key ~= "stop" then return end
        core.sendGlobalEvent("FollowerCommands_detachScript")
    end
)

return {
    engineHandlers = {
        onInit = onInit,
        onUpdate = onUpdate,
    },
}