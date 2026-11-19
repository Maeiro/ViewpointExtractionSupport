require "ExtractionMode/TrueCompanionsIntegration"

local ALife = require "ViewpointExtractionSupport/ALifeCompanions"
local Client = {}
local SOURCE_CAPTURE_RADIUS = 256
local MAX_CAPTURED_COMPANIONS = 16
local pendingMoves = {}
local hooksInstalled = false

local function captureALifeCompanions(player, captured)
    local cell = getCell and getCell() or nil
    local zombies = cell and cell.getZombieList and cell:getZombieList() or nil
    if zombies == nil then return captured end

    local seen = {}
    for _, entry in ipairs(captured) do
        if entry._viewpointALife == true then seen[entry.uid] = true end
    end

    local sourceX, sourceY, sourceZ = player:getX(), player:getY(), player:getZ()
    local radiusSquared = SOURCE_CAPTURE_RADIUS * SOURCE_CAPTURE_RADIUS
    for index = 0, zombies:size() - 1 do
        local shell = zombies:get(index)
        local ok, companion = pcall(ALife.isCompanion, shell)
        local alive = false
        if ok and companion then
            local aliveOk, isDead = pcall(function() return shell:isDead() end)
            alive = aliveOk and not isDead
        end
        if alive then
            local dx, dy = shell:getX() - sourceX, shell:getY() - sourceY
            local dataOk, data = pcall(function() return shell:getModData() end)
            if not dataOk then data = nil end
            local uid = type(data) == "table" and data.ProjectALifeUID or nil
            if type(uid) == "string" and uid ~= "" and not seen[uid]
                and dx * dx + dy * dy <= radiusSquared
                and math.abs(shell:getZ() - sourceZ) <= 2
                and #captured < MAX_CAPTURED_COMPANIONS then
                seen[uid] = true
                captured[#captured + 1] = {
                    _viewpointALife = true,
                    uid = uid,
                    sourceX = shell:getX(),
                    sourceY = shell:getY(),
                    sourceZ = shell:getZ(),
                }
            end
        end
    end
    return captured
end

local function localMove(entry, player, targetX, targetY, targetZ)
    if ALife.relocate then
        local ok = ALife.relocate(player, {
            entries = { entry }, targetX = targetX, targetY = targetY, targetZ = targetZ,
        })
        return ok
    end
    return false
end

local function relocateALife(entries, player, x, y, z)
    local targetX = tonumber(x) or player:getX()
    local targetY = tonumber(y) or player:getY()
    local targetZ = tonumber(z) or player:getZ()
    if isClient and isClient() then
        local payload = { entries = {}, targetX = targetX, targetY = targetY, targetZ = targetZ }
        for _, entry in ipairs(entries) do
            payload.entries[#payload.entries + 1] = {
                uid = entry.uid,
                sourceX = entry.sourceX,
                sourceY = entry.sourceY,
                sourceZ = entry.sourceZ,
            }
        end
        if #payload.entries > 0 then
            sendClientCommand(player, "ViewpointExtractionSupport", "RelocateALifeCompanions", payload)
        end
        return
    end

    for _, entry in ipairs(entries) do
        if not localMove(entry, player, targetX, targetY, targetZ) then
            pendingMoves[entry.uid] = {
                entry = entry,
                player = player,
                targetX = targetX,
                targetY = targetY,
                targetZ = targetZ,
                expiresAt = (getTimestampMs and getTimestampMs() or 0) + 20000,
            }
        end
    end
end

function Client.install()
    if hooksInstalled then return true end
    local integration = ExtractionMode and ExtractionMode.TrueCompanionsIntegration
    if type(integration) ~= "table" or type(integration.captureForTransition) ~= "function"
        or type(integration.relocateCaptured) ~= "function" then return false end

    local capture = integration.captureForTransition
    integration.captureForTransition = function(player, raidOnly)
        local captured = capture(player, raidOnly)
        if raidOnly == true and player and type(captured) == "table" then
            local ok, withALife = pcall(captureALifeCompanions, player, captured)
            if ok and type(withALife) == "table" then captured = withALife end
        end
        return captured
    end

    local relocate = integration.relocateCaptured
    integration.relocateCaptured = function(captured, player, x, y, z, requireOutdoor)
        local regular, alife = {}, {}
        for _, entry in ipairs(captured or {}) do
            if entry._viewpointALife == true then
                alife[#alife + 1] = entry
            else
                regular[#regular + 1] = entry
            end
        end
        local result = relocate(regular, player, x, y, z, requireOutdoor)
        if #alife > 0 then pcall(relocateALife, alife, player, x, y, z) end
        return result
    end
    hooksInstalled = true
    return true
end

local installTicks = 0
Events.OnTick.Add(function()
    installTicks = installTicks + 1
    if not hooksInstalled and installTicks % 30 == 0 then Client.install() end

    local now = getTimestampMs and getTimestampMs() or 0
    for uid, pending in pairs(pendingMoves) do
        if now >= pending.expiresAt then
            pendingMoves[uid] = nil
        else
            local ok, moved = pcall(localMove, pending.entry, pending.player,
                pending.targetX, pending.targetY, pending.targetZ)
            if ok and moved then pendingMoves[uid] = nil end
        end
    end
end)

Client.install()
return Client
