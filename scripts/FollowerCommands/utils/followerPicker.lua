local types = require("openmw.types")

local picker = {}

picker.pickprobe = function(followers, type)
    local selectedFollower
    local biggestCount = 0
    local bestScore = 0
    for _, actor in ipairs(followers) do
        if not types.NPC.objectIsInstance(actor) then goto continue end

        local pickprobes = actor.type.inventory(actor):getAll(type)
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

        local security = actor.type.stats.skills.security(actor).modified
        local agility = actor.type.stats.attributes.agility(actor).modified
        local luck = actor.type.stats.attributes.luck(actor).modified
        local statModifier = security + agility / 5 + luck / 10

        local score = statModifier * bestQuality
        if score > bestScore and count > biggestCount then
            bestScore = score
            biggestCount = count
            selectedFollower = actor
        end

        ::continue::
    end
    return selectedFollower, bestScore
end

picker.loot = function(followers, obj)
    
end

return picker
