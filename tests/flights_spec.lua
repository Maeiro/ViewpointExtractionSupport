local Flights = require "ViewpointExtractionSupport/Flights"
local settings = { approachSeconds = 30, campaignApproachSeconds = 60, cruiseHeight = 120, hoverHeight = 12 }
local function data(remaining, state)
    return {
        state = state or "EXTRACTING", isParticipant = true, raidId = 17, activeExtraction = 2,
        extractionSeconds = remaining, extractionTotalSeconds = 90,
        extractionSites = { { id = 1, x = 1, y = 1 }, { id = 2, x = 100, y = 200, z = 3 } },
    }
end
local function update(runtime, snapshot, now, extra)
    return Flights.update(runtime, { { data = snapshot, native = true, campaign = extra } }, now, settings)
end
local function near(a, b, tolerance)
    assert(math.abs(a - b) < (tolerance or 0.00001), tostring(a) .. " != " .. tostring(b))
end
local function distance(pose)
    return math.sqrt((pose.x - 100.5)^2 + (pose.y - 200.5)^2)
end

local runtime = Flights.new()
assert(#update(runtime, data(90), 0) == 0, "must wait for the authoritative final approach")
local snapshot = data(30)
local first = update(runtime, snapshot, 1000)[1]
near(distance(first), 240)
near(first.height, 3 * 2.4494896 + 120)
assert(first.alpha == 0)
local later = update(runtime, snapshot, 2000)[1]
assert(distance(later) < distance(first), "unchanged countdown samples must still animate")
snapshot.extractionSeconds = 29
local corrected = update(runtime, snapshot, 2000)[1]
near(distance(corrected), distance(later))
snapshot.extractionSeconds = 30
local oldPacket = update(runtime, snapshot, 2001)[1]
assert(distance(oldPacket) <= distance(corrected), "late countdown packets must not reverse the flight")

snapshot.state = "BOARDING"
snapshot.extractionRope = { x = 100, y = 200, z = 3, siteId = 2 }
local hover = update(runtime, snapshot, 31000)[1]
near(hover.x, 100.5)
near(hover.y, 200.5)
near(hover.height, 3 * 2.4494896 + 12, 0.151)
assert(hover.native)

local departing = Flights.update(runtime, {}, 31000, settings)[1]
near(departing.x, hover.x)
near(departing.y, hover.y)
near(departing.height, hover.height)
assert(not departing.native)
local away = Flights.update(runtime, {}, 35000, settings)[1]
assert(distance(away) > 90 and away.height > hover.height)
assert(#Flights.update(runtime, {}, 39000, settings) == 0)
assert(next(runtime.entries) == nil)

runtime = Flights.new()
snapshot = data(20)
local approaching = update(runtime, snapshot, 0)[1]
local abort = Flights.update(runtime, {}, 0, settings)[1]
near(abort.x, approaching.x)
near(abort.y, approaching.y)
assert(#update(runtime, data(30), 100) == 1, "a repeated call must replace its departure cleanly")
assert(update(runtime, data(30), 100)[1].alpha == 0)

runtime = Flights.new()
snapshot = data(0, "BOARDING")
local other = data(0, "BOARDING")
other.raidId = 18
local poses = Flights.update(runtime, { { data = snapshot }, { data = snapshot }, { data = other } }, 0, settings)
assert(#poses == 2 and poses[1].id ~= poses[2].id, "deduplicate observers, preserve separate raids")

snapshot = data(60)
assert(#update(Flights.new(), snapshot, 0) == 0)
assert(#update(Flights.new(), snapshot, 0, true) == 1, "campaign uses its own approach window")
snapshot.extractionTotalSeconds = 10
snapshot.extractionSeconds = 10
near(distance(update(Flights.new(), snapshot, 0)[1]), 240)

for _, mutate in ipairs({
    function(d) d.activeExtraction = 99 end,
    function(d) d.isParticipant = false end,
    function(d) d.state = "RAID" end,
    function(d) d.extractionSeconds = nil end,
    function(d) d.extractionSites[2].x = 0 / 0 end,
    function(d) d.extractionSites[2].y = math.huge end,
}) do
    snapshot = data(15)
    mutate(snapshot)
    assert(#update(Flights.new(), snapshot, 0) == 0, "invalid or hidden pickups must not become flights")
end

snapshot = data(0, "BOARDING")
snapshot.activeExtraction, snapshot.extractionSites = nil, {}
snapshot.extractionRope = { x = 100, y = 200, z = 3, siteId = 2, pickupId = "public-rope" }
assert(#update(Flights.new(), snapshot, 0) == 1, "a server-revealed boarding rope can anchor a hover")
print("flights_spec: approach, interpolation, boarding, altitude, departure, cancellation, identity and invalid-state checks passed")
