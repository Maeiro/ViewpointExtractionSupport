require "PZAPI/ModOptions"
require "ExtractionMode/Config"
require "ExtractionMode/Util"

local Flights = require "ViewpointExtractionSupport/Flights"
local Areas = require "ViewpointExtractionSupport/Areas"
local interaction = require "ViewpointExtractionSupport/Interaction"
local HudVisibility = require "ViewpointExtractionSupport/HudVisibility"
local NeatUI = require "ViewpointExtractionSupport/NeatUI"
local Support = {}
ViewpointExtractionSupport = Support

local onlyWithInventory
local useNeatUI
local selectedAircraft = {}
local interactionTicks = 0
local function installInteraction()
    interactionTicks = interactionTicks + 1
    if interactionTicks % 10 ~= 0 then return end
    interaction.install()
    interaction.sync()
    HudVisibility.install(onlyWithInventory)
    NeatUI.sync(useNeatUI)
end

interaction.install()
interaction.sync()
Events.OnGameStart.Add(function()
    interaction.install()
    HudVisibility.install(onlyWithInventory)
    NeatUI.sync(useNeatUI)
end)
Events.OnTick.Add(installInteraction)

local options = PZAPI.ModOptions:create("ViewpointExtractionSupport", "UI_ViewpointExtractionSupport_Title")
local enabled = options:addTickBox("enabled", "UI_ViewpointExtractionSupport_Enabled", true,
    "UI_ViewpointExtractionSupport_EnabledTooltip")
local hoverHeight = options:addSlider("hoverHeight", "UI_ViewpointExtractionSupport_HoverHeight",
    6, 30, 1, 12, "UI_ViewpointExtractionSupport_HoverHeightTooltip")
local showArea = options:addTickBox("showArea", "UI_ViewpointExtractionSupport_ShowArea", true,
    "UI_ViewpointExtractionSupport_ShowAreaTooltip")
onlyWithInventory = options:addTickBox("onlyWithInventory", "UI_ViewpointExtractionSupport_OnlyWithInventory", false,
    "UI_ViewpointExtractionSupport_OnlyWithInventoryTooltip")
useNeatUI = options:addTickBox("useNeatUI", "UI_ViewpointExtractionSupport_UseNeatUI", true,
    "UI_ViewpointExtractionSupport_UseNeatUITooltip")
local aircraftChoices = {
    { id = "UH-1BHelicopter", key = "UH1B", default = true },
    { id = "AircraftMod", key = "Nightfang" },
    { id = "LittleBird", key = "LittleBird" },
    { id = "Chinook", key = "Chinook" },
    { id = "BlackHawk", key = "BlackHawk" },
    { id = "AH1SuperCobra", key = "SuperCobra" },
    { id = "UH1", key = "UH1" },
    { id = "FTZ_Hummingbird", key = "FTZHummingbird" },
    { id = "FTZ_Orca", key = "FTZOrca" },
    { id = "FTZ_Hellcat", key = "FTZHellcat" },
}
for _, choice in ipairs(aircraftChoices) do
    choice.option = options:addTickBox("aircraft_" .. choice.key,
        "UI_ViewpointExtractionSupport_Aircraft_" .. choice.key,
        choice.default == true, "UI_ViewpointExtractionSupport_AircraftTooltip_" .. choice.key)
end
HudVisibility.install(onlyWithInventory)
NeatUI.sync(useNeatUI)

local runtime, submitted, observations = Flights.new(), {}, {}
local warned = false

local function clearFlights()
    if VisibleHelicopterEvent then
        for id in pairs(submitted) do VisibleHelicopterEvent.removeFlight(id) end
    end
    if ViewpointExtractionSupportBridge then
        ViewpointExtractionSupportBridge.suppressNative(false)
        ViewpointExtractionSupportBridge.clearNativeAudioPosition()
        ViewpointExtractionSupportBridge.clearRopes()
    end
    runtime, submitted, selectedAircraft = Flights.new(), {}, {}
end

function Support.reset()
    clearFlights()
    interaction.clear()
    observations = {}
    if ViewpointExtractionSupportBridge then ViewpointExtractionSupportBridge.clearAreas() end
end

local function pickupsForPlayers(wallNow, includeLocalState)
    local pickups = {}
    local states = ExtractionMode.ClientStates or { [0] = ExtractionMode.ClientState }
    for number, state in pairs(states) do
        local player = getSpecificPlayer(number)
        if player and not player:isDead() and type(state) == "table" and state.isParticipant == true then
            local revision = state._hudRevision or state
            local observation = observations[number]
            if not observation or observation.revision ~= revision then
                observation = { revision = revision, receivedAt = wallNow }
                observations[number] = observation
            end
            if not isClient() or wallNow - observation.receivedAt <= 5000 then
                if state.pvpveMode then
                    for _, pickup in ipairs(state.nearbyExtractions or {}) do
                        pickups[#pickups + 1] = { data = pickup, native = false }
                    end
                    if includeLocalState then
                        pickups[#pickups + 1] = { data = state, native = true }
                    end
                    if state.campaignHandoffActive then
                        pickups[#pickups + 1] = { data = state, native = true, campaign = true }
                    end
                else
                    pickups[#pickups + 1] = {
                        data = state, native = true, campaign = state.campaignHandoffActive == true,
                    }
                end
            end
        else
            observations[number] = nil
        end
    end
    return pickups
end

local function refreshAreas()
    if not ViewpointExtractionSupportBridge or not getSpecificPlayer(0) then
        if ViewpointExtractionSupportBridge then ViewpointExtractionSupportBridge.clearAreas() end
        return
    end

    ViewpointExtractionSupportBridge.beginAreas()
    if showArea:getValue() then
        for _, area in ipairs(Areas.collect(pickupsForPlayers(getTimestampMs(), true))) do
            ViewpointExtractionSupportBridge.area(area.x, area.y, area.z, area.radius)
        end
    end
    ViewpointExtractionSupportBridge.endAreas()
end

local function collect()
    local renderer = VisibleHelicopterEvent
    if not renderer or not renderer.active() or not getSpecificPlayer(0) then
        if ViewpointExtractionSupportBridge then
            ViewpointExtractionSupportBridge.configureFtzAircraft(false, false, false)
        end
        if not renderer or not getSpecificPlayer(0) then Support.reset() else clearFlights() end
        return
    end

    local featureEnabled = enabled:getValue()
    if ViewpointExtractionSupportBridge then
        ViewpointExtractionSupportBridge.registerFtzAircraft()
        ViewpointExtractionSupportBridge.configureFtzAircraft(
            featureEnabled and aircraftChoices[8].option:getValue(),
            featureEnabled and aircraftChoices[9].option:getValue(),
            featureEnabled and aircraftChoices[10].option:getValue())
    end
    local availableAircraft, allowedAircraft = {}, {}
    if featureEnabled then
        for _, choice in ipairs(aircraftChoices) do
            if choice.option:getValue() and renderer.modelAvailable(choice.id) then
                availableAircraft[#availableAircraft + 1] = choice.id
                allowedAircraft[choice.id] = true
            end
        end
    end
    local pickups = pickupsForPlayers(getTimestampMs())
    if not featureEnabled or #availableAircraft == 0 then
        clearFlights()
        return
    end

    local config = ExtractionMode.Config
    local poses = Flights.update(runtime, pickups,
        ExtractionMode.Util.timerNowMs(), {
            approachSeconds = tonumber(config.HELICOPTER_ACTIVE_APPROACH_SECONDS) or 30,
            campaignApproachSeconds = tonumber(config.CAMPAIGN_HELICOPTER_ACTIVE_APPROACH_SECONDS) or 60,
            cruiseHeight = renderer.height(),
            hoverHeight = hoverHeight:getValue(),
        })
    local desired, suppressNative, audioPose, audioDistance = {}, false, nil, nil
    local player = getSpecificPlayer(0)
    ViewpointExtractionSupportBridge.beginRopes()
    for _, pose in ipairs(poses) do
        local aircraftId = selectedAircraft[pose.id]
        if not allowedAircraft[aircraftId] then
            aircraftId = availableAircraft[ZombRand(#availableAircraft) + 1]
            selectedAircraft[pose.id] = aircraftId
        end
        renderer.modelFlight(pose.id, pose.x, pose.y, pose.height, pose.heading, aircraftId)
        renderer.flightAlpha(pose.id, pose.alpha)
        ViewpointExtractionSupportBridge.rope(
            pose.id, pose.x, pose.y, pose.ropeX, pose.ropeY, pose.groundHeight,
            pose.height, pose.ropeProgress, pose.alpha, aircraftId)
        desired[pose.id] = true
        if pose.native and pose.alpha >= 0.99 and renderer.flightReady(pose.id) then suppressNative = true end
        if pose.native then
            local distance = (pose.x - player:getX())^2 + (pose.y - player:getY())^2
            if not audioDistance or distance < audioDistance then
                audioPose, audioDistance = pose, distance
            end
        end
    end
    ViewpointExtractionSupportBridge.endRopes()
    for id in pairs(submitted) do
        if not desired[id] then renderer.removeFlight(id) end
    end
    submitted = desired
    for id in pairs(selectedAircraft) do
        if not desired[id] then selectedAircraft[id] = nil end
    end
    ViewpointExtractionSupportBridge.suppressNative(suppressNative)
    if audioPose and renderer.directional() then
        ViewpointExtractionSupportBridge.nativeAudioPosition(audioPose.x, audioPose.y, audioPose.height)
    else
        ViewpointExtractionSupportBridge.clearNativeAudioPosition()
    end
end

function Support.collect()
    local ok, err = pcall(collect)
    if not ok then
        Support.reset()
        if not warned then
            warned = true
            print("[Viewpoint Extraction Support] Could not update extraction aircraft: " .. tostring(err))
        end
    end
end

options.apply = function()
    if not enabled:getValue() then clearFlights() end
    if not showArea:getValue() and ViewpointExtractionSupportBridge then ViewpointExtractionSupportBridge.clearAreas() end
    HudVisibility.install(onlyWithInventory)
    NeatUI.sync(useNeatUI)
    if ExtractionMode.UIVisibility then ExtractionMode.UIVisibility.updateHUD() end
end

-- Submit inside the renderer's collection cycle, before it removes unseen flights.
LuaEventManager.AddEvent("OnViewpointExtractionFlights")
Events.OnViewpointExtractionFlights.Add(Support.collect)
Events.OnTick.Add(refreshAreas)
Events.OnGameStart.Add(Support.reset)
Events.OnDisconnect.Add(Support.reset)
Events.OnMainMenuEnter.Add(Support.reset)
