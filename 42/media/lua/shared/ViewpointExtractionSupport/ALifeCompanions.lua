require "ExtractionMode/Util"

local Integration = {}
local pendingMoves = {}
local MOVE_TIMEOUT_MS = 20000
local ARRIVAL_RADIUS = 64
local SOURCE_RADIUS = 256

local function companionApi()
    local project = ProjectALife
    local companions = project and project.Companions
    if type(companions) ~= "table" then return nil end
    return companions
end

function Integration.isCompanion(shell)
    if not ExtractionMode.Util.isALifeNPC(shell) then return false end

    local companions = companionApi()
    if companions and type(companions.actorOfShell) == "function"
        and type(companions.isCandidate) == "function" then
        local ok, actor = pcall(companions.actorOfShell, shell)
        if ok and type(actor) == "table" then
            local checked, candidate = pcall(companions.isCandidate, actor)
            if checked then return candidate == true end
        end
    end

    local ok, data = pcall(function() return shell:getModData() end)
    if not ok then return false end
    if type(data) ~= "table" then return false end
    if data.ProjectALifeFactionId == "alife_companions" then return true end
    local profileId = tostring(data.ProjectALifeProfileId or "")
    local prefix = "alife_companion_"
    return string.sub(profileId, 1, #prefix) == prefix
end

local function shellUid(shell)
    local ok, data = pcall(function() return shell:getModData() end)
    if not ok then return nil end
    local uid = type(data) == "table" and data.ProjectALifeUID or nil
    if type(uid) ~= "string" or uid == "" then return nil end
    return uid
end

function Integration.installCleanupGuard()
    local util = ExtractionMode and ExtractionMode.Util
    if type(util) ~= "table" or type(util.retireALifeNPC) ~= "function"
        or util._viewpointALifeCompanionGuard then return end

    local retire = util.retireALifeNPC
    util.retireALifeNPC = function(shell)
        local ok, isCompanion = pcall(Integration.isCompanion, shell)
        if ok and isCompanion then return false end
        return retire(shell)
    end
    util._viewpointALifeCompanionGuard = true
end

local function validPosition(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z
        or math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then
        return nil
    end
    return x, y, z
end

local function getShell(uid)
    local companions = companionApi()
    if companions and type(companions.shellOf) == "function" then
        local ok, shell = pcall(companions.shellOf, uid)
        if ok and shell then return shell end
    end

    local cell = getCell and getCell() or nil
    local zombies = cell and cell.getZombieList and cell:getZombieList() or nil
    if zombies == nil then return nil end
    for index = 0, zombies:size() - 1 do
        local shell = zombies:get(index)
        if shellUid(shell) == uid then return shell end
    end
    return nil
end

local function distanceSquared(x1, y1, x2, y2)
    return (x1 - x2) ^ 2 + (y1 - y2) ^ 2
end

local function moveNearPlayer(uid, player, source, target)
    if not player or player:isDead() then return false end
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    if math.abs(px - target.x) > ARRIVAL_RADIUS or math.abs(py - target.y) > ARRIVAL_RADIUS
        or math.abs(pz - target.z) > 2 then return false end

    local shell = getShell(uid)
    if not shell or (shell.isDead and shell:isDead()) or not Integration.isCompanion(shell) then return true end
    if distanceSquared(shell:getX(), shell:getY(), source.x, source.y) > SOURCE_RADIUS * SOURCE_RADIUS
        or math.abs(shell:getZ() - source.z) > 2 then return true end
    if math.abs(shell:getZ() - pz) <= 0.5
        and distanceSquared(shell:getX(), shell:getY(), px, py) <= 64 then return true end

    local companions = companionApi()
    if not companions or type(companions.bringNear) ~= "function" then return false end
    local ok, moved = pcall(companions.bringNear, shell, player)
    return ok and moved == true
end

function Integration.relocate(player, args)
    if not player or player:isDead() or type(args) ~= "table" then return false end
    local targetX, targetY, targetZ = validPosition(args.targetX, args.targetY, args.targetZ)
    if not targetX then return false end
    local target = { x = targetX, y = targetY, z = targetZ }
    local entries = type(args.entries) == "table" and args.entries or {}
    local now = getTimestampMs and getTimestampMs() or 0
    local handled = false

    for index = 1, math.min(#entries, 16) do
        local entry = entries[index]
        local uid = type(entry) == "table" and entry.uid or nil
        local sx, sy, sz
        if type(entry) == "table" then
            sx, sy, sz = validPosition(entry.sourceX, entry.sourceY, entry.sourceZ)
        end
        if type(uid) == "string" and #uid <= 128 and sx then
            local shell = getShell(uid)
            local source = { x = sx, y = sy, z = sz }
            if shell and Integration.isCompanion(shell)
                and distanceSquared(shell:getX(), shell:getY(), sx, sy) <= SOURCE_RADIUS * SOURCE_RADIUS
                and math.abs(shell:getZ() - sz) <= 2 then
                handled = true
                local pending = {
                    player = player,
                    uid = uid,
                    source = source,
                    target = target,
                    expiresAt = now + MOVE_TIMEOUT_MS,
                }
                pendingMoves[uid] = pending
                if moveNearPlayer(uid, player, source, target) then
                    pendingMoves[uid] = nil
                end
            end
        end
    end
    return handled
end

function Integration.update()
    local now = getTimestampMs and getTimestampMs() or 0
    for uid, pending in pairs(pendingMoves) do
        if now >= pending.expiresAt or moveNearPlayer(uid, pending.player, pending.source, pending.target) then
            pendingMoves[uid] = nil
        end
    end
end

Integration.installCleanupGuard()
Events.OnTick.Add(function() pcall(Integration.update) end)

return Integration
