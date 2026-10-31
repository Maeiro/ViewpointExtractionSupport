local lastCountdownByPlayer = {}

local function townName(config, data)
    if type(config.townDisplayName) == "function" then
        local name = config.townDisplayName(data.selectedTownKey, data.selectedTownName)
        if name and name ~= "" then return name end
    end
    return tostring(data.selectedTownName or data.selectedTownKey or "RAID")
end

local function showCountdown(player, config, data, seconds)
    local town = townName(config, data)
    local localization = ExtractionMode.Localization
    local message = localization and localization.get
        and localization.get("IGUI_ExtractionMode_DeployingIn", "DEPLOYING TO %1 IN %2s", town, tostring(seconds))
        or ("DEPLOYING TO " .. town .. " IN " .. tostring(seconds) .. "s")

    pcall(function()
        player:setHaloNote(message, 137, 232, 148, 128)
    end)
end

local function update()
    local config = ExtractionMode and ExtractionMode.Config
    if not config or not getSpecificPlayer then return end

    local states = ExtractionMode.ClientStates or { [0] = ExtractionMode.ClientState }
    for playerNumber, data in pairs(states) do
        local number = tonumber(playerNumber) or 0
        local player = getSpecificPlayer(number)
        local seconds = type(data) == "table" and tonumber(data.countdownSeconds) or nil
        local active = player and type(data) == "table" and data.state == config.STATE_COUNTDOWN
            and seconds ~= nil

        if active then
            seconds = math.max(0, math.floor(seconds))
            local town = townName(config, data)
            local last = lastCountdownByPlayer[number]
            if not last or last.seconds ~= seconds or last.town ~= town then
                showCountdown(player, config, data, seconds)
                lastCountdownByPlayer[number] = { seconds = seconds, town = town }
            end
        else
            lastCountdownByPlayer[number] = nil
        end
    end
end

Events.OnTick.Add(update)
