local Effects = {}
local flares = {}
local lastShot = setmetatable({}, { __mode = "k" })
local enabled = true
local duration = 20
local module = "ViewpointExtractionSupport"

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) <= 10000000
end

local function clock()
    return ExtractionMode.Util.timerNowMs()
end

local function receive(x, y, z, dx, dy)
    if not finite(x) or not finite(y) or not finite(z) or not finite(dx) or not finite(dy) then return end
    if #flares >= 8 then table.remove(flares, 1) end
    flares[#flares + 1] = { x = x, y = y, z = z, dx = dx, dy = dy, started = clock() }
end

function Effects.shot(player)
    if not player or player:isDead() then return end
    local weapon = player:getPrimaryHandItem()
    if not weapon or weapon:getFullType() ~= "ExtractionMode.ExtractionFlareGun" then return end
    local now = getTimestampMs()
    if lastShot[player] and now - lastShot[player] < 1500 then return end
    lastShot[player] = now
    receive(player:getX(), player:getY(), player:getZ(),
        player:getForwardDirectionX(), player:getForwardDirectionY())
    if isClient() then
        sendClientCommand(player, module, "FlareShot", {})
    end
end

function Effects.update()
    local bridge = ViewpointExtractionSupportBridge
    if not bridge or not bridge.beginFlares then return end
    bridge.beginFlares()
    local now = clock()
    for index = #flares, 1, -1 do
        local flare = flares[index]
        local age = math.max(0, (now - flare.started) / 1000)
        if age >= duration then
            table.remove(flares, index)
        elseif enabled then
            bridge.flare(flare.x, flare.y, flare.z, flare.dx, flare.dy, age)
        end
    end
    bridge.endFlares()
end

function Effects.configure(value)
    enabled = value == true
    Effects.update()
end

function Effects.reset()
    flares = {}
    lastShot = setmetatable({}, { __mode = "k" })
    local bridge = ViewpointExtractionSupportBridge
    if bridge and bridge.clearFlares then bridge.clearFlares() end
end

local function install()
    local client = ExtractionMode and ExtractionMode.Client
    if not client or not client.sendCommand or client._vesFlareEffects then return end
    local send = client.sendCommand
    client.sendCommand = function(player, command, args, ...)
        if command == "FireFlare" then
            local ok, err = pcall(Effects.shot, player)
            if not ok then print("[Viewpoint Extraction Support] Flare effect unavailable: " .. tostring(err)) end
        end
        return send(player, command, args, ...)
    end
    client._vesFlareEffects = true
end

Events.OnServerCommand.Add(function(commandModule, command, args)
    if commandModule ~= module or command ~= "FlareShot" or type(args) ~= "table" then return end
    receive(args.x, args.y, args.z, args.dx, args.dy)
end)
Events.OnGameStart.Add(function() Effects.reset(); install() end)
Events.OnTick.Add(Effects.update)
Events.OnDisconnect.Add(Effects.reset)
Events.OnMainMenuEnter.Add(Effects.reset)
install()

return Effects
