local function event()
    local handlers = {}
    return {
        Add = function(fn) handlers[#handlers + 1] = fn end,
        Remove = function(fn)
            for i = #handlers, 1, -1 do if handlers[i] == fn then table.remove(handlers, i) end end
        end,
        fire = function(...) for _, fn in ipairs(handlers) do fn(...) end end,
    }
end
Events = { OnGameStart = event(), OnMainMenuEnter = event(), OnDisconnect = event(), OnTick = event(), OnPreUIDraw = event() }
LuaEventManager = { AddEvent = function(name) Events[name] = Events[name] or event() end }

local values = {}
PZAPI = { ModOptions = { create = function()
    local options = {}
    local function option(id, default)
        values[id] = default
        return { getValue = function() return values[id] end }
    end
    function options:addTickBox(id, _, default) return option(id, default) end
    function options:addSlider(id, _, _, _, _, default) return option(id, default) end
    return options
end } }
package.loaded["PZAPI/ModOptions"] = true
package.loaded["ExtractionMode/Config"] = true
package.loaded["ExtractionMode/Util"] = true

local now, multiplayer, active, available, ready, directional = 0, false, true, true, false, true
local models, seen, suppressed, audioPosition, groundAreas, pendingAreas = {}, {}, false, nil, {}, {}
local player = { isDead = function() return false end, getX = function() return 100 end, getY = function() return 200 end }
getSpecificPlayer = function(number) if number == 0 or number == 1 then return player end end
getTimestampMs = function() return now end
isClient = function() return multiplayer end
sendClientCommand = function() error("the visual addon must not send server commands") end
ExtractionMode = {
    Config = { HELICOPTER_ACTIVE_APPROACH_SECONDS = 30, CAMPAIGN_HELICOPTER_ACTIVE_APPROACH_SECONDS = 60 },
    Util = { timerNowMs = function() return now end },
    ClientStates = {},
}
ViewpointExtractionSupportBridge = {
    suppressNative = function(value) suppressed = value end,
    nativeAudioPosition = function(x, y, height) audioPosition = { x = x, y = y, height = height } end,
    clearNativeAudioPosition = function() audioPosition = nil end,
    beginAreas = function() pendingAreas = {} end,
    area = function(x, y, z, radius) pendingAreas[#pendingAreas + 1] = { x = x, y = y, z = z, radius = radius } end,
    endAreas = function() groundAreas = pendingAreas end,
    clearAreas = function() groundAreas, pendingAreas = {}, {} end,
}
VisibleHelicopterEvent = {
    active = function() return active end,
    modelAvailable = function() return available end,
    height = function() return 120 end,
    directional = function() return directional end,
    flightReady = function(id) return ready and models[id] ~= nil end,
    modelFlight = function(id, x, y, height, heading, model)
        seen[id], models[id] = true, { x = x, y = y, height = height, heading = heading, model = model }
    end,
    flightAlpha = function(id, alpha) models[id].alpha = alpha end,
    removeFlight = function(id) models[id] = nil end,
    beginALife = function() end, alife = function() end, weekOne = function() end,
    restoreEmitters = function() end,
    beginFlights = function() seen = {} end,
    endFlights = function()
        Events.OnViewpointExtractionFlights.fire()
        for id in pairs(models) do if not seen[id] then models[id] = nil end end
    end,
    clearFlights = function() models = {} end,
}

assert(loadstring(rendererCompatSource))()
require "ViewpointExtractionSupport"
Events.OnGameStart.fire()

local function snapshot()
    return {
        _hudRevision = 1, isParticipant = true, state = "BOARDING", raidId = 2, activeExtraction = 1,
        extractionSeconds = 0, extractionTotalSeconds = 90,
        extractionSites = { { id = 1, x = 100, y = 200, z = 0 } },
        extractionRope = { x = 100, y = 200, z = 0, radius = 3, siteId = 1 },
    }
end
local function count()
    local total = 0
    for _ in pairs(models) do total = total + 1 end
    return total
end
local function frame(ms)
    now = ms
    Events.OnTick.fire()
end

local state = snapshot()
ExtractionMode.ClientStates[0] = state
ExtractionMode.ClientState = state
frame(0)
assert(count() == 1, "flight must be submitted before the real renderer's endFlights cleanup")
assert(not suppressed, "keep the native visual while the replacement model is loading")
assert(#groundAreas == 1 and groundAreas[1].radius == 3, "show the actual boarding radius")
assert(audioPosition and audioPosition.x == 100.5 and audioPosition.y == 200.5,
    "audio must track the extraction site even before its visual is ready")
ready = true
frame(1000)
assert(suppressed, "hide duplicate native aircraft only after the exact replacement is ready")
for _, model in pairs(models) do
    assert(model.model == "UH-1BHelicopter")
    assert(audioPosition.height == model.height, "audio must use the model altitude, not native event altitude")
end
assert(state.state == "BOARDING" and state.extractionSites[1].x == 100, "must not mutate extraction state")

ExtractionMode.ClientStates[1] = state
frame(1100)
assert(count() == 1, "split-screen observers must not duplicate the same pickup")
ExtractionMode.ClientStates[1] = nil

local originalCollector = VisibleHelicopterEventCompat.weekOneFlights
VisibleHelicopterEventCompat.weekOneFlights = function()
    originalCollector()
    VisibleHelicopterEvent.modelFlight("foreign", 0, 0, 100, 0, "other")
end
values.enabled = false
frame(1200)
assert(count() == 1 and models.foreign, "disabling must remove only this addon's models")
assert(not suppressed and audioPosition == nil)
assert(#groundAreas == 1, "ground areas must remain available with the helicopter option disabled")
values.enabled = true
frame(1300)
assert(count() == 2)
ViewpointExtractionSupport.reset()
assert(count() == 1 and models.foreign)
assert(audioPosition == nil)
assert(#groundAreas == 0)
VisibleHelicopterEventCompat.weekOneFlights = originalCollector
models = {}

multiplayer = true
state = snapshot()
state.pvpveMode = true
local second = snapshot()
second.key, second.raidId = "other-team:3:1", 3
state.nearbyExtractions = { snapshot(), second }
ExtractionMode.ClientStates[0] = state
frame(2000)
frame(3000)
assert(count() == 2 and not suppressed, "independent PvPvE pickups must not suppress an unrelated native event")
assert(audioPosition == nil, "PvPvE emitters must not hijack the native helicopter's audio")
frame(8001)
assert(not suppressed)
assert(#groundAreas == 0, "stale multiplayer state must clear ground areas immediately")
frame(16001)
assert(count() == 0, "stale multiplayer snapshots must stop feeding the flights")
state._hudRevision = 2
frame(17000)
assert(count() == 2, "new authoritative snapshots must restore the visuals")

available = false
frame(18000)
assert(count() == 0 and not suppressed, "missing model must leave native rendering available")
assert(#groundAreas == 1, "ground areas do not need loaded aircraft assets")
available, active = true, false
frame(19000)
assert(count() == 0)
assert(#groundAreas == 0)
active = true
frame(19500)
assert(count() == 2)
Events.OnDisconnect.fire()
assert(count() == 0 and not suppressed and audioPosition == nil)
assert(#groundAreas == 0)

multiplayer = false
ExtractionMode.ClientStates[0] = snapshot()
Events.OnGameStart.fire()
frame(20000)
assert(audioPosition)
directional = false
frame(20100)
assert(audioPosition == nil, "respect the renderer's directional audio preference")
values.showArea = false
frame(20200)
assert(#groundAreas == 0 and count() == 1, "disabling the area must preserve the aircraft")
print("adapter_spec: installed VHE collection cycle, independent ground areas, native audio, readiness fallback, split-screen, cleanup and multiplayer snapshots passed")
