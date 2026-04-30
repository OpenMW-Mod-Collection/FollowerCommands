local types = require("openmw.types")
local storage = require("openmw.storage")

local settingsCommands = storage.playerSection("SettingsFollowerCommands_commands")

local picker = {}

---@class PickprobeOptions
---@field type anyType

---@param followers GameObject[]
---@param opts PickprobeOptions
---@return GameObject|nil
---@return integer
picker.pickprobe = function(followers, opts)
    local selectedFollower
    local biggestCount = 0
    local bestScore = 0
    for _, follower in ipairs(followers) do
        if not types.NPC.objectIsInstance(follower) then goto continue end

        local pickprobes = follower.type.inventory(follower):getAll(opts.type)
        if not pickprobes then goto continue end

        local bestQuality = 0
        local count = 0
        for _, pickprobe in ipairs(pickprobes) do
            local record = pickprobe.type.records[pickprobe.recordId]
            if record.quality >= bestQuality and pickprobe.count > count then
                bestQuality = record.quality
                count = pickprobe.count
            end
        end

        local security = follower.type.stats.skills.security(follower).modified
        local agility = follower.type.stats.attributes.agility(follower).modified
        local luck = follower.type.stats.attributes.luck(follower).modified
        local statModifier = security + agility / 5 + luck / 10

        local score = statModifier * bestQuality
        if score > bestScore and count > biggestCount then
            bestScore = score
            biggestCount = count
            selectedFollower = follower
        end

        ::continue::
    end
    return selectedFollower, bestScore
end

---@param followers GameObject[]
---@return GameObject|nil
picker.forceUntrap = function(followers)
    local selectedFollower
    local highestHP = settingsCommands:get("kamikazeUntrapMinHealth")
    for _, follower in ipairs(followers) do
        local health = follower.type.stats.dynamic.health(follower)
        if health.current >= highestHP then
            highestHP = health.current
            selectedFollower = follower
        end
    end
    return selectedFollower
end

picker.loot = function(followers, obj)

end

return picker
