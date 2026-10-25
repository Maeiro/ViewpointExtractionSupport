local Areas = require "ViewpointExtractionSupport/Areas"
local function boarding(x, z, radius)
    return { data = {
        isParticipant = true, state = "BOARDING",
        extractionRope = { x = x or 100, y = 200, z = z or 0, radius = radius },
    } }
end

local pickup = boarding(100, 2, 4)
local areas = Areas.collect({ pickup, pickup, boarding(110, 0, 3), boarding(100, 3, 4) })
assert(#areas == 3, "deduplicate the same rope, keep other points and floors distinct")
assert(areas[1].x == 100.5 and areas[1].y == 200.5 and areas[1].z == 2 and areas[1].radius == 4)
assert(pickup.data.extractionRope.x == 100, "never change the server's rope coordinates")
assert(Areas.collect({ boarding() })[1].radius == 3)

for _, mutate in ipairs({
    function(p) p.data.isParticipant = false end,
    function(p) p.data.state = "EXTRACTING" end,
    function(p) p.data.extractionRope = nil end,
    function(p) p.data.extractionRope.x = math.huge end,
    function(p) p.data.extractionRope.y = 0 / 0 end,
    function(p) p.data.extractionRope.z = 0.5 end,
    function(p) p.data.extractionRope.radius = -1 end,
    function(p) p.data.extractionRope.radius = 65 end,
}) do
    local invalid = boarding()
    mutate(invalid)
    assert(#Areas.collect({ invalid }) == 0, "only render valid public boarding ropes")
end
assert(#Areas.collect({}) == 0)
print("areas_spec: boarding visibility, exact radius, floor identity, tile centering and invalid states passed")
