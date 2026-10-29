local Flights = {}

local STOREY_METRES = 2.4494896
local APPROACH_DISTANCE = 240
local DEPARTURE_DISTANCE = 400
local DEPARTURE_MS = 8000
local ROPE_DEPLOY_START = 0.92
local ROPE_RETRACT_TIME = 0.18

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function smooth(value)
    local t = clamp(value, 0, 1)
    return t * t * (3 - 2 * t)
end

local function finite(value)
    local number = tonumber(value)
    if number and number == number and math.abs(number) < 10000000 then return number end
end

local function pickupInfo(pickup, settings)
    local data = pickup.data
    if type(data) ~= "table" or data.isParticipant ~= true then return nil end
    if data.state ~= "EXTRACTING" and data.state ~= "BOARDING" then return nil end

    local site
    for _, candidate in ipairs(data.extractionSites or {}) do
        if data.activeExtraction ~= nil and tostring(candidate.id) == tostring(data.activeExtraction) then
            site = candidate
            break
        end
    end
    if data.state == "BOARDING" and type(data.extractionRope) == "table" then
        site = data.extractionRope
    end
    if type(site) ~= "table" then return nil end
    local x, y, z = finite(site.x), finite(site.y), finite(site.z or 0)
    if not x or not y or not z then return nil end

    local remaining = finite(data.extractionSeconds)
    if data.state == "EXTRACTING" and (not remaining or remaining < 0) then return nil end
    local window = pickup.campaign and settings.campaignApproachSeconds or settings.approachSeconds
    window = math.max(5, math.min(finite(data.extractionTotalSeconds) or window, window))
    if data.state == "EXTRACTING" and remaining > window then return nil end

    local siteId = data.activeExtraction or site.siteId or site.id or site.pickupId or "rope"
    local key = data.key or (tostring(data.raidId or 0) .. ":" .. tostring(siteId)
        .. ":" .. tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z))
    local id = "extraction:" .. tostring(key)
    if #id > 180 then return nil end
    local angle = ((tonumber(data.raidId) or 0) * 79
        + (tonumber(siteId) or x + y) * 131) % 360 * math.pi / 180
    return {
        id = id, x = x + 0.5, y = y + 0.5, ground = z * STOREY_METRES,
        angle = angle, remaining = remaining or 0, window = window,
        boarding = data.state == "BOARDING", native = pickup.native == true,
    }
end

local function activePose(entry, info, now, settings)
    if entry.remaining ~= info.remaining then
        entry.remaining, entry.observedAt = info.remaining, now
    end
    local remaining = math.max(0, entry.remaining - math.max(0, now - entry.observedAt) / 1000)
    local progress = info.boarding and 1 or clamp(1 - remaining / info.window, 0, 1)
    entry.progress = math.max(entry.progress, progress)
    local t = entry.progress
    local distance = APPROACH_DISTANCE * (1 - t) * (1 - t)
    local hover = info.ground + settings.hoverHeight
    local cruise = info.ground + math.max(settings.cruiseHeight, settings.hoverHeight + 12)
    local bob = math.sin(now / 850) * 0.15 * smooth((t - 0.8) / 0.2)
    local ropeProgress = info.boarding and 1 or smooth((t - ROPE_DEPLOY_START) / (1 - ROPE_DEPLOY_START))
    return {
        id = info.id,
        x = info.x - math.cos(info.angle) * distance,
        y = info.y - math.sin(info.angle) * distance,
        height = cruise + (hover - cruise) * smooth(t) + bob,
        ropeX = info.x,
        ropeY = info.y,
        groundHeight = info.ground,
        ropeProgress = ropeProgress,
        heading = info.angle,
        alpha = clamp((now - entry.firstSeen) / 700, 0, 1),
        native = info.native,
    }
end

local function departurePose(entry, now, settings)
    local t = clamp((now - entry.departedAt) / DEPARTURE_MS, 0, 1)
    if t >= 1 then return nil end
    local from = entry.departureFrom
    local distance = DEPARTURE_DISTANCE * t * t
    return {
        id = from.id,
        x = from.x + math.cos(from.heading) * distance,
        y = from.y + math.sin(from.heading) * distance,
        height = from.height + math.max(30, settings.cruiseHeight - settings.hoverHeight) * smooth(t),
        ropeX = from.ropeX,
        ropeY = from.ropeY,
        groundHeight = from.groundHeight,
        ropeProgress = from.ropeProgress * (1 - smooth(t / ROPE_RETRACT_TIME)),
        heading = from.heading,
        alpha = from.alpha * (1 - smooth((t - 0.75) / 0.25)),
        native = false,
    }
end

function Flights.new()
    return { entries = {} }
end

function Flights.update(runtime, pickups, now, settings)
    local seen, poses = {}, {}
    for _, pickup in ipairs(pickups) do
        local info = pickupInfo(pickup, settings)
        if info and not seen[info.id] then
            seen[info.id] = true
            local entry = runtime.entries[info.id]
            if not entry or entry.departedAt then
                entry = { firstSeen = now, observedAt = now, progress = 0 }
                runtime.entries[info.id] = entry
            end
            entry.pose = activePose(entry, info, now, settings)
            poses[#poses + 1] = entry.pose
        end
    end
    for id, entry in pairs(runtime.entries) do
        if not seen[id] then
            if not entry.departedAt then
                entry.departedAt, entry.departureFrom = now, entry.pose
            end
            local pose = departurePose(entry, now, settings)
            if pose then poses[#poses + 1] = pose else runtime.entries[id] = nil end
        end
    end
    return poses
end

return Flights
