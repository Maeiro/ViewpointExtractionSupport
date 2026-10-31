local Night = {
    enabled = false,
    isNight = false,
    nightCycle = 0,
    lootBonusPercent = 50,
    sprinterPercentage = 10,
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

local function refresh()
    local settings = SandboxVars and SandboxVars.ViewpointExtractionSupport or {}
    local gameTime = getGameTime()

    Night.enabled = settings.NightMode == true
    Night.isNight = gameTime:isNight()
    Night.nightCycle = getNightCycle(gameTime)
    Night.lootBonusPercent = math.max(0, math.min(500, tonumber(settings.NightLootBonus) or 50))
    Night.sprinterPercentage = math.max(0, math.min(100, tonumber(settings.NightSprinterPercentage) or 10))

    local bridge = ViewpointExtractionSupportBridge
    if bridge and bridge.setNightFeatureState then
        bridge.setNightFeatureState(Night.enabled, Night.lootBonusPercent, Night.isNight)
    end
end

Night.refresh = refresh
ViewpointExtractionSupportNight = Night

Events.OnGameStart.Add(refresh)
Events.EveryOneMinute.Add(refresh)

return Night
