local function list(initial)
    local values = initial or {}
    return {
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end,
        add = function(_, value) values[#values + 1] = value end,
        remove = function(_, value)
            for index = #values, 1, -1 do
                if values[index] == value then table.remove(values, index) return true end
            end
            return false
        end,
        values = values,
    }
end

local squares = {}
local function square(x, y, objects)
    local result = { x = x, y = y, objects = list(objects) }
    function result:getFloor() return self.floor end
    function result:getObjects() return self.objects end
    function result:isOutside() return true end
    squares[x .. ":" .. y .. ":0"] = result
    return result
end

for x = -2, 2 do
    for y = -2, 2 do square(x, y) end
end
local existing = { getSprite = function() return {} end }
square(1, 0, { existing })
getCell = function()
    return { getGridSquare = function(_, x, y, z) return squares[x .. ":" .. y .. ":" .. z] end }
end
IsoSprite = { new = function() return {} end }
IsoObject = { new = function(sq)
    local object = { square = sq }
    function object:getSprite() return self.sprite end
    function object:setSprite(value) self.sprite = value end
    function object:setAlphaAndTarget(value) self.alpha = value end
    return object
end }

local Target = require "ViewpointExtractionSupport/InteractionTarget"
Target.sync({ x = 0, y = 0, z = 0, radius = 1 })
assert(#squares["0:0:0"].objects.values == 1, "create an invisible target on the center tile")
assert(#squares["1:0:0"].objects.values == 1, "do not override a real world object")
Target.sync({ x = 0, y = 0, z = 0, radius = 1 })
assert(#squares["0:0:0"].objects.values == 1, "reuse targets while the rope is unchanged")
Target.clear()
assert(#squares["0:0:0"].objects.values == 0, "remove temporary targets cleanly")
print("interaction_target_spec: temporary passable targets, real-object protection and cleanup passed")
