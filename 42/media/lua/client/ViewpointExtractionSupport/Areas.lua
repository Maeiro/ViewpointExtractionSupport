local Areas = {}

local function coordinate(value)
    local number = tonumber(value)
    if number and number == number and math.abs(number) < 10000000 then return number end
end

function Areas.collect(pickups)
    local result, seen = {}, {}
    for _, pickup in ipairs(pickups) do
        local data = pickup.data
        local rope = data and data.extractionRope
        if data and data.isParticipant == true and data.state == "BOARDING" and type(rope) == "table" then
            local x, y, z = coordinate(rope.x), coordinate(rope.y), coordinate(rope.z or 0)
            local radius = coordinate(rope.radius or 3)
            if x and y and z and z == math.floor(z) and z >= -32 and z <= 255
                and radius and radius > 0 and radius <= 64 then
                local key = tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
                if not seen[key] then
                    seen[key] = true
                    result[#result + 1] = { x = x + 0.5, y = y + 0.5, z = z, radius = radius }
                end
            end
        end
    end
    return result
end

return Areas
