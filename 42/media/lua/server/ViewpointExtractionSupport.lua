local lastShot = setmetatable({}, { __mode = "k" })

Events.OnClientCommand.Add(function(module, command, player)
    if module ~= "ViewpointExtractionSupport" or command ~= "FlareShot" then return end
    if not player or player:isDead() then return end
    local weapon = player:getPrimaryHandItem()
    if not weapon or weapon:getFullType() ~= "ExtractionMode.ExtractionFlareGun" then return end
    local now = getTimestampMs()
    if lastShot[player] and now - lastShot[player] < 1500 then return end
    lastShot[player] = now

    local x, y = player:getX(), player:getY()
    local args = { x = x, y = y, z = player:getZ(),
        dx = player:getForwardDirectionX(), dy = player:getForwardDirectionY() }
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local observer = players:get(index)
        if observer ~= player and (observer:getX() - x)^2 + (observer:getY() - y)^2 <= 150^2 then
            sendServerCommand(observer, module, command, args)
        end
    end
end)
