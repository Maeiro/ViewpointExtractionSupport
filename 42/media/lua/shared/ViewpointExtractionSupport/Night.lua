local Night = {
    enabled = false,
    isNight = false,
    nightCycle = 0,
    level = 1,
    lootBonusPercent = 0,
    sprinterPercentage = 0,
}

local nightDataKey = "ViewpointExtractionSupportNight"
local defaultLevels = {
    { weight = 50, lootBonusPercent = 50, sprinterPercentage = 10 },
    { weight = 35, lootBonusPercent = 100, sprinterPercentage = 20 },
    { weight = 10, lootBonusPercent = 150, sprinterPercentage = 33 },
    { weight = 5, lootBonusPercent = 200, sprinterPercentage = 50 },
}

local function getNightCycle(gameTime)
    local year = gameTime:getYear()
    local day = year * 400 + gameTime:getDay()

    for month = 0, gameTime:getMonth() - 1 do
        day = day + gameTime:daysInMonth(year, month)
    end

    if gameTime:getHour() < gameTime:getDawn() then
        day = day - 1
    end

    return day
end

local function clampSetting(value, minimum, maximum, fallback)
    return math.max(minimum, math.min(maximum, tonumber(value) or fallback))
end

local function getLevels(settings)
    local levels = {}
    for level = 1, 4 do
        local defaults = defaultLevels[level]
        local prefix = "NightLevel" .. level
        levels[level] = {
            weight = clampSetting(settings[prefix .. "Weight"], 0, 100, defaults.weight),
            lootBonusPercent = clampSetting(settings[prefix .. "LootBonus"], 0, 500, defaults.lootBonusPercent),
            sprinterPercentage = clampSetting(settings[prefix .. "SprinterPercentage"], 0, 100, defaults.sprinterPercentage),
        }
    end
    return levels
end

local function chooseLevel(levels)
    local totalWeight = 0
    for level = 1, 4 do
        totalWeight = totalWeight + levels[level].weight
    end
    if totalWeight == 0 then return 1 end

    local roll = ZombRand(totalWeight)
    local accumulatedWeight = 0
    for level = 1, 4 do
        accumulatedWeight = accumulatedWeight + levels[level].weight
        if roll < accumulatedWeight then return level end
    end
    return 4
end

local function getNightLevel(cycle, levels)
    if isClient() then
        local data = ModData.get(nightDataKey)
        if data and tonumber(data.nightCycle) == cycle then
            return clampSetting(data.level, 1, 4, 1)
        end
        return 1
    end

    local data = ModData.getOrCreate(nightDataKey)
    if tonumber(data.nightCycle) ~= cycle then
        data.nightCycle = cycle
        data.level = chooseLevel(levels)
        if isServer() then
            ModData.transmit(nightDataKey)
        end
    end
    return clampSetting(data.level, 1, 4, 1)
end

local function refresh()
    local settings = SandboxVars and SandboxVars.ViewpointExtractionSupport or {}
    local gameTime = getGameTime()

    Night.enabled = settings.NightMode == true
    Night.isNight = gameTime:isNight()
    Night.nightCycle = getNightCycle(gameTime)
    Night.levels = getLevels(settings)
    Night.level = Night.enabled and Night.isNight and getNightLevel(Night.nightCycle, Night.levels) or 1

    local selectedLevel = Night.levels[Night.level]
    Night.lootBonusPercent = Night.enabled and Night.isNight and selectedLevel.lootBonusPercent or 0
    Night.sprinterPercentage = Night.enabled and Night.isNight and selectedLevel.sprinterPercentage or 0

    local bridge = ViewpointExtractionSupportBridge
    if bridge and bridge.setNightFeatureState then
        bridge.setNightFeatureState(Night.enabled, Night.lootBonusPercent, Night.isNight, Night.level,
            Night.sprinterPercentage)
    end
end

Night.refresh = refresh
ViewpointExtractionSupportNight = Night

Events.OnGameStart.Add(refresh)
Events.EveryOneMinute.Add(refresh)

return Night
