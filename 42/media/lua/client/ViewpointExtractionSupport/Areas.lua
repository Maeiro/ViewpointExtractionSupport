local Areas = {}

local function coordinate(value)
    local number = tonumber(value)
    if number and number == number and math.abs(number) < 10000000 then return number end
end

function Areas.collect(pickups)
    local result, byKey = {}, {}

    local function add(source, priority, defaultRadius)
        if type(source) ~= "table" then return end
        local x, y, z = coordinate(source.x), coordinate(source.y), coordinate(source.z or 0)
        local radius = coordinate(source.radius or defaultRadius)
        if not x or not y or not z or z ~= math.floor(z) or z < -32 or z > 255
            or not radius or radius <= 0 or radius > 64 then return end

        local key = tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
        local existing = byKey[key]
        if existing and existing.priority >= priority then return end
        local wasExisting = existing ~= nil

        local area = existing and existing.area or {
            x = x + 0.5, y = y + 0.5, z = z,
        }
        area.radius, existing = radius, { area = area, priority = priority }
        byKey[key] = existing
        if not wasExisting then
            result[#result + 1] = area
        end
    end

    for _, pickup in ipairs(pickups) do
        local data = pickup.data
        if data and data.isParticipant == true then
            if pickup.native == true then
                for _, site in ipairs(data.extractionSites or {}) do
                    add(site, 1, 12)
                end
            end

            local rope = data.state == "BOARDING" and data.extractionRope
            if type(rope) == "table" then
                add(rope, 2, 3)
            end
        end
    end

    return result
end

return Areas
