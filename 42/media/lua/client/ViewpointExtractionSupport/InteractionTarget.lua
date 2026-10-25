local Target = {}

local TARGET_NAME = "ViewpointExtractionSupportExtractionTarget"
local targets, signature = {}, nil
local sprite

local function finite(value)
    local number = tonumber(value)
    if number and number == number and math.abs(number) < 10000000 then return number end
end

local function clear()
    for _, target in ipairs(targets) do
        local square = target.square
        if square then square:getObjects():remove(target.object) end
    end
    targets, signature = {}, nil
end

local function hasWorldObject(square)
    local floor = square:getFloor()
    local objects = square:getObjects()
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        if object ~= floor and object:getSprite() ~= nil then return true end
    end
    return false
end

local function add(square)
    if hasWorldObject(square) then return end
    sprite = sprite or IsoSprite.new()
    local object = IsoObject.new(square, "", TARGET_NAME)
    object:setSprite(sprite)
    if object.setAlphaAndTarget then object:setAlphaAndTarget(0) end
    square:getObjects():add(object)
    targets[#targets + 1] = { square = square, object = object }
end

function Target.sync(rope)
    if type(rope) ~= "table" then clear() return end
    local x, y, z = finite(rope.x), finite(rope.y), finite(rope.z or 0)
    local radius = finite(rope.radius or 3)
    if not x or not y or not z or z ~= math.floor(z) or not radius or radius <= 0 or radius > 16 then
        clear()
        return
    end

    local key = table.concat({ x, y, z, radius }, ":")
    if key == signature then return end
    clear()
    signature = key

    local cell = getCell()
    local minX, maxX = math.floor(x - radius), math.floor(x + radius)
    local minY, maxY = math.floor(y - radius), math.floor(y + radius)
    for tileX = minX, maxX do
        for tileY = minY, maxY do
            local dx, dy = tileX - x, tileY - y
            if dx * dx + dy * dy <= radius * radius then
                local square = cell:getGridSquare(tileX, tileY, z)
                if square and square:isOutside() then add(square) end
            end
        end
    end
end

function Target.clear()
    clear()
end

function Target.isTarget(object)
    for _, target in ipairs(targets) do
        if target.object == object then return true end
    end
    return false
end

return Target
