local nightMessages = {
    [1] = { text = "A small stroke of luck. Something fast is hunting nearby.", color = { 137, 232, 148 } },
    [2] = { text = "Fortune smiles, but the dead are moving faster. Stay sharp.", color = { 255, 210, 64 } },
    [3] = { text = "The night offers riches. The dead are running in numbers. Keep moving.", color = { 255, 140, 64 } },
    [4] = { text = "Fortune is at its peak. Sprinters are everywhere. Run.", color = { 255, 80, 80 } },
}

local dawnMessage = "Dawn breaks. The dead have slowed, but the night's warning still stands: stay alert."
local hordeMessage = "Radio: A horde is one hour out. Find cover or get moving."
local noticeDuration = 256
local lastNightCycle
local nightWasActive = false
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

local function updateNightNotice(player, night)
    if night.enabled ~= true then
        nightWasActive = false
        lastNightCycle = night.nightCycle
        return
    end

    if night.isNight then
        if night.levelReady ~= true then return end
        if not nightWasActive or lastNightCycle ~= night.nightCycle then
            local notice = nightMessages[tonumber(night.level) or 1] or nightMessages[1]
            showNotice(player, notice.text, notice.color)
            nightWasActive = true
            lastNightCycle = night.nightCycle
        end
    elseif nightWasActive then
        showNotice(player, dawnMessage, { 175, 215, 255 })
        nightWasActive = false
    end
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

    local night = ViewpointExtractionSupportNight
    if night then updateNightNotice(player, night) end

    local extraction = ExtractionMode
    local config = extraction and extraction.Config
    local data = extraction and (extraction.ClientState
        or extraction.ClientStates and extraction.ClientStates[0])
    if config and data then updateHordeNotice(player, data, config) end
end

Events.OnTick.Add(update)
