local Tracking = require "ExtractionModePDA/QuestTracking"
local Dashboard = {}
local sample = {}

function Dashboard.new(context)
    local view = {}
    local text, getState = context.text, context.state
    local function modeText(key, fallback, ...)
        return ExtractionMode.Localization.get("IGUI_ExtractionMode_" .. key, fallback, ...)
    end
    local function player() return getSpecificPlayer(0) end
    local function inside(data)
        return player() and data.state == ExtractionMode.Config.STATE_HIDEOUT
            and ExtractionMode.Infection.playerInsideHideout(player())
    end
    local function allowed()
        return ExtractionMode.UIVisibility.canOpen(player()) == true
    end
    local function send(command, args)
        if player() and allowed() then ExtractionMode.Client.sendCommand(player(), command, args or {}) end
    end
    local function hit(ui, rect, action)
        rect.action = action
        ui._empdaExtractionHits[#ui._empdaExtractionHits + 1] = rect
    end
    local function button(ui, pda, x, y, w, label, action, enabled, selected, style)
        style = style or {}
        local rect = { x = x, y = y, w = w, h = style.height or view.buttonH }
        local primary = style.primary and enabled ~= false
        local color = primary and pda.P.accent or selected and pda.P.buttonHover or pda.P.button
        ui:drawRect(x, y, w, rect.h, 1, color[1], color[2], color[3])
        color = selected and pda.P.accent or pda.P.edge
        ui:drawRectBorder(x, y, w, rect.h, enabled == false and 0.3 or 0.8, color[1], color[2], color[3])
        local Layout = ExtractionMode.TextLayout
        local title = Layout.fit(label, UIFont.Small, w - 18)
        local foreground = primary and pda.P.screen or pda.P.text
        if style.subtitle then
            ui:drawText(title, x + 12, y + 8, foreground[1], foreground[2], foreground[3],
                enabled == false and 0.4 or 1, UIFont.Small)
            ui:drawText(Layout.fit(style.subtitle, UIFont.Small, w - 24), x + 12, y + 10 + Layout.height(UIFont.Small),
                pda.P.muted[1], pda.P.muted[2], pda.P.muted[3], enabled == false and 0.4 or 1, UIFont.Small)
        else
            ui:drawTextCentre(title, x + w / 2, y + (rect.h - Layout.height(UIFont.Small) + 3) / 2,
                foreground[1], foreground[2], foreground[3], enabled == false and 0.4 or 1, UIFont.Small)
        end
        if enabled ~= false then hit(ui, rect, action) end
    end
    local function line(ui, pda, value, x, y, width, heading)
        local Layout = ExtractionMode.TextLayout
        local font = heading and UIFont.Medium or UIFont.Small
        local color = heading and pda.P.accent or pda.P.text
        for _, part in ipairs(Layout.wrap(value, font, width)) do
            ui:drawText(part, x, y, color[1], color[2], color[3], 1, font)
            y = y + Layout.height(font)
        end
        return y + 5
    end
    local function refreshSample(data, definition)
        local now = getTimestampMs()
        local id = definition and definition.id
        if sample.player == player() and sample.quest == id and now - (sample.at or 0) < 500 then return end
        sample = { player = player(), quest = id, at = now, gasoline = 0, counts = {} }
        if player() then
            sample.gasoline = ExtractionMode.Generator.availableGasoline(player():getInventory())
            if definition then sample.counts = ExtractionMode.Quests.requirementCounts(player(), definition.requirements or {}) end
        end
    end
    local function trackedFlow(data, definition, width)
        local api, Layout = ExtractionMode.Quests, ExtractionMode.TextLayout
        local flow = Layout.flow(width)
        flow:add(api.name(definition), UIFont.Medium)
        flow:add(api.contactDisplayName(definition.contactId))
        flow:add(api.description(definition))
        local met = api.skillRequirementsMet(player(), definition) and api.objectivesMet(data.questObjectives, definition)
        for _, objective in ipairs(definition.objectives or {}) do
            local maximum = math.max(0, tonumber(objective.amount) or 0)
            local count = math.min(maximum, api.objectiveCount(data.questObjectives, definition, objective))
            flow:add(api.label(objective) .. ": " .. count .. "/" .. maximum)
            if objective.type == "raid_visit" then
                met = met and data.raidVisitSuccessful == true
                flow:add(modeText("RaidSuccessObjective", "Raid successfully extracted") .. ": "
                    .. (data.raidVisitSuccessful == true and "1/1" or "0/1"))
            end
        end
        for index, requirement in ipairs(definition.requirements or {}) do
            local maximum = math.max(0, tonumber(requirement.amount) or 0)
            local count = tonumber(sample.counts[index]) or 0
            met = met and count >= maximum
            flow:add(api.label(requirement) .. ": " .. math.min(count, maximum) .. "/" .. maximum)
        end
        for _, requirement in ipairs(definition.skillRequirements or {}) do
            flow:add(api.label(requirement) .. ": " .. api.skillLevel(player(), requirement) .. "/" .. (requirement.level or 0))
        end
        return flow, met and inside(data)
    end
    local function measure(value)
        return getTextManager():MeasureStringX(UIFont.Small, value)
    end
    function view.bodyTop()
        local Layout = ExtractionMode.TextLayout
        view.buttonH = math.max(32, Layout.height(UIFont.Small) + 12)
        return 80 + Layout.height(UIFont.Medium) + Layout.height(UIFont.Small) + 24 + view.buttonH + 18
    end
    local function phaseLabel(data)
        local config = ExtractionMode.Config
        if data.state == config.STATE_HIDEOUT or data.state == config.STATE_COUNTDOWN then return text("AtHideout", "AT THE HIDEOUT") end
        if data.state == config.STATE_BOARDING then return text("Boarding", "BOARDING") end
        if data.state == config.STATE_EXTRACTING then return text("Extracting", "EXTRACTION IN PROGRESS") end
        return data.state and text("InRaid", "IN RAID") or text("Waiting", "Waiting for Extraction Mode state...")
    end
    local function raidThreatStatus(data)
        if data.lateRaidHordeEnabled == false then return nil end
        if tonumber(data.raidMode) == 2 and tonumber(data.hordeRemainingHours) then
            return text("MajorHordeIn", "Major horde expected in %1 in-game hours", tostring(data.hordeRemainingHours))
        end
        if data.hordeWaveMode == true and (tonumber(data.hordeWaveIndex) or 0) > 0 then
            if data.hordeWaveNextLabel then
                return text("NextWaveAt", "Next wave scheduled for %1", tostring(data.hordeWaveNextLabel))
            end
            return nil
        end
        if data.hordeSpawned == true then
            return text("RaidThreatActive", "Threat event active. No next arrival time is available.")
        end
        if data.hordeWindowImminent == true then
            return text("HordeImminent", "A horde could arrive at any moment.")
        end
        if data.hordeWindowLabel then
            return text("NextHordeAfter", "Next horde may arrive after %1", tostring(data.hordeWindowLabel))
        end
        return nil
    end
    function view.navigation(ui, pda, selected)
        local Layout, data = ExtractionMode.TextLayout, getState(0)
        local bodyTop = view.bodyTop()
        ui._empdaExtractionHits = {}
        line(ui, pda, text("DashboardTitle", "Extraction control"), 30, 80, ui.width >= 760 and ui.width - 300 or ui.width - 60, true)
        local subtitle = context.town(data) .. " | " .. (data.sharedHideout == true
            and text("SharedHideout", "Shared hideout") or text("PersonalHideout", "Personal hideout"))
        local tabsY = bodyTop - view.buttonH - 18
        line(ui, pda, subtitle, 30, 84 + Layout.height(UIFont.Medium), ui.width - 60)
        if ui.width >= 760 then
            ui:drawTextRight(phaseLabel(data), ui.width - 30, 84, pda.P.accent[1], pda.P.accent[2], pda.P.accent[3], 1, UIFont.Small)
        end
        local tabs = {{"home", text("Overview", "OVERVIEW")}, {"upgrades", text("UpgradeTab", "UPGRADES")},
            {"quests", text("Missions", "MISSIONS")}, {"barter", text("Barter", "BARTER")}, {"garage", text("GarageTab", "GARAGE")}}
        local available, total = ui.width - 36, 24
        for _, tab in ipairs(tabs) do total = total + measure(tab[2]) + 28 end
        local x, config = 18, ExtractionMode.Config
        local reference = data.state == config.STATE_RAID or data.state == config.STATE_EXTRACTING or data.state == config.STATE_BOARDING
        for _, tab in ipairs(tabs) do
            local page = tab[1]
            local width = total <= available and measure(tab[2]) + 28 or (available - 24) / #tabs
            button(ui, pda, x, tabsY, width, tab[2], function() context.navigate(page) end,
                page ~= "barter" or not reference, selected == page)
            x = x + width + 6
        end
        for _, rect in ipairs(ui._empdaExtractionHits) do rect.navigation = true end
        return bodyTop
    end
    local function panel(ui, pda, x, y, width, height)
        ui:drawRect(x, y, width, height, 1, pda.P.panel[1], pda.P.panel[2], pda.P.panel[3])
        ui:drawRectBorder(x, y, width, height, 0.8, pda.P.edge[1], pda.P.edge[2], pda.P.edge[3])
    end
    local function drawFlow(ui, pda, flow, x, y)
        for _, run in ipairs(flow.runs) do
            local color = run.warning and {1, 0.78, 0.28} or run.font == UIFont.Medium and pda.P.accent or pda.P.text
            ui:drawText(run.text, x + (run.x or 0), y + run.y, color[1], color[2], color[3], 1, run.font or UIFont.Small)
        end
    end
    local function actionRow(items, width)
        local row = {height = 0, items = {}}
        local x, y = 0, 0
        for _, item in ipairs(items) do
            local w = math.min(width, measure(item.label) + 28)
            if x > 0 and x + w > width then x, y = 0, y + view.buttonH + 8 end
            item.x, item.y, item.width = x, y, w
            row.items[#row.items + 1] = item
            x = x + w + 8
            row.height = y + view.buttonH
        end
        return row
    end
    local function drawActions(ui, pda, row, x, y)
        for _, item in ipairs(row.items) do
            button(ui, pda, x + item.x, y + item.y, item.width, item.label, item.action, item.enabled, false, {primary = item.primary})
        end
    end
    local function operationAction(data)
        local config = ExtractionMode.Config
        if data.pvpveLobby == true then
            return {label = text("Deploy", "DEPLOY"), action = function() context.open("openDeployPanel") end}
        end
        if data.state == config.STATE_HIDEOUT or data.state == config.STATE_COUNTDOWN then
            local ready, joining = data.selfReady == true, data.canJoinFactionRaid == true
            local townKey, raidKey = data.selectedTownKey, data.selectedJoinRaidKey
            local label = joining and modeText("JoinRaid", "JOIN RAID")
                or not townKey and text("NoDestination", "No destination selected")
                or data.vehicleInsertionActive == true and data.vehicleInsertionHasDriver ~= true and modeText("DriverRequired", "DRIVER REQUIRED")
                or data.canReady == false and modeText("EnterInsertionVehicle", "ENTER INSERTION VEHICLE")
                or ready and modeText("CancelReady", "CANCEL READY") or modeText("ReadyForRaid", "READY FOR RAID")
            return {label = label, enabled = townKey ~= nil and (joining or data.canReady ~= false), action = function()
                local current = getState(0)
                if current.pvpveLobby == true or (current.state ~= config.STATE_HIDEOUT and current.state ~= config.STATE_COUNTDOWN)
                    or current.selectedTownKey ~= townKey or current.selectedJoinRaidKey ~= raidKey then return end
                if joining then
                    if current.canJoinFactionRaid == true then send("JoinFactionRaid") end
                elseif current.canJoinFactionRaid ~= true and current.canReady ~= false and (current.selfReady == true) == ready then
                    send("SetReady", {ready = not ready})
                end
            end}
        end
        local hud = ExtractionMode.HUDInstance
        local currentPlayer = player()
        if not (hud and hud.action and currentPlayer) then return nil end
        hud:updateContent(data, currentPlayer)
        if not hud.action:isVisible() then return nil end
        local nativeLabel, phase = hud.action.title, data.state
        local label = nativeLabel
        if phase == config.STATE_BOARDING then
            label = currentPlayer:getVehicle() ~= nil and text("ExitVehicleToBoard", "EXIT VEHICLE TO BOARD")
                or data.boardingPendingSelf == true and text("BoardingHelicopter", "BOARDING EXTRACTION HELICOPTER...")
                or text("BoardExtraction", "BOARD EXTRACTION HELICOPTER")
        end
        return {label = label, enabled = hud.action.enable ~= false, action = function()
            local current = getState(0)
            local activePlayer = player()
            if current.state ~= phase or not activePlayer then return end
            hud:updateContent(current, activePlayer)
            if hud.action:isVisible() and hud.action.enable ~= false and hud.action.title == nativeLabel then hud:onAction() end
        end}
    end
    local function townBlocked(data, choice)
        return choice.deathBlocked == true or (choice.locationRefresh and choice.locationRefresh.blocked and not choice.activeRaidKey)
            or (choice.vehiclesBlocked == true and data.playerInVehicle == true)
    end
    function view.render(ui, pda, top)
        local data, Layout, config = getState(0), ExtractionMode.TextLayout, ExtractionMode.Config
        local left, width, bottom = 18, ui.width - 36, ui.height - 18
        local viewportH = math.max(1, bottom - top)
        local scroll = math.min(ui._empdaExtractionScroll or 0, math.max(0, (ui._empdaExtractionContentH or 0) - viewportH))
        local y, gap, pad = top - scroll, 18, 18
        local narrow = width < 760
        ui:setStencilRect(left, top, width, viewportH)
        local operationW = narrow and width or math.floor(width * 0.56)
        local contentW = operationW - 2 * pad
        local choosing = data.state == config.STATE_HIDEOUT and data.pvpveLobby ~= true
        local showTowns = (choosing or data.state == config.STATE_COUNTDOWN) and data.pvpveLobby ~= true
        local destination = Layout.flow(contentW)
        destination:add(showTowns and text("NextRaid", "NEXT RAID") or phaseLabel(data), UIFont.Medium)
        destination.y = destination.y + 10
        destination:add(text("Destination", "DESTINATION") .. ": " .. context.town(data))
        destination.y = destination.y + 12
        local towns, townRows = showTowns and data.townChoices or {}, {}
        local columns = contentW >= 320 and 2 or 1
        local townW = (contentW - 8 * (columns - 1)) / columns
        local townH = view.buttonH + Layout.height(UIFont.Small) + 4
        local townTop = destination.y
        for index, choice in ipairs(towns or {}) do
            local town = choice
            local subtitle = town.deathBlocked and text("Unavailable", "Unavailable today")
                or town.vehiclesBlocked and text("NoVehicles", "NO VEHICLES")
                or config.townSize and config.townSize(town.key, town.size) or text("MainTown", "Main town")
            if town.activeFactionRaid then subtitle = text("ActiveRaid", "ACTIVE RAID") end
            townRows[#townRows + 1] = {x = ((index - 1) % columns) * (townW + 8),
                y = townTop + math.floor((index - 1) / columns) * (townH + 8),
                title = config.townDisplayName(town.key, town.name), subtitle = subtitle,
                selected = data.selectedTownKey == town.key and tostring(data.selectedJoinRaidKey or "") == tostring(town.activeRaidKey or ""),
                enabled = choosing and not townBlocked(data, town), action = function()
                    local current = getState(0)
                    if current.state ~= config.STATE_HIDEOUT or current.pvpveLobby == true then return end
                    for _, available in ipairs(current.townChoices or {}) do
                        if available.key == town.key and tostring(available.activeRaidKey or "") == tostring(town.activeRaidKey or "") then
                            if not townBlocked(current, available) then send("SelectTown", {townKey = available.key, activeRaidKey = available.activeRaidKey}) end
                            return
                        end
                    end
                end}
        end
        destination.y = townTop + math.ceil(#townRows / columns) * (townH + 8)
        if showTowns then destination:add(text("DestinationHint", "Changing destination clears the team's ready status.")) end
        local teamW = narrow and contentW or width - operationW - 2 * pad - 1
        local team = Layout.flow(teamW)
        team:add(showTowns and text("TeamPreparation", "TEAM PREPARATION") or text("OperationStatus", "OPERATION STATUS"), UIFont.Medium)
        team.y = team.y + 8
        if showTowns then
            team:add(text("TeamReady", "%1 of %2 survivors ready", tostring(data.readyCount or 0), tostring(data.requiredCount or 1)))
            team:add(data.state == config.STATE_COUNTDOWN
                and text("DepartingIn", "Departing in %1 s", tostring(data.countdownSeconds or 0))
                or text("ReadyHint", "Deployment begins when the participants are ready."))
        else
            team:add(phaseLabel(data))
            if data.state == config.STATE_EXTRACTING or data.state == config.STATE_BOARDING then
                team:add(text("ExtractionTimer", "Extraction: %1 s", tostring(data.extractionSeconds or data.countdownSeconds or 0)))
            end
            team:add(text("RaidEndCondition", "No fixed end time. The raid ends when all participants extract or die."))
            local threatStatus = raidThreatStatus(data)
            if threatStatus then team:add(threatStatus) end
        end
        local primary = operationAction(data)
        local optOut
        if showTowns and data.canOptOut == true and data.canJoinFactionRaid ~= true then
            local opted = data.selfOptedOut == true
            optOut = {label = opted and modeText("CancelOptOut", "CANCEL OPT OUT") or modeText("OptOut", "OPT OUT"), action = function()
                local current = getState(0)
                if (current.state == config.STATE_HIDEOUT or current.state == config.STATE_COUNTDOWN) and current.canOptOut == true
                    and current.canJoinFactionRaid ~= true and (current.selfOptedOut == true) == opted then send("SetOptOut", {optedOut = not opted}) end
            end}
        end
        local actionsH = (primary and view.buttonH + 12 or 0) + (optOut and view.buttonH + 8 or 0)
        local leftH, rightH = destination.y, team.y + actionsH + 16
        local operationH = narrow and leftH + rightH + 3 * pad or math.max(180, math.max(leftH, rightH) + 2 * pad)
        panel(ui, pda, left, y, width, operationH)
        drawFlow(ui, pda, destination, left + pad, y + pad)
        for _, town in ipairs(townRows) do
            button(ui, pda, left + pad + town.x, y + pad + town.y, townW, town.title, town.action,
                town.enabled, town.selected, {height = townH, subtitle = town.subtitle})
        end
        local teamX = narrow and left + pad or left + operationW + pad
        local teamY = narrow and y + leftH + 2 * pad or y + pad
        if not narrow then ui:drawRect(left + operationW, y + pad, 1, operationH - 2 * pad, 0.7, pda.P.edge[1], pda.P.edge[2], pda.P.edge[3]) end
        drawFlow(ui, pda, team, teamX, teamY)
        local actionY = math.max(teamY + team.y + 14, y + operationH - pad - actionsH)
        if primary then
            button(ui, pda, teamX, actionY, teamW, primary.label, primary.action, primary.enabled, false, {primary = true})
            actionY = actionY + view.buttonH + 8
        end
        if optOut then button(ui, pda, teamX, actionY, teamW, optOut.label, optOut.action) end
        y = y + operationH + gap
        local tracked = Tracking.get(player(), data)
        refreshSample(data, tracked)
        local cardW = narrow and width or (width - gap) / 2
        local innerW = cardW - 2 * pad
        local generator = data.generator or {}
        local fuel, capacity = tonumber(generator.fuel) or 0, tonumber(generator.capacity) or 0
        local generation = Layout.flow(innerW)
        generation:add(text("Hideout", "HIDEOUT"), UIFont.Medium)
        generation.y = generation.y + 8
        generation:add(generator.running == true and modeText("GeneratorRunning", "RUNNING - UTILITIES ONLINE")
            or modeText("GeneratorStopped", "STOPPED - UTILITIES OFFLINE"))
        if generator.running ~= true then
            for _, run in ipairs(generation.runs) do if run.font ~= UIFont.Medium then run.warning = true end end
        end
        local barY = generation.y + 8
        generation.y = generation.y + 26
        generation:add(modeText("GeneratorTank", "Tank: %1 / %2 L    Carried gasoline: %3 L",
            string.format("%.1f", fuel), string.format("%.1f", capacity), string.format("%.1f", sample.gasoline)))
        generation:add(text("FuelHours", "Fuel remaining: %1 in-game hours", string.format("%.1f", tonumber(generator.hoursRemaining) or 0)))
        local canChange = inside(data) and data.canContributeHideout ~= false
        local function generatorAction(command)
            local current = getState(0)
            if not inside(current) or current.canContributeHideout == false then return end
            local value = current.generator or {}
            if command == "AddGeneratorFuel" then
                if (tonumber(value.fuel) or 0) >= (tonumber(value.capacity) or 0) then return end
                if ExtractionMode.Generator.availableGasoline(player():getInventory()) <= 0.0001 then return end
                send(command)
            elseif value.running == true or (tonumber(value.fuel) or 0) > 0.0001 then send(command, {running = value.running ~= true}) end
        end
        local generatorActions = actionRow({
            {label = text("Refuel", "REFUEL"), action = function() generatorAction("AddGeneratorFuel") end,
                enabled = canChange and fuel < capacity - 0.0001 and sample.gasoline > 0.0001},
            {label = generator.running == true and modeText("StopGenerator", "STOP GENERATOR") or modeText("StartGenerator", "START GENERATOR"),
                action = function() generatorAction("SetGeneratorRunning") end, enabled = canChange and (generator.running == true or fuel > 0.0001)},
            {label = text("ViewUpgrades", "VIEW UPGRADES"), action = function() context.navigate("upgrades") end},
        }, innerW)
        local nextUpgrade = Layout.flow(innerW)
        for _, definition in ipairs(ExtractionMode.Upgrades.definitions()) do
            if not (data.upgrades or {})[definition.id] then
                nextUpgrade:add(text("NextUpgrade", "Next unfinished upgrade: %1", ExtractionMode.Upgrades.name(definition)))
                break
            end
        end
        local generatorH = 2 * pad + generation.y + 12 + generatorActions.height + 16 + nextUpgrade.y
        local mission = Layout.flow(innerW)
        mission:add(text("TrackedMission", "TRACKED MISSION"), UIFont.Medium)
        mission.y = mission.y + 12
        local missionItems = {}
        if tracked then
            local progress, turnIn = trackedFlow(data, tracked, innerW)
            for _, run in ipairs(progress.runs) do run.y = run.y + mission.y; mission.runs[#mission.runs + 1] = run end
            mission.y = mission.y + progress.y
            missionItems[#missionItems + 1] = {label = text("MissionDetails", "MISSION DETAILS"), action = function() context.navigate("quests", tracked.id) end}
            missionItems[#missionItems + 1] = {label = modeText("TurnIn", "TURN IN"), enabled = turnIn, action = function()
                local current = getState(0)
                local definition = Tracking.get(player(), current)
                if not definition or definition.id ~= tracked.id then return end
                sample.at = nil
                refreshSample(current, definition)
                local _, available = trackedFlow(current, definition, innerW)
                if available then send("CompleteQuest", {questId = definition.id}) end
            end}
            missionItems[#missionItems + 1] = {label = text("Untrack", "STOP TRACKING"), action = function() Tracking.set(player(), getState(0), nil) end}
        else
            mission:add(text("NoTrackedMission", "Choose a mission to track in the Missions section."))
            missionItems[#missionItems + 1] = {label = text("ChooseMission", "CHOOSE MISSION"), action = function() context.navigate("quests") end}
        end
        if data.state == config.STATE_HIDEOUT then
            missionItems[#missionItems + 1] = {label = text("ViewBarter", "VIEW BARTER"), action = function() context.navigate("barter") end}
        end
        local missionActions = actionRow(missionItems, innerW)
        local missionH = 2 * pad + mission.y + 12 + missionActions.height
        local cardH = math.max(generatorH, missionH, 180)
        local missionX, missionY = narrow and left or left + cardW + gap, narrow and y + generatorH + gap or y
        panel(ui, pda, left, y, cardW, narrow and generatorH or cardH)
        panel(ui, pda, missionX, missionY, cardW, narrow and missionH or cardH)
        drawFlow(ui, pda, generation, left + pad, y + pad)
        ui:drawRect(left + pad, y + pad + barY, innerW, 5, 0.35, pda.P.edge[1], pda.P.edge[2], pda.P.edge[3])
        ui:drawRect(left + pad, y + pad + barY, innerW * math.max(0, math.min(1, fuel / math.max(1, capacity))), 5,
            1, pda.P.phosphor[1], pda.P.phosphor[2], pda.P.phosphor[3])
        drawActions(ui, pda, generatorActions, left + pad, y + pad + generation.y + 12)
        drawFlow(ui, pda, nextUpgrade, left + pad, y + pad + generation.y + 28 + generatorActions.height)
        drawFlow(ui, pda, mission, missionX + pad, missionY + pad)
        drawActions(ui, pda, missionActions, missionX + pad, missionY + pad + mission.y + 12)
        y = narrow and missionY + missionH + gap or y + cardH + gap
        local garage = text("OpenGarage", "OPEN GARAGE")
        local garageW = math.min(width, measure(garage) + 28)
        local countW = math.max(1, width - garageW - gap)
        local footerY = line(ui, pda, text("GarageCount", "Garage: %1 stored vehicles", tostring(#(data.garageVehicles or {}))), left, y, countW)
        local vehicle = data.activeHideoutVehicle
        if vehicle then footerY = line(ui, pda, text("GarageActive", "Vehicle outside garage: %1", vehicle.name or vehicle.scriptName or "—"), left, footerY, countW) end
        button(ui, pda, left + width - garageW, y, garageW, garage, function() context.navigate("garage") end)
        y = math.max(footerY, y + view.buttonH) + gap
        local extras = {}
        if data.hideoutSocial then extras[#extras + 1] = {"Social", "HIDEOUT / INVITATIONS", "openHideoutSocial"} end
        if data.pvpveLobby then extras[#extras + 1] = {"Deploy", "DEPLOY", "openDeployPanel"} end
        if context.admin(data) then extras[#extras + 1] = {"Admin", "ADMINISTRATION", "openAdminPanel"} end
        if data.debugEnabled then extras[#extras + 1] = {"Debug", "DEBUG", "openDebugPanel"} end
        local extraItems = {}
        for _, extra in ipairs(extras) do
            local route = extra[3]
            extraItems[#extraItems + 1] = {label = text(extra[1], extra[2]), action = function() context.open(route) end}
        end
        local extraActions = actionRow(extraItems, width)
        drawActions(ui, pda, extraActions, left, y)
        y = y + extraActions.height
        ui:clearStencilRect()
        ui._empdaExtractionContentH, ui._empdaExtractionScroll = y + scroll - top + 12, scroll
        ui._empdaExtractionViewport = {x = left, y = top, w = width, h = viewportH}
        local valid = {}
        for _, rect in ipairs(ui._empdaExtractionHits) do
            if rect.navigation or (rect.y >= top and rect.y + rect.h <= bottom) then valid[#valid + 1] = rect end
        end
        ui._empdaExtractionHits = valid
        if ui._empdaExtractionContentH > viewportH then
            ui:drawTextRight(text("ScrollHint", "Scroll to see more"), left + width - 8, bottom - Layout.height(UIFont.Small),
                pda.P.muted[1], pda.P.muted[2], pda.P.muted[3], 1, UIFont.Small)
        end
    end
    return view
end

return Dashboard
