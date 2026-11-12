local clock, world, client, policy = 0, "world1", false, true
local symbols, files = {}, {}
local player
local function newPlayer()
    local data = {}
    return {getPlayerNum = function() return 0 end, getUsername = function() return "user" end,
        getModData = function() return data end, isDead = function(self) return self.dead end,
        getX = function(self) return self.x or 12.25 end, getY = function(self) return self.y or 34.5 end, getZ = function() return -1 end}
end
player = newPlayer()
getSpecificPlayer = function(n) return n == 0 and player end
getNumActivePlayers = function() return 1 end
isClient = function() return client end
getServerIP = function() return "127.0.0.1" end
getWorld = function() return {getWorld = function() return world end} end
getTimestampMs = function() return clock end
getText = function(key, value) return key .. tostring(value or "") end
MapSymbolDefinitions = {getInstance = function() return {getSymbolById = function(_, id) return id ~= "Bad" end} end}
getFileWriter = function(path)
    files[path] = ""
    return {write = function(_, text) files[path] = files[path] .. text end, close = function() end}
end
getFileReader = function(path)
    if not files[path] then return end
    local lines = files[path]:gmatch("([^\n]+)\n")
    return {readLine = function() return lines() end, close = function() end}
end
ViewpointCompassMap = {
    getCollection = function() return symbols end,
    getCount = function(c) return #c end,
    getSymbol = function(c, i) return c[i + 1] end,
    getNumber = function(s, key) return s[key] end,
    getContent = function(s) return s.content end,
    getStyle = function(s) return s.style end,
    isText = function() return false end,
    getGeneration = function(_, s) return s end,
}
ViewpointExtractionSupportBridge = {
    compassSave = function() end,
    compassIndex = function(c, symbol)
        for i, current in ipairs(c) do if current == symbol then return i - 1 end end
        return -1
    end,
    compassCreate = function(c, icon, x, y, r, g, b, a)
        local s = {content = icon, x = x, y = y, r = r, g = g, b = b, a = a,
            scale = 0.65, rotation = 0, anchorX = 0.5, anchorY = 0.5, minZoom = 0, maxZoom = 100, style = ":false:false"}
        c[#c + 1] = s
        return s
    end,
    compassRemove = function(c, symbol)
        for i, current in ipairs(c) do if current == symbol then table.remove(c, i); return end end
    end,
}
assert(loadstring(compassMarkersSource))()
ViewpointCompassServerPolicy = {getBoolean = function() return policy end}
ExtractionMode = {Config = {STATE_RAID = "RAID", STATE_EXTRACTING = "EXTRACTING", STATE_BOARDING = "BOARDING"},
    ClientState = {state = "HIDEOUT", isParticipant = true}}
local function event()
    local handlers = {}
    return {Add = function(fn) handlers[#handlers + 1] = fn end,
        fire = function(...) for _, fn in ipairs(handlers) do fn(...) end end}
end
Events = {OnTick = event(), OnPlayerDeath = event(), OnMainMenuEnter = event(), OnDisconnect = event(), OnServerCommand = event()}
local function option(value) return {getValue = function(self) return self.value end, value = value} end
local options = {extraction = option(true), death = option(true), raidDeathsOnly = option(false),
    extractionIcon = option("Z"), deathIcon = option("FaceDead"),
    extractionColor = option({r = 1, g = 0, b = 0, a = 1}), deathColor = option({r = 1, g = 0, b = 0, a = 1})}
local Compass = require "ViewpointExtractionSupport/Compass"
Compass.install(options)
local function tick() clock = clock + 1100; Compass.tick() end
local function state(value, sites) ExtractionMode.ClientState = {state = value, isParticipant = true, extractionSites = sites} end
tick()
assert(#symbols == 0)
state("RAID", {{id = 1, x = 100, y = 200}, {id = 2, x = 300, y = 400}})
tick(); tick()
assert(#symbols == 2, "raid entry creates each site once")
local count = #ViewpointCompassMarkers.refresh(player, true).markers
assert(count == 2, "annotations must also be Compass waypoints")
state("RAID", {{id = 3, x = 500, y = 600}})
tick()
assert(#symbols == 1 and symbols[1].x == 500, "raid changes remove old sites")
options.extractionColor.value.r = 0.3
tick(); tick()
assert(#symbols == 1 and symbols[1].r == 0.3, "appearance changes must not duplicate waypoints")
player.dead = true
Compass.death(player); Compass.death(player)
assert(#symbols == 1 and symbols[1].content == "FaceDead", "death removes extractions and is recorded once")
assert(symbols[1].x == 12.25 and symbols[1].y == 34.5, "death coordinates remain exact")
player = newPlayer()
state("HIDEOUT")
tick()
local markers = ViewpointCompassMarkers.refresh(player, true).markers
assert(#symbols == 1 and #markers == 1, "death waypoint survives a new character")
Events.OnMainMenuEnter.fire()
player = newPlayer()
tick()
markers = ViewpointCompassMarkers.refresh(player, true).markers
assert(#symbols == 1 and #markers == 1, "death history must reload from disk without duplicate annotations")
policy = false
player = newPlayer()
tick(); tick()
policy = true
tick()
markers = ViewpointCompassMarkers.refresh(player, true).markers
assert(#markers == 1, "server policy must not erase permanent death history")
ViewpointCompassMarkers.remove(player, markers[1])
Events.OnMainMenuEnter.fire()
player = newPlayer()
tick()
assert(#ViewpointCompassMarkers.refresh(player, true).markers == 0, "manual removal must not be resurrected")
state("RAID", {{id = 4, x = 50, y = 60}})
policy = false
tick()
assert(#symbols == 1, "server waypoint restriction must be respected")
policy = true
tick()
assert(#symbols == 2)
Compass.clear()
assert(#symbols == 1, "disconnect cleanup preserves death annotations")
tick()
assert(#symbols == 2)
options.extraction.value = false
tick()
assert(#symbols == 1, "disabling extraction markers cleans only integration sites")
client, world = true, "other-world"
player = newPlayer()
tick()
assert(#ViewpointCompassMarkers.refresh(player, true).markers == 0, "death history must be scoped per world/user")
local nativeCalls = 0
ExtractionMode.Config.COMMAND_MODULE = "ExtractionMode"
ExtractionMode.Client = {
    stateFor = function() return ExtractionMode.ClientState end,
    sendCommand = function() nativeCalls = nativeCalls + 1; return "native result" end,
    receiveServerCommand = function() return "native response" end,
}
tick()
local initial = #symbols
state("RAID", {})
options.raidDeathsOnly.value = true
assert(ExtractionMode.Client.sendCommand(player, "RescueFromDeath", {rescueRequestId = "first"}) == "native result")
player.x, player.y = 999, 888
state("HIDEOUT")
assert(ExtractionMode.Client.receiveServerCommand("ExtractionMode", "ApplyDeathRescueHealth", {}, player) == "native response")
assert(#symbols == initial + 1 and symbols[#symbols].x == 12.25 and symbols[#symbols].y == 34.5,
    "SP rescue must mark the pre-teleport location even without OnPlayerDeath")
Compass.death(player)
ExtractionMode.Client.receiveServerCommand("ExtractionMode", "ApplyDeathRescueHealth", {}, player)
assert(#symbols == initial + 1, "duplicate native death and confirmation must not duplicate rescue markers")
state("RAID", {})
ExtractionMode.Client.sendCommand(player, "RescueFromDeath", {rescueRequestId = "second"})
Events.OnServerCommand.fire("ExtractionMode", "ApplyDeathRescueHealth", {_targetIdentity = "other"})
assert(#symbols == initial + 1, "other players' rescue replies must not confirm this request")
Events.OnServerCommand.fire("ExtractionMode", "ApplyDeathRescueHealth", {_targetIdentity = "user", _targetPlayerNum = 0})
assert(#symbols == initial + 2, "MP confirmation supports repeated rescues of the same character")
ExtractionMode.Client.sendCommand(player, "RescueFromDeath", {rescueRequestId = "rejected"})
Events.OnServerCommand.fire("ExtractionMode", "DeathRescueRejected", {_targetIdentity = "user"})
Events.OnServerCommand.fire("ExtractionMode", "ApplyDeathRescueHealth", {_targetIdentity = "user"})
assert(#symbols == initial + 2 and nativeCalls == 3, "rejected rescues never create a marker or alter native commands")
ExtractionMode.Client.sendCommand(player, "RescueFromDeath", {rescueRequestId = "actual-death"})
player.dead = true
Compass.death(player)
Events.OnServerCommand.fire("ExtractionMode", "DeathRescueRejected", {_targetIdentity = "user"})
assert(#symbols == initial + 3, "an actual engine death remains marked even if its rescue is rejected")
ViewpointCompassMap = nil
tick()
print("compass_spec: raid lifecycle, waypoint registration, death persistence, manual removal, settings, scope and policy passed")
