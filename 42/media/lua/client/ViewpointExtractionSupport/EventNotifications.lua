local hordeMessage = "Radio: A horde is one hour out. Find cover or get moving."
local noticeDuration = 256
local alertedHordeRaidId
local hordeNoticeArmed = false

local function showNotice(player, message, color)
    if not player then return end
    pcall(function()
        player:setHaloNote(message, color[1], color[2], color[3], noticeDuration)
    end)
end

local function showHordeNotice(player)
    showNotice(player, hordeMessage, { 255, 165, 64 })
end

local function updateHordeNotice(player, data, config)
    local activeRaid = data.state == config.STATE_RAID
        or data.state == config.STATE_EXTRACTING
        or data.state == config.STATE_BOARDING
    local remaining = tonumber(data.hordeRemainingHours)
    local raidId = tostring(data.raidId or "")

    if not activeRaid or data.isParticipant ~= true or data.lateRaidHordeEnabled == false
        or remaining == nil then
        alertedHordeRaidId = nil
        hordeNoticeArmed = false
        return
    end

    if alertedHordeRaidId ~= raidId then
        alertedHordeRaidId = raidId
        hordeNoticeArmed = false
    end

    if remaining > 1 then
        hordeNoticeArmed = true
    elseif remaining > 0 and hordeNoticeArmed then
        showHordeNotice(player)
        hordeNoticeArmed = false
    end
end

local function update()
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end

    local extraction = ExtractionMode
    local config = extraction and extraction.Config
    local data = extraction and (extraction.ClientState
        or extraction.ClientStates and extraction.ClientStates[0])
    if config and data then updateHordeNotice(player, data, config) end
end

Events.OnTick.Add(update)
