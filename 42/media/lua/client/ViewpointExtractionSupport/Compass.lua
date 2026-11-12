local Compass = {}
local sessions, settings = {}, {}
local fields = {"x", "y", "r", "g", "b", "a", "scale", "rotation", "anchorX", "anchorY", "minZoom", "maxZoom"}
local lastUpdate, warned = 0, false
local pendingRescues = setmetatable({}, {__mode = "k"})
local protect

local function hex(value)
    return (tostring(value):gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function unhex(value)
    return (value:gsub("%x%x", function(c) return string.char(tonumber(c, 16)) end))
end

local function ready()
    return ViewpointCompassMap and ViewpointCompassMarkers
        and type(ViewpointCompassMarkers.refresh) == "function"
        and type(ViewpointCompassMarkers.add) == "function"
        and type(ViewpointCompassMarkers.remove) == "function"
        and type(ViewpointCompassMarkers.rename) == "function"
        and ViewpointExtractionSupportBridge and ViewpointExtractionSupportBridge.compassCreate
end

local function snapshot(symbol)
    local map = ViewpointCompassMap
    local s = {content = map.getContent(symbol), style = map.getStyle(symbol)}
    for _, field in ipairs(fields) do s[field] = map.getNumber(symbol, field) end
    return s
end

local function matches(symbol, s)
    local map = ViewpointCompassMap
    if map.isText(symbol) or map.getContent(symbol) ~= s.content or map.getStyle(symbol) ~= s.style then return false end
    for _, field in ipairs(fields) do
        if math.abs(map.getNumber(symbol, field) - s[field]) > 0.000001 then return false end
    end
    return true
end

local function save(session)
    local writer = getFileWriter(session.path, true, false)
    if not writer then error("Could not save compass waypoints") end
    for _, record in ipairs(session.records) do
        local s = record.signature
        local line = {record.kind, s.content, s.style, hex(record.name or "")}
        for _, field in ipairs(fields) do line[#line + 1] = string.format("%.17g", s[field]) end
        writer:write(table.concat(line, "|") .. "\n")
    end
    writer:close()
    ViewpointExtractionSupportBridge.compassSave()
end

local function sessionFor(player)
    local owner = isClient() and player:getUsername() or tostring(player:getPlayerNum())
    local scope = tostring(getWorld():getWorld()) .. "|" .. (isClient() and getServerIP() or "SP") .. "|" .. owner
    local session = sessions[scope]
    if not session then
        session = {path = "VESCompass_" .. hex(scope) .. ".txt", records = {}}
        local reader = getFileReader(session.path, false)
        if reader then
            local line = reader:readLine()
            while line do
                local parts = {}
                for value in (line .. "|"):gmatch("(.-)|") do parts[#parts + 1] = value end
                if #parts == #fields + 4 and (parts[1] == "extraction" or parts[1] == "death") then
                    local s, valid = {content = parts[2], style = parts[3]}, true
                    for i, field in ipairs(fields) do
                        local number = tonumber(parts[i + 4])
                        if not number or number ~= number or math.abs(number) == math.huge then valid = false end
                        s[field] = number
                    end
                    if valid then session.records[#session.records + 1] = {
                        kind = parts[1], signature = s, name = unhex(parts[4]),
                    } end
                end
                line = reader:readLine()
            end
            reader:close()
        end
        sessions[scope] = session
    end
    if session.player ~= player then
        session.player = player
        for _, record in ipairs(session.records) do record.bound, record.symbol = false, nil end
    end
    return session
end

local function findSymbol(collection, record)
    if record.symbol and ViewpointExtractionSupportBridge.compassIndex(collection, record.symbol) >= 0 then return record.symbol end
    local found
    for index = 0, ViewpointCompassMap.getCount(collection) - 1 do
        local symbol = ViewpointCompassMap.getSymbol(collection, index)
        if matches(symbol, record.signature) then
            -- Identical user annotations cannot safely be claimed or deleted.
            if found then return nil, true end
            found = symbol
        end
    end
    return found
end

local function track(player, collection, record)
    local markers = ViewpointCompassMarkers
    markers.add(player, ViewpointExtractionSupportBridge.compassIndex(collection, record.symbol))
    for _, marker in ipairs(markers.refresh(player, true).markers) do
        if marker.symbol == record.symbol then
            if record.name ~= "" then markers.rename(player, marker, record.name) end
            return
        end
    end
end

local function createSymbol(collection, record)
    local s = record.signature
    local symbol = ViewpointExtractionSupportBridge.compassCreate(
        collection, s.content, s.x, s.y, s.r, s.g, s.b, s.a or 1)
    record.symbol, record.signature = symbol, snapshot(symbol)
end

local function raidActive(player, state)
    local config = ExtractionMode.Config
    return not player:isDead() and state and state.isParticipant == true
        and (state.state == config.STATE_RAID or state.state == config.STATE_EXTRACTING
            or state.state == config.STATE_BOARDING)
end

local function style(kind)
    local icon = settings[kind .. "Icon"]:getValue()
    if not MapSymbolDefinitions.getInstance():getSymbolById(icon) then
        icon = kind == "death" and "FaceDead" or "Z"
    end
    local color = settings[kind .. "Color"]:getValue()
    return icon, color
end

local function allowed()
    return not ViewpointCompassServerPolicy or ViewpointCompassServerPolicy.getBoolean("AllowMapWaypoints")
end

local function update(player)
    local collection = ViewpointCompassMap.getCollection()
    if not collection then return end
    local session = sessionFor(player)
    if not player:isDead() and session.deathAt and getTimestampMs() - session.deathAt > 10000 then
        session.deathPlayer = nil
    end
    local compassState = ViewpointCompassMarkers.refresh(player, true)
    if not compassState then return end
    local tracked = {}
    for _, marker in ipairs(compassState.markers) do tracked[marker.symbol] = marker end
    local state = ExtractionMode.ClientStates and ExtractionMode.ClientStates[player:getPlayerNum()]
        or player:getPlayerNum() == 0 and ExtractionMode.ClientState
    local desired = {}
    local icon, color = style("extraction")
    if settings.extraction:getValue() and allowed() and raidActive(player, state) then
        for _, site in ipairs(state.extractionSites or {}) do
            local x, y = tonumber(site.x), tonumber(site.y)
            if x and y and x == x and y == y and math.abs(x) < 10000000 and math.abs(y) < 10000000 then
                desired[tostring(x) .. ":" .. tostring(y)] = {x = x, y = y, id = site.id}
            end
        end
    end
    local changed = false
    for index = #session.records, 1, -1 do
        local record = session.records[index]
        local symbol, ambiguous = findSymbol(collection, record)
        local s = record.signature
        local key = tostring(s.x) .. ":" .. tostring(s.y)
        local keep = record.kind == "death" or desired[key] ~= nil
        -- Wait for the first synchronized raid state before deleting restored extractions.
        if record.kind == "extraction" and not state and not player:isDead() then keep = true end
        if record.kind == "extraction" and keep and desired[key] then
            keep = s.content == icon and math.abs(s.r - color.r) < 0.000001
                and math.abs(s.g - color.g) < 0.000001 and math.abs(s.b - color.b) < 0.000001
                and math.abs(s.a - color.a) < 0.000001
        end
        if record.kind == "death" and not allowed() then
            record.bound = false
        elseif not keep or ambiguous then
            if ambiguous then desired[key] = nil end
            if symbol and not ambiguous then ViewpointExtractionSupportBridge.compassRemove(collection, symbol) end
            table.remove(session.records, index)
            changed = true
        elseif not record.bound then
            record.symbol = symbol
            if not symbol and record.kind == "death" and allowed() then createSymbol(collection, record) end
            if record.symbol and allowed() then track(player, collection, record) end
            record.bound = true
            changed = true
            if record.kind == "extraction" then desired[key] = nil end
        elseif not symbol or not tracked[symbol] and record.kind == "death" then
            table.remove(session.records, index)
            changed = true
        else
            record.symbol = symbol
            if not matches(symbol, record.signature) then changed = true end
            record.signature = snapshot(symbol)
            if tracked[symbol] and record.name ~= (tracked[symbol].name or "") then
                record.name, changed = tracked[symbol].name or "", true
            end
            if record.kind == "extraction" then desired[key] = nil end
        end
    end
    for _, site in pairs(desired) do
        local record = {kind = "extraction", bound = true,
            name = getText("UI_ViewpointExtractionSupport_CompassExtractionName", tostring(site.id or "")),
            signature = {content = icon, x = site.x, y = site.y, r = color.r, g = color.g, b = color.b, a = color.a}}
        createSymbol(collection, record)
        track(player, collection, record)
        session.records[#session.records + 1] = record
        changed = true
    end
    if changed then save(session) end
end

local function installRemovalHook()
    local markers = ViewpointCompassMarkers
    if markers.remove == Compass.removeWrapper then return end
    local original = markers.remove
    Compass.removeWrapper = function(player, marker)
        original(player, marker)
        for _, session in pairs(sessions) do
            if session.player == player then
                local changed = false
                for index = #session.records, 1, -1 do
                    local record = session.records[index]
                    if record.kind == "death" and (not marker or record.symbol == marker.symbol) then
                        table.remove(session.records, index)
                        changed = true
                    end
                end
                if changed then save(session) end
            end
        end
    end
    markers.remove = Compass.removeWrapper
end

local function rescueResponse(module, command, args, target)
    if module ~= ExtractionMode.Config.COMMAND_MODULE then return end
    if command ~= "ApplyDeathRescueHealth" and command ~= "DeathRescueRejected" then return end
    for player, pending in pairs(pendingRescues) do
        local addressed = target == player or not target
            and (not args or not args._targetIdentity or args._targetIdentity == player:getUsername())
            and (not args or args._targetPlayerNum == nil or tonumber(args._targetPlayerNum) == player:getPlayerNum())
        if addressed then
            pendingRescues[player] = nil
            if command == "ApplyDeathRescueHealth" then Compass.death(player, pending, pending.id) end
        end
    end
end

local function installRescueHooks()
    local client = ExtractionMode.Client
    if not client or type(client.sendCommand) ~= "function" then return end
    if client.sendCommand ~= Compass.sendWrapper then
        local original = client.sendCommand
        Compass.sendWrapper = function(player, command, args)
            if command == "RescueFromDeath" and player and getSpecificPlayer(player:getPlayerNum()) == player then
                protect(function()
                    local state = client.stateFor(player)
                    local config = ExtractionMode.Config
                    pendingRescues[player] = {x = player:getX(), y = player:getY(), z = player:getZ(),
                        inRaid = state and state.isParticipant == true and (state.state == config.STATE_RAID
                            or state.state == config.STATE_EXTRACTING or state.state == config.STATE_BOARDING),
                        id = args and args.rescueRequestId or tostring(getTimestampMs())}
                end)
            end
            return original(player, command, args)
        end
        client.sendCommand = Compass.sendWrapper
    end
    -- SP delivers directly to this helper; multiplayer uses OnServerCommand.
    if type(client.receiveServerCommand) == "function" and client.receiveServerCommand ~= Compass.receiveWrapper then
        local original = client.receiveServerCommand
        Compass.receiveWrapper = function(module, command, args, target)
            protect(rescueResponse, module, command, args, target)
            return original(module, command, args, target)
        end
        client.receiveServerCommand = Compass.receiveWrapper
    end
end

function Compass.tick()
    if not ready() then return end
    installRescueHooks()
    local now = getTimestampMs()
    if now - lastUpdate < 1000 then return end
    lastUpdate = now
    installRemovalHook()
    for number = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(number)
        if player then update(player) end
    end
end

function Compass.death(player, location, rescueId)
    if not ready() or not settings.death:getValue() or not allowed()
        or not player or getSpecificPlayer(player:getPlayerNum()) ~= player then return end
    local state = ExtractionMode.ClientStates and ExtractionMode.ClientStates[player:getPlayerNum()]
        or ExtractionMode.ClientState
    if not rescueId and pendingRescues[player] then
        location = pendingRescues[player]
        rescueId = location.id
    end
    local inRaid = location and location.inRaid or not location and (state and state.isParticipant == true
        and (state.state == ExtractionMode.Config.STATE_RAID or state.state == ExtractionMode.Config.STATE_EXTRACTING
            or state.state == ExtractionMode.Config.STATE_BOARDING))
    if settings.raidDeathsOnly:getValue() and not inRaid then return end
    update(player)
    local collection = ViewpointCompassMap.getCollection()
    if not collection then return end
    local session = sessionFor(player)
    if rescueId and session.lastRescueId == rescueId or not rescueId and session.deathPlayer == player then return end
    local icon, color = style("death")
    local record = {kind = "death", bound = true,
        name = getText("UI_ViewpointExtractionSupport_CompassDeathName", tostring(location and location.z or player:getZ())),
        signature = {content = icon, x = location and location.x or player:getX(),
            y = location and location.y or player:getY(), r = color.r, g = color.g, b = color.b, a = color.a}}
    createSymbol(collection, record)
    track(player, collection, record)
    session.records[#session.records + 1] = record
    save(session)
    session.deathPlayer, session.lastRescueId = player, rescueId
    session.deathAt = getTimestampMs()
    print("[Viewpoint Extraction Support] Death waypoint saved at " .. tostring(record.signature.x)
        .. ", " .. tostring(record.signature.y) .. (rescueId and " (Extraction Mode rescue)." or "."))
end

function Compass.clear()
    if not ready() then return end
    local collection = ViewpointCompassMap.getCollection()
    if not collection then return end
    for _, session in pairs(sessions) do
        local changed = false
        for index = #session.records, 1, -1 do
            local record = session.records[index]
            if record.kind == "extraction" then
                local symbol, ambiguous = findSymbol(collection, record)
                if symbol and not ambiguous then ViewpointExtractionSupportBridge.compassRemove(collection, symbol) end
                table.remove(session.records, index)
                changed = true
            end
        end
        if changed then
            ViewpointCompassMarkers.refresh(session.player, true)
            save(session)
        end
    end
end

function Compass.install(options)
    settings = options
    protect = function(callback, ...)
        local ok, failure = pcall(callback, ...)
        if not ok and not warned then
            warned = true
            print("[Viewpoint Extraction Support] Compass integration unavailable: " .. tostring(failure))
        end
    end
    Events.OnTick.Add(function() protect(Compass.tick) end)
    Events.OnPlayerDeath.Add(function(player) protect(Compass.death, player) end)
    Events.OnServerCommand.Add(function(module, command, args) protect(rescueResponse, module, command, args) end)
    Events.OnDisconnect.Add(function() protect(Compass.clear) end)
    Events.OnMainMenuEnter.Add(function()
        protect(Compass.clear)
        sessions, lastUpdate = {}, 0
        pendingRescues = setmetatable({}, {__mode = "k"})
    end)
end

return Compass
