local Dashboard = require "ExtractionModePDA/Dashboard"
local QuestTracking = require "ExtractionModePDA/QuestTracking"
local Integration = {}
local navigate
local mainPages = { openUpgradePanel = "upgrades", openQuestPanel = "quests", openGaragePanel = "garage" }

local routes = {
    {
        name = "openControllerPanel",
        title = "EMPD_ExtractionController",
        fallback = "EXTRACTION CONTROLS",
        icon = "Pin",
        resolve = function(mode) return mode.ControllerPanelInstances and mode.ControllerPanelInstances[0] end,
    },
    {
        name = "openTownPicker",
        title = "EMPD_ExtractionDestinations",
        fallback = "RAID DESTINATIONS",
        icon = "Pin",
        resolve = function(mode) return mode.TownPickerInstance end,
    },
    {
        name = "openUpgradePanel",
        title = "EMPD_HideoutUpgrades",
        fallback = "HIDEOUT UPGRADES",
        icon = "Gear",
        resolve = function(mode) return mode.UpgradePanelInstance end,
    },
    {
        name = "openQuestPanel",
        title = "EMPD_Contacts",
        fallback = "CONTACTS",
        icon = "Mail",
        resolve = function(mode) return mode.QuestPanelInstance end,
    },
    {
        name = "openHideoutSocial",
        title = "EMPD_HideoutSocial",
        fallback = "HIDEOUT / INVITATIONS",
        icon = "Contacts",
        social = true,
    },
    {
        name = "openDeployPanel",
        title = "EMPD_Deploy",
        fallback = "DEPLOYMENT",
        icon = "Contract",
        lobby = true,
    },
    {
        name = "openGaragePanel",
        title = "EMPD_Garage",
        fallback = "HIDEOUT GARAGE",
        icon = "Gear",
        resolve = function(mode) return mode.GaragePanelInstance end,
        playerObject = true,
    },
    {
        name = "openAdminPanel",
        title = "EMPD_Admin",
        fallback = "EXTRACTION ADMIN",
        icon = "Server",
        resolve = function(mode) return mode.AdminPanelInstance end,
        admin = true,
    },
    {
        name = "openAdminOperations",
        title = "EMPD_AdminOperations",
        fallback = "ADMIN OPERATIONS",
        icon = "Contract",
        admin = true,
    },
    {
        name = "openAdminTools",
        title = "EMPD_AdminTools",
        fallback = "ADMIN TOOLS",
        icon = "Gear",
        resolve = function(mode) return mode.AdminToolsInstance end,
        admin = true,
    },
    {
        name = "openDebugPanel",
        title = "EMPD_Debug",
        fallback = "EXTRACTION DEBUG",
        icon = "Danger",
        resolve = function(mode) return mode.DebugPanelInstance end,
        debug = true,
    },
    {
        name = "openRaidLocationEditor",
        title = "EMPD_RaidLocations",
        fallback = "RAID LOCATIONS",
        icon = "Pin",
        resolve = function(mode) return mode.RaidLocationEditorInstance end,
        admin = true,
    },
    {
        name = "openContentEditor",
        title = "EMPD_ContentEditor",
        fallback = "CONTENT EDITOR",
        icon = "Contract",
        resolve = function(mode) return mode.ContentEditorInstance end,
        admin = true,
    },
    {
        name = "openAdminBandits",
        title = "EMPD_BanditControls",
        fallback = "BANDIT CONTROLS",
        icon = "Danger",
        admin = true,
    },
    {
        name = "openAdminALife",
        title = "EMPD_ALifeControls",
        fallback = "A-LIFE CONTROLS",
        icon = "Danger",
        admin = true,
    },
}

local state = {
    instances = {},
    originals = {},
    pending = {},
    wrapped = {},
    attempts = 0,
    failure = nil,
    diagnostics = {},
    languageFiles = {},
    localizationHook = nil,
    getTextHook = nil,
    startTabRowsWrapper = nil,
    playerCardClampWrapper = nil,
    playerCardFrontWrapper = nil,
    playerCardPollWrapper = nil,
    playerPortraitPlaceWrapper = nil,
}

local function diagnostic(key, message)
    if state.diagnostics[key] then return end
    state.diagnostics[key] = true
    print("[Extraction Mode PDA] " .. message)
end

local syncDockedPanels

local function pack(...)
    return { n = select("#", ...), ... }
end

local function unpackArgs(args)
    return unpack(args, 1, args.n)
end

local function pdaLanguageCode()
    local ok, language = pcall(require, "PRPGE_PDALang")
    local entry = ok and language.LANGS and language.LANGS[language.index]
    return entry and entry.code or nil
end

local function readLanguageFile(code, filename, modId)
    modId = modId or "ExtractionModePDA"
    local cacheKey = modId .. ":" .. code .. "/" .. filename
    if state.languageFiles[cacheKey] then return state.languageFiles[cacheKey] end
    local ok, language = pcall(require, "PRPGE_PDALang")
    if not ok or type(language.Parse) ~= "function" or not getModFileReader then return nil end
    local read, values = pcall(function()
        local reader = getModFileReader(modId,
            "media/lua/shared/Translate/" .. code .. "/" .. filename, false)
        if not reader then return nil end
        local lines = {}
        local line = reader:readLine()
        while line do
            lines[#lines + 1] = line
            line = reader:readLine()
        end
        reader:close()
        return language.Parse(table.concat(lines, "\n"))
    end)
    if read and type(values) == "table" then
        state.languageFiles[cacheKey] = values
        return values
    end
    return nil
end

local function pdaTranslation(key, filename)
    local code = pdaLanguageCode()
    if not code then return nil end
    local function lookup(languageCode)
        local values = readLanguageFile(languageCode, filename)
        if values and values[key] then return values[key] end
        if filename == "IG_UI.json" then
            values = readLanguageFile(languageCode, filename, "ExtractionMode")
            if values and values[key] then return values[key] end
        end
    end
    local value = lookup(code)
    if value then return value end
    if code ~= "EN" then
        return lookup("EN")
    end
    return nil
end

local function formatPdaTranslation(value, ...)
    local args = { ... }
    if #args == 0 then return value end
    return (value:gsub("%%(%d)", function(index)
        local argument = args[tonumber(index)]
        return argument == nil and "%" .. index or tostring(argument)
    end):gsub("%%%%", "%%"))
end

local function translation(key, fallback)
    local value = pdaTranslation(key, "UI.json")
    if value then return value end
    if getText then
        local ok, value = pcall(getText, key)
        if ok and type(value) == "string" and value ~= key and value ~= "" then return value end
    end
    return fallback
end

local function isInside(x, y, rect)
    return rect and x >= rect.x and y >= rect.y and x < rect.x + rect.w and y < rect.y + rect.h
end

local function playerFor(number)
    return getSpecificPlayer and getSpecificPlayer(number or 0) or (getPlayer and getPlayer())
end

local function stateFor(number)
    local mode = ExtractionMode
    if mode and mode.Client and mode.Client.stateFor then
        local ok, value = pcall(mode.Client.stateFor, number or 0)
        if ok and type(value) == "table" then return value end
    end
    return mode and mode.ClientState or {}
end

local function adminControlsVisible(data)
    local options = ExtractionMode and ExtractionMode.ClientOptions
    if data.adminEnabled ~= true or not (options and options.showAdminControls) then return false end
    local ok, visible = pcall(options.showAdminControls)
    return ok and visible == true
end

local function dashboardText(key, fallback, ...)
    return formatPdaTranslation(translation("UI_ExtractionModePDA_" .. key, fallback), ...)
end

local function townName(data)
    local key = data.selectedTownKey or data.destinationTownKey
    local fallback = data.selectedTownName or data.destinationTownName
    if not key then
        return fallback or translation("UI_ExtractionModePDA_NoDestination", "No destination selected")
    end
    local config = ExtractionMode and ExtractionMode.Config
    if config and config.townDisplayName then
        local ok, name = pcall(config.townDisplayName, key, fallback or key)
        if ok and name then return tostring(name) end
    end
    return tostring(fallback or key)
end

local function windowLike(value)
    return type(value) == "table" and type(value.isVisible) == "function" and type(value.setVisible) == "function"
end

local function resolvedPanel(route)
    local value = state.instances[route.name]
    if route.resolve then
        local ok, resolved = pcall(route.resolve, ExtractionMode)
        if ok and resolved then value = resolved end
    end
    return value
end

local function instanceFor(route)
    local value = resolvedPanel(route)
    if windowLike(value) then return value end
    return nil
end

local function colorObject(color, alpha)
    return { r = color[1], g = color[2], b = color[3], a = alpha or 1 }
end

local function recolor(element, field, color)
    local old = element[field]
    if type(old) ~= "table" or old.r == nil or old.g == nil or old.b == nil then return end
    element[field] = colorObject(color, old.a)
end

local function styleWindow(root, palette)
    if not windowLike(root) then return end
    local pending = { root }
    while #pending > 0 do
        local element = table.remove(pending)
        if type(element) == "table" then
            if not element._empdaExtractionStyled then
                local isRoot = element == root
                local kind = tostring(element.Type or element.type or "")
                local isButton = kind:find("Button", 1, true) ~= nil or element.onClick ~= nil
                recolor(element, "backgroundColor", isRoot and palette.panel or isButton and palette.button or palette.row)
                recolor(element, "borderColor", palette.edge)
                if isButton then
                    recolor(element, "backgroundColorMouseOver", palette.buttonHover)
                    recolor(element, "textColor", palette.text)
                end
                element._empdaExtractionStyled = true
            end
            for _, child in pairs(element.children or {}) do pending[#pending + 1] = child end
        end
    end
end

local function panelFromResult(route, result, args)
    if windowLike(result) then return result end
    local value = instanceFor(route)
    if value then return value end
    local owner = args[1]
    if type(owner) == "table" then
        if route.name == "openAdminOperations" then return owner.operations end
        if route.name == "openAdminBandits" or route.name == "openAdminALife" then return owner.bandits end
    end
    return nil
end

local function capture(route, result, args)
    local panel = panelFromResult(route, result, args)
    if panel then
        state.instances[route.name] = panel
        if mainPages[route.name] then
            state.section = route.name == "openQuestPanel" and state.section == "barter" and "barter" or mainPages[route.name]
            panel.returnToController = false
            if route.name == "openQuestPanel" then
                QuestTracking.installPanel(panel, dashboardText)
                panel.activeTab = state.section == "barter" and "barter" or "quests"
                if state.requestedQuest then
                    panel.expandedQuestId, panel._empdaFocusQuest = state.requestedQuest, state.requestedQuest
                    state.requestedQuest = nil
                end
                panel:applyTabState()
                panel.lastLayoutKey = nil
            end
            if route.name ~= "openGaragePanel" and not panel._empdaPageLayout then
                panel._empdaPageLayout = true
                local original = panel.prerender
                panel.prerender = function(owner, ...)
                    local previous = state.viewportPanel
                    local docked = owner._pdaDock == true and state.ui.instance ~= nil
                    if docked then state.viewportPanel = owner end
                    local rect = docked and state.pda.DockRect(state.ui.instance)
                    local key = tostring(docked) .. ":" .. tostring(rect and rect.w) .. ":" .. tostring(rect and rect.h)
                        .. ":" .. tostring(pdaLanguageCode())
                    if owner._empdaPageSize ~= key then
                        owner._empdaPageSize, owner.lastLayoutKey, owner.textLayoutKey = key, nil, nil
                    end
                    local result = pack(pcall(original, owner, ...))
                    state.viewportPanel = previous
                    if not result[1] then error(result[2]) end
                    if owner.closeButton then owner.closeButton:setVisible(not docked) end
                    if docked and owner.clearISButtonB then owner:clearISButtonB() end
                    if owner.questTab then
                        owner.questTab:setVisible(not docked and owner.readOnlyRaid ~= true)
                        owner.barterTab:setVisible(not docked and owner.readOnlyRaid ~= true)
                        if docked and owner.readOnlyRaid ~= true then
                            for _, list in ipairs({owner.questList, owner.barterList}) do
                                local gained = list.y - owner.questTab.y
                                list:setY(owner.questTab.y)
                                list:setHeight(list.height + gained)
                                list:setScrollHeight(math.max(list.height, list:getScrollHeight()))
                                if list.vscroll then list.vscroll:setHeight(list.height) end
                            end
                        end
                        if docked and owner._empdaFocusQuest then
                            local y = 0
                            for _, definition in ipairs(owner:acquiredDefinitions()) do
                                if definition.id == owner._empdaFocusQuest then
                                    local maximum = math.max(0, owner.questList:getScrollHeight() - owner.questList.height)
                                    owner.questList:setYScroll(-math.min(y, maximum))
                                    break
                                end
                                y = y + owner:rowHeight(definition)
                            end
                            owner._empdaFocusQuest = nil
                        end
                    end
                    return unpack(result, 2, result.n)
                end
            end
        end
    end
    return panel
end

local function playerNumber(route, args)
    if route.playerObject then
        local player = args[1]
        if player and player.getPlayerNum then
            local ok, number = pcall(player.getPlayerNum, player)
            if ok then return tonumber(number) or 0 end
        end
        return 0
    end
    if route.name == "openAdminPanel" or route.name == "openAdminOperations"
        or route.name == "openAdminTools" or route.name == "openDebugPanel"
        or route.name == "openRaidLocationEditor" or route.name == "openContentEditor"
        or route.name == "openAdminBandits" or route.name == "openAdminALife" then
        return 0
    end
    return tonumber(args[1]) or 0
end

local function allowedToRoute(route, args)
    local mode = ExtractionMode
    local number = playerNumber(route, args)
    local player = route.playerObject and args[1] or playerFor(number)
    local visibility = mode and mode.UIVisibility
    if visibility and visibility.canOpen then
        local ok, allowed = pcall(visibility.canOpen, player or number)
        if not ok or allowed ~= true then return false end
    end
    local data = stateFor(number)
    if route.admin and not adminControlsVisible(data) then return false end
    if route.debug and data.debugEnabled ~= true then return false end
    if route.social and not data.hideoutSocial then return false end
    if route.lobby and data.pvpveLobby ~= true then return false end
    return true
end

local function pdaFor(route, args, pda, ui)
    local player = playerFor(playerNumber(route, args))
    if not player or type(ui.open) ~= "function" or type(pda.CanUse) ~= "function" then return nil end
    local instance = ui.instance
    if instance and instance._pda and pda.KeepOpen and pda.KeepOpen(player) then
        pda.Tab = "extraction"
        return instance
    end

    local ok, allowed = pcall(pda.CanUse, player)
    if not ok or allowed ~= true then return nil end

    local opened, result = pcall(ui.open, player)
    if not opened or result == false then return nil end
    instance = ui.instance or (windowLike(result) and result or nil)
    if not instance then return nil end
    pda.Tab = "extraction"
    return instance
end

local function runOriginal(route, original, args, pda, ui)
    local ok, result = pcall(original, unpackArgs(args))
    if not ok then error(result) end
    local panel = capture(route, result, args)
    if panel and ui.instance and pda.DockTick then
        local docked, active = pcall(pda.DockTick, ui.instance)
        if docked then
            for _, window in ipairs(active or {}) do styleWindow(window, pda.P) end
        end
    end
    return result
end

local function invoke(routeName, args)
    local original = state.originals[routeName]
    local route
    for _, candidate in ipairs(routes) do
        if candidate.name == routeName then route = candidate; break end
    end
    if not original or not route then return end
    diagnostic("route-requested:" .. routeName, "Extraction Mode screen requested: " .. routeName)
    if not allowedToRoute(route, args) then
        diagnostic("route-denied:" .. routeName,
            "Existing Extraction Mode permissions kept " .. routeName .. " in its native UI")
        return original(unpackArgs(args))
    end
    local pda = state.pda
    local ui = state.ui
    local instance = pdaFor(route, args, pda, ui)
    if not instance then
        diagnostic("route-unavailable:" .. routeName,
            "PDA unavailable for " .. routeName .. "; opening its native UI")
        return original(unpackArgs(args))
    end
    if routeName == "openControllerPanel" then return navigate("home") end
    if instance._pda and instance._pda.phase == "ready" then
        diagnostic("route-docked:" .. routeName, routeName .. " opened through the PDA")
        return runOriginal(route, original, args, pda, ui)
    end
    state.pending[#state.pending + 1] = {
        route = route, original = original, args = args, requestedAt = getTimestampMs and getTimestampMs() or 0,
    }
end

navigate = function(page, questId)
    local pda, ui = state.pda, state.ui.instance
    if not ui then return end
    local data, config = stateFor(0), ExtractionMode.Config
    if page == "barter" and (data.state == config.STATE_RAID or data.state == config.STATE_EXTRACTING
        or data.state == config.STATE_BOARDING) then return end
    local top = ui._pdaTop
    if (page == "quests" or page == "barter") and top and top == ExtractionMode.QuestPanelInstance then
        state.section = page
        top.activeTab = page == "barter" and "barter" or "quests"
        if questId then top.expandedQuestId, top._empdaFocusQuest = questId, questId end
        top:applyTabState()
        top:layoutRows(false)
        if page == "barter" then top:layoutBarterRows(true) end
        return
    end
    for _ = 1, #routes do
        top = ui._pdaTop
        local info = top and pda._docked[top]
        if not (info and info.entry._extractionModePDA) then break end
        top.returnToController = false
        pda.Back(ui)
    end
    pda.Tab, state.section = "extraction", page
    ui._empdaExtractionScroll = 0
    if page == "home" then return end
    state.requestedQuest = questId
    local route = page == "upgrades" and "openUpgradePanel"
        or (page == "quests" or page == "barter") and "openQuestPanel" or "openGaragePanel"
    if page == "garage" and playerFor(0) and ExtractionMode.Client then
        ExtractionMode.Client.sendCommand(playerFor(0), "RequestState", {})
    end
    local args = page == "garage" and pack(playerFor(0), true) or pack(0, false)
    return invoke(route, args)
end

local function installRoute(route)
    local mode = ExtractionMode
    if type(mode[route.name]) ~= "function" or state.originals[route.name] then return end
    local original = mode[route.name]
    state.originals[route.name] = original
    local function makeWrapper(name)
        return function(...) return invoke(name, pack(...)) end
    end
    mode[route.name] = makeWrapper(route.name)
end

local function dockEntry(route)
    return {
        get = function() return resolvedPanel(route) end,
        key = route.title,
        fallback = route.fallback,
        icon = route.icon,
        fill = route.name == "openUpgradePanel" or route.name == "openQuestPanel",
        _extractionModePDA = route.name,
    }
end

local function installRoutes()
    local count = 0
    for _, route in ipairs(routes) do
        installRoute(route)
        if state.originals[route.name] and not state.wrapped[route.name] then
            local entry = dockEntry(route)
            local found = false
            for _, existing in ipairs(state.pda.DOCK) do
                if existing._extractionModePDA == route.name then found = true; break end
            end
            if not found then state.pda.DOCK[#state.pda.DOCK + 1] = entry end
            state.wrapped[route.name] = true
        end
        if state.originals[route.name] then count = count + 1 end
    end
    return count
end

local tabIcons = {
    home = "TabHome", tree = "TabTree", danger = "Danger", ops = "Contract",
    traders = "Trader", contacts = "Mail", bank = "Bank", settings = "Gear",
    extraction = "Pin",
}

local function tabLabel(rect, pda, localization, ui)
    if rect.id == "extraction" then
        return translation("UI_ExtractionModePDA_Tab", "EXTRACTION")
    end
    if rect.id == "screen" then
        local title = pda.ScreenTitle and pda.ScreenTitle(ui)
        return title or "SCREEN"
    end
    if localization and localization.Get and rect.key then
        local ok, value = pcall(localization.Get, rect.key)
        if ok and value then return tostring(value) end
    end
    return tostring(rect.key or rect.id)
end

local function drawTab(ui, rect, label, icon, active, pda, iconsOnly)
    local mx = getMouseX() - ui:getAbsoluteX()
    local my = getMouseY() - ui:getAbsoluteY()
    local hover = isInside(mx, my, rect)
    local palette = pda.P
    local fill = active and palette.buttonHover or hover and palette.button or palette.screen
    ui:drawRect(rect.x, rect.y, rect.w, rect.h, 1, fill[1], fill[2], fill[3])
    ui:drawRectBorder(rect.x, rect.y, rect.w, rect.h, hover and 0.9 or 0.55,
        palette.edge[1], palette.edge[2], palette.edge[3])
    if active then
        ui:drawRect(rect.x + 6, rect.y + rect.h - 4, rect.w - 12, 3, 1,
            palette.phosphor[1], palette.phosphor[2], palette.phosphor[3])
    end

    local textureName = icon or tabIcons[rect.id]
    local texture = textureName and getTexture("media/ui/RPGSkillTreeExpanded/PRPGE_UI_Info" .. textureName .. ".png")
    local iconSize = math.min(16, rect.h - 8, rect.w - 8)
    local textX = rect.x + 10
    if texture and iconSize > 0 then
        local centerIcon = iconsOnly or rect.id == "settings"
        local iconX = centerIcon and rect.x + (rect.w - iconSize) / 2 or rect.x + 9
        ui:drawTextureScaled(texture, iconX, rect.y + (rect.h - iconSize) / 2 - 1,
            iconSize, iconSize, 1, palette.accent[1], palette.accent[2], palette.accent[3])
        if not iconsOnly and rect.id ~= "settings" then textX = rect.x + 31 end
    end

    if not iconsOnly and rect.id ~= "settings" then
        local manager = getTextManager()
        local available = rect.x + rect.w - 8 - textX
        local width = manager:MeasureStringX(UIFont.Small, label)
        local scale = math.min(1, available / math.max(1, width))
        local height = manager:MeasureStringY(UIFont.Small, "Ag") * scale
        local color = active and palette.accent or palette.muted
        ui:drawTextZoomed(label, textX, rect.y + (rect.h - height) / 2,
            scale, color[1], color[2], color[3], 1, UIFont.Small)
    end
    if rect.news then
        ui:drawRect(rect.x + 3, rect.y + 3, 7, 7, 1, 1, 0.22, 0.22)
    end
    if rect.badge and rect.badge ~= "" then
        ui:drawText(rect.badge, rect.x + rect.w - 22, rect.y + 2,
            palette.phosphor[1], palette.phosphor[2], palette.phosphor[3], 1, UIFont.Small)
    end
end

local function addExtractionTab(ui, pda)
    local tabRects = ui._tabRects
    if type(tabRects) ~= "table" then return false end
    local tabs = {}
    local extractionTab = { id = "extraction", key = "TabHome" }
    for _, rect in ipairs(tabRects) do
        if rect.id ~= "extraction" then tabs[#tabs + 1] = rect end
        if rect.id == "extraction" then extractionTab = rect end
    end
    local inserted = false
    for index, rect in ipairs(tabs) do
        if rect.id == "home" then
            table.insert(tabs, index + 1, extractionTab)
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(tabs, math.min(2, #tabs + 1), extractionTab)
    end
    local controls = pda.Controls(ui)
    local maxRight = controls and controls[3] and controls[3].x - 14
    if not maxRight then return false end

    local localizationOk, localization = pcall(require, "PRPGE_Localization")
    if not localizationOk then localization = nil end
    local labels, named = {}, {}
    for index, rect in ipairs(tabs) do
        labels[index] = tabLabel(rect, pda, localization, ui)
        if rect.id ~= "settings" then named[#named + 1] = labels[index] end
    end

    local left, top, height, gap = 20, 12, 42, 6
    local settingsWidth = 46
    local tabWidth = math.floor((maxRight - left - ( #tabs - 1) * gap - settingsWidth)
        / math.max(1, #tabs - 1))
    local manager = getTextManager()
    local scale = 1
    for _, label in ipairs(named) do
        local width = manager:MeasureStringX(UIFont.Small, label)
        scale = math.min(scale, (tabWidth - 42) / math.max(1, width))
    end
    local iconsOnly = scale < 0.62 or tabWidth < 60
    if iconsOnly then
        tabWidth = math.floor((maxRight - left - (#tabs - 1) * gap) / #tabs)
        settingsWidth = tabWidth
    else
        scale = math.min(1, scale)
    end
    ui._tabMode = iconsOnly and "icons" or "small"
    ui._tabScale = scale

    ui:drawRect(left, top, maxRight - left, height, 1,
        pda.P.screen[1], pda.P.screen[2], pda.P.screen[3])
    local x = left
    local pageActive = pda.DockActive(ui)
    local activeTabRects = {}
    for index, rect in ipairs(tabs) do
        local width = rect.id == "settings" and settingsWidth or tabWidth
        local placed = {
            x = x, y = top, w = width, h = height,
            id = rect.id, key = rect.id == "extraction" and "TabHome" or rect.key,
            badge = rect.badge, news = rect.news,
        }
        local active = rect.id == "screen" and pageActive
            or not pageActive and pda.Tab == rect.id
        local icon = rect.id == "screen" and select(2, pda.ScreenTitle(ui)) or nil
        if rect.id == "extraction" then ui._empdaExtractionTabRect = placed end
        drawTab(ui, placed, labels[index], icon, active, pda, iconsOnly)
        activeTabRects[#activeTabRects + 1] = placed
        x = x + width + gap
    end
    ui._tabRects = activeTabRects
    ui._tabsRight = x - gap
    return true
end

local function installPageHooks(ui, pda)
    if ui.render ~= state.renderWrapper then
        local oldRender = ui.render
        state.renderWrapper = function(owner, ...)
            local result = pack(oldRender(owner, ...))
            local added = addExtractionTab(owner, pda)
            if added then
                diagnostic("tab-rendered", "Extraction tab rendered in PDA navigation")
            else
                diagnostic("tab-missing", "PDA could not add the Extraction tab to its navigation")
            end
            if pda.Tab == "extraction" then
                local info = owner._pdaTop and pda._docked[owner._pdaTop]
                if not pda.DockActive(owner) or (info and mainPages[info.entry._extractionModePDA]) then
                    local page = pda.DockActive(owner) and state.section or "home"
                    local top = state.dashboard.navigation(owner, pda, page)
                    if page == "home" then state.dashboard.render(owner, pda, top) end
                else
                    owner._empdaExtractionHits = {}
                end
            end
            if syncDockedPanels then syncDockedPanels(owner) end
            return unpackArgs(result)
        end
        ui.render = state.renderWrapper
    end
    if ui.onMouseDown ~= state.downWrapper then
        local oldDown = ui.onMouseDown
        state.downWrapper = function(owner, x, y, ...)
            owner._empdaExtractionPressed = nil
            owner._empdaExtractionTabPressed = nil
            local tab = owner._empdaExtractionTabRect
            if tab and isInside(x, y, tab) then
                owner._empdaExtractionTabPressed = true
                if pda.DockActive(owner) then pda.Back(owner) end
                if pda.Tab ~= "extraction" then
                    pda.Tab = "extraction"
                    if pda.Sound then pda.Sound("Key") end
                    pda.Transition(owner, translation("UI_ExtractionModePDA_Tab", "EXTRACTION"))
                end
                return true
            end
            if pda.Tab == "extraction" then
                for _, rect in ipairs(owner._empdaExtractionHits or {}) do
                    if isInside(x, y, rect) then
                        owner._empdaExtractionPressed = rect
                        if pda.Sound then pda.Sound("Key") end
                        return true
                    end
                end
            end
            return oldDown(owner, x, y, ...)
        end
        ui.onMouseDown = state.downWrapper
    end
    if ui.onMouseUp ~= state.upWrapper then
        local oldUp = ui.onMouseUp
        state.upWrapper = function(owner, x, y, ...)
            local tabPressed = owner._empdaExtractionTabPressed
            owner._empdaExtractionTabPressed = nil
            if tabPressed then return true end
            local pressed = owner._empdaExtractionPressed
            owner._empdaExtractionPressed = nil
            if pressed then
                if pda.Tab == "extraction" and isInside(x, y, pressed) and pressed.action then pressed.action() end
                return true
            end
            return oldUp(owner, x, y, ...)
        end
        ui.onMouseUp = state.upWrapper
    end
    if ui.onMouseWheel ~= state.wheelWrapper then
        local oldWheel = ui.onMouseWheel
        state.wheelWrapper = function(owner, delta, ...)
            if pda.Tab == "extraction" and not pda.DockActive(owner) then
                local rect = owner._empdaExtractionViewport
                local x, y = getMouseX() - owner:getAbsoluteX(), getMouseY() - owner:getAbsoluteY()
                if isInside(x, y, rect) then
                    local maximum = math.max(0, (owner._empdaExtractionContentH or 0) - rect.h)
                    owner._empdaExtractionScroll = math.max(0, math.min(maximum, (owner._empdaExtractionScroll or 0) - delta * 42))
                    return true
                end
            end
            if oldWheel then return oldWheel(owner, delta, ...) end
        end
        ui.onMouseWheel = state.wheelWrapper
    end
    state.pageHooksInstalled = true
    return true
end

local function installDockSkin(pda)
    local originalViewport = ExtractionMode.TextLayout.viewport
    -- Only the docked panel's layout uses PDA dimensions; other native menus keep their viewport.
    ExtractionMode.TextLayout.viewport = function(playerNum, ...)
        local panel = state.viewportPanel
        if panel and panel._pdaDock and panel.playerNum == playerNum and state.ui.instance then
            local rect = pda.DockRect(state.ui.instance)
            return rect.w, rect.h
        end
        return originalViewport(playerNum, ...)
    end
    local originalRect, originalScreen = pda.DockRect, pda.DrawScreen
    local function mainPage(ui)
        local info = ui and ui._pdaTop and pda._docked[ui._pdaTop]
        return info and mainPages[info.entry._extractionModePDA] ~= nil
    end
    pda.DockRect = function(ui)
        local rect = originalRect(ui)
        if mainPage(ui) then
            local top = state.dashboard.bodyTop()
            rect.h, rect.y = rect.h - (top - rect.y), top
        end
        return rect
    end
    pda.DrawScreen = function(ui, ...)
        if not mainPage(ui) then return originalScreen(ui, ...) end
        ui._backRect = nil
        local rect = pda.DockRect(ui)
        pda.Panel(ui, rect.x, rect.y, rect.w, rect.h, pda.P.edge)
    end
    local oldDockTick = pda.DockTick
    pda.DockTick = function(ui, ...)
        local active = oldDockTick(ui, ...)
        for _, window in ipairs(active or {}) do styleWindow(window, pda.P) end
        return active
    end
end

syncDockedPanels = function(liveInstance)
    local ui, pda = state.ui, state.pda
    local instance = liveInstance or ui and ui.instance
    if not instance or not instance._pda then return end
    if instance._pda.phase ~= "ready" then
        diagnostic("dock-phase:" .. tostring(instance._pda.phase),
            "PDA docking monitor waiting for ready state; phase=" .. tostring(instance._pda.phase))
        return
    end

    local visiblePanels = {}
    for _, route in ipairs(routes) do
        local panel = resolvedPanel(route)
        if panel then
            local ok, visible = pcall(function() return panel:isVisible() end)
            if route.name == "openControllerPanel" then
                diagnostic("controller-panel-probe",
                    "Controller panel probe: visibleCall=" .. tostring(ok)
                    .. ", visible=" .. tostring(visible)
                    .. ", javaObject=" .. tostring(panel.javaObject ~= nil))
            end
            if ok and visible then visiblePanels[#visiblePanels + 1] = { route = route, panel = panel } end
        end
    end

    local active = instance._pdaDocked or {}
    if #visiblePanels == 0 and pda.Tab == "extraction" then
        local now = getTimestampMs and getTimestampMs() or 0
        if now >= (state.nextDockProbe or 0) then
            state.nextDockProbe = now + 5000
            print("[Extraction Mode PDA] Dock probe found no visible registered Extraction Mode panels; active PDA pages="
                .. tostring(#(active or {})))
        end
    end
    for _, entry in ipairs(visiblePanels) do
        if entry.panel._pdaDock then
            diagnostic("panel-docked:" .. entry.route.name,
                entry.route.name .. " was moved into the PDA")
        else
            local reason = entry.panel.javaObject and "PDA did not accept the visible panel" or "panel has no Java UI object"
            diagnostic("panel-undocked:" .. entry.route.name,
                entry.route.name .. " remains in its native UI: " .. reason)
        end
    end
end

local function hookReady(pda, ui)
    if type(pda) ~= "table" or type(ui) ~= "table" or type(ui.render) ~= "function"
        or type(ui.onMouseDown) ~= "function" or type(ui.onMouseUp) ~= "function"
        or type(ui.open) ~= "function" or type(pda.DOCK) ~= "table" or type(pda.P) ~= "table"
        or type(pda.Panel) ~= "function" or type(pda.DockTick) ~= "function"
        or type(pda.CanUse) ~= "function" or type(pda.KeepOpen) ~= "function"
        or type(pda.DockActive) ~= "function" then
        return "required ProjectRPGExpanded PDA methods are missing"
    end
    if type(pda.Back) ~= "function" or type(pda.Transition) ~= "function"
        or type(pda.Controls) ~= "function" or type(pda.ScreenTitle) ~= "function"
        or type(pda.DockRect) ~= "function" or type(pda.TransitionActive) ~= "function"
        or type(pda.DrawScreen) ~= "function"
        or type(pda._docked) ~= "table" then
        return "required ProjectRPGExpanded navigation methods are missing"
    end
    local layout = ExtractionMode and ExtractionMode.TextLayout
    if not layout or type(layout.viewport) ~= "function" then return "Extraction Mode text layout is unavailable" end
    return nil
end

local function installHUDVisibility()
    local visibility = ExtractionMode and ExtractionMode.UIVisibility
    if not visibility or type(visibility.updateHUD) ~= "function" then return end
    local original = visibility.updateHUD
    visibility.updateHUD = function(...)
        local result = original(...)
        local hud = ExtractionMode.HUDInstance
        if hud then hud:setVisible(false) end
        return result
    end
    visibility.updateHUD()
end

local function installExtractionModeLocalization()
    local localization = ExtractionMode and ExtractionMode.Localization
    if not localization or type(localization.get) ~= "function" or state.localizationHook then return end
    local original = localization.get
    state.localizationHook = function(key, fallback, ...)
        local value = pdaTranslation(key, "IG_UI.json")
        if value then return formatPdaTranslation(value, ...) end
        return original(key, fallback, ...)
    end
    localization.get = state.localizationHook

    if getText and getText ~= state.getTextHook then
        local originalGetText = getText
        state.getTextHook = function(key, ...)
            if type(key) == "string" and key:sub(1, 14) == "UI_PRPGE_EMPD_" then
                local value = pdaTranslation(key, "UI.json")
                if value then return formatPdaTranslation(value, ...) end
            end
            return originalGetText(key, ...)
        end
        getText = state.getTextHook
    end
end

local function installExtractionStartTab(pda)
    if type(pda.START_TABS) == "table" then
        pda.START_TABS[4] = "extraction"
    end

    local ok, settings = pcall(require, "PRPGE_PDASettings")
    if not ok or type(settings) ~= "table" or type(settings.PDARows) ~= "function" then
        diagnostic("start-tab-settings", "PDA start-tab setting is unavailable")
        return false
    end
    if settings.PDARows == state.startTabRowsWrapper then return true end

    local originalRows = settings.PDARows
    state.startTabRowsWrapper = function(...)
        local rows = originalRows(...)
        for _, row in ipairs(rows or {}) do
            if row.id == "starttab" and type(row.choices) == "table" then
                local extractionChoice
                for _, choice in ipairs(row.choices) do
                    if choice[1] == 4 then extractionChoice = choice end
                end
                if extractionChoice then
                    extractionChoice[2], extractionChoice.icon = "", "Pin"
                else
                    local insertAt = #row.choices + 1
                    for index, choice in ipairs(row.choices) do
                        if choice[1] == 0 then insertAt = index; break end
                    end
                    table.insert(row.choices, insertAt, {4, "", icon = "Pin"})
                end
            end
        end
        return rows
    end
    settings.PDARows = state.startTabRowsWrapper
    if settings.Rows == originalRows then settings.Rows = state.startTabRowsWrapper end
    return true
end

local function installPlayerCardCompatibility()
    local ok, playerCard = pcall(require, "PRPGE_PlayerCard")
    if not ok or type(playerCard) ~= "table" then return false end

    local portraitOk, portrait = pcall(require, "PRPGE_Portrait")
    if portraitOk and type(portrait) == "table"
        and type(portrait.Place) == "function"
        and portrait.Place ~= state.playerPortraitPlaceWrapper then
        local originalPlace = portrait.Place
        state.playerPortraitPlaceWrapper = function(model, owner, ...)
            if not playerCard.card or owner ~= playerCard.card then
                return originalPlace(model, owner, ...)
            end

            local map = ISWorldMap_instance
            local mapOpen = false
            if map and type(map.isVisible) == "function" then
                local visibleOk, visible = pcall(map.isVisible, map)
                mapOpen = visibleOk and visible == true
            end

            if mapOpen then
                if model and type(model.setVisible) == "function" then
                    pcall(model.setVisible, model, false)
                end
                diagnostic("player-card-map-portrait-hidden", "Temporarily hiding the ProjectRPGExpanded portrait while the world map is open")
                return false
            end

            return originalPlace(model, owner, ...)
        end
        portrait.Place = state.playerPortraitPlaceWrapper
        diagnostic("player-card-map-portrait-installed", "Installed world-map compatibility for the ProjectRPGExpanded portrait")
    end

    local inventoryWindows = {
        "ErgUIPanel", "ErgUIClusterFrame", "ErgUIBarVisPopup", "ErgUITypeWindow",
        "ErgUISettings", "ErgUIReleaseNotesWindow", "ErgUIQuantityPicker",
    }
    if type(playerCard.WINDOWS) == "table" then
        for _, name in ipairs(inventoryWindows) do
            local found = false
            for _, existing in ipairs(playerCard.WINDOWS) do
                if existing == name then found = true; break end
            end
            if not found then playerCard.WINDOWS[#playerCard.WINDOWS + 1] = name end
        end
    end

    local function overlappingErgonomicWindows(card)
        if not (UIManager and UIManager.getUI and card and card.javaObject) then return nil end
        local listOk, list = pcall(function() return UIManager.getUI() end)
        if not listOk or not list then return nil end

        local cardOk, x, y, width, height = pcall(function()
            return card:getAbsoluteX(), card:getAbsoluteY(), card:getWidth(), card:getHeight()
        end)
        if not cardOk then return nil end

        local windows, seen = {}, {}
        local function addWindow(element)
            local javaObject = element and element.javaObject
            if not element or not javaObject or seen[javaObject] then return end
            seen[javaObject] = true

            local visibleOk, visible = pcall(function() return element:isVisible() end)
            if not visibleOk or not visible then return end
            local index = list:indexOf(javaObject)
            if index < 0 then return end

            local boundsOk, left, top, elementWidth, elementHeight = pcall(function()
                return element:getAbsoluteX(), element:getAbsoluteY(), element:getWidth(), element:getHeight()
            end)
            if boundsOk and x < left + elementWidth and left < x + width
                and y < top + elementHeight and top < y + height then
                windows[#windows + 1] = {
                    index = index,
                    javaObject = javaObject,
                    x = left,
                    y = top,
                    width = elementWidth,
                    height = elementHeight,
                }
            end
        end

        local host = ErgonomicUI and ErgonomicUI.panel
        addWindow(host)
        for _, frame in pairs(host and host._frames or {}) do addWindow(frame) end
        for _, name in ipairs(inventoryWindows) do
            local class = _G[name]
            addWindow(class and class.instance)
        end
        return list, windows
    end

    local function keepPlayerCardBehindErgonomicUI(card)
        local list, windows = overlappingErgonomicWindows(card)
        if not list or #windows == 0 then return windows end

        local firstWindow = windows[1]
        for _, window in ipairs(windows) do
            if window.index < firstWindow.index then firstWindow = window end
        end

        local parts = {card, card.portrait, card.levelBadge}
        local entries, entryByPart, highestIndex = {}, {}, -1
        for _, part in ipairs(parts) do
            local javaObject = part and part.javaObject
            if javaObject then
                local index = list:indexOf(javaObject)
                if index >= 0 then
                    local entry = {index = index, javaObject = javaObject}
                    entries[#entries + 1] = entry
                    entryByPart[part] = entry
                    highestIndex = math.max(highestIndex, index)
                end
            end
        end
        if highestIndex <= firstWindow.index then return windows end

        local removalOrder = {}
        for _, entry in ipairs(entries) do removalOrder[#removalOrder + 1] = entry end
        table.sort(removalOrder, function(a, b) return a.index > b.index end)

        local reordered = pcall(function()
            for _, entry in ipairs(removalOrder) do list:remove(entry.index) end

            local insertAt = list:indexOf(firstWindow.javaObject)
            if insertAt < 0 then error("Ergonomic UI window left the UI stack") end
            for _, part in ipairs(parts) do
                local entry = entryByPart[part]
                if entry then
                    list:add(insertAt, entry.javaObject)
                    insertAt = insertAt + 1
                end
            end
        end)

        if not reordered then
            diagnostic("player-card-ergonomic-order", "Could not reorder the ProjectRPGExpanded HUD below Ergonomic UI")
            pcall(function()
                for _, entry in ipairs(entries) do
                    if list:indexOf(entry.javaObject) < 0 then
                        list:add(math.min(entry.index, list:size()), entry.javaObject)
                    end
                end
            end)
        else
            diagnostic("player-card-ergonomic-order", "Layered the ProjectRPGExpanded HUD below Ergonomic UI")
        end
        return windows
    end

    local function safelyKeepPlayerCardBehindErgonomicUI(card)
        local ok, windows = pcall(keepPlayerCardBehindErgonomicUI, card)
        if not ok then
            diagnostic("player-card-ergonomic-error", "HUD layering compatibility failed: " .. tostring(windows))
            return nil
        end
        if windows and #windows > 0 then
            diagnostic("player-card-ergonomic-detected", "Detected Ergonomic UI window(s) overlapping the ProjectRPGExpanded HUD")
        end
        return windows
    end

    local function pointerOverErgonomicWindow(windows)
        if not windows or not getMouseX or not getMouseY then return false end
        local x, y = getMouseX(), getMouseY()
        for _, window in ipairs(windows) do
            if x >= window.x and y >= window.y
                and x < window.x + window.width and y < window.y + window.height then
                return true
            end
        end
        return false
    end

    local function syncPlayerCardVisibility(card, overlapsInventory)
        if overlapsInventory then
            card._empdaErgonomicHidden = true
            if card:isVisible() then card:setVisible(false) end
            if card.portrait and card.portrait:isVisible() then card.portrait:setVisible(false) end
            if card.levelBadge and card.levelBadge:isVisible() then card.levelBadge:setVisible(false) end
        elseif card._empdaErgonomicHidden then
            card._empdaErgonomicHidden = nil
            if card._shown then card:setVisible(true) end
        end
    end

    if type(playerCard.Clamp) == "function" and playerCard.Clamp ~= state.playerCardClampWrapper then
        local originalClamp = playerCard.Clamp
        state.playerCardClampWrapper = function(card, ...)
            local requestedY = card and tonumber(card.y)
            local result = originalClamp(card, ...)
            if requestedY and card and card.setY and type(playerCard.Screen) == "function" then
                local screenOk, _, screenHeight = pcall(playerCard.Screen)
                screenHeight = screenOk and tonumber(screenHeight)
                if screenHeight and tonumber(card.height) then
                    local maxY = math.max(0, screenHeight - card.height - 4)
                    local y = math.max(0, math.min(requestedY, maxY))
                    if card.y ~= y then card:setY(y) end
                end
            end
            return result
        end
        playerCard.Clamp = state.playerCardClampWrapper
    end

    if type(playerCard.Front) == "function" and playerCard.Front ~= state.playerCardFrontWrapper then
        local originalFront = playerCard.Front
        state.playerCardFrontWrapper = function(card, ...)
            local windows = safelyKeepPlayerCardBehindErgonomicUI(card)
            if windows and #windows > 0 then return false end
            return originalFront(card, ...)
        end
        playerCard.Front = state.playerCardFrontWrapper
    end

    if type(playerCard.Poll) == "function" and playerCard.Poll ~= state.playerCardPollWrapper then
        local originalPoll = playerCard.Poll
        state.playerCardPollWrapper = function(card, ...)
            local windows = safelyKeepPlayerCardBehindErgonomicUI(card)
            local overlapsInventory = windows and #windows > 0
            syncPlayerCardVisibility(card, overlapsInventory)
            if overlapsInventory then
                diagnostic("player-card-ergonomic-hidden", "Temporarily hiding the ProjectRPGExpanded HUD where it overlaps Ergonomic UI")
            end
            if pointerOverErgonomicWindow(windows) then return false end
            return originalPoll(card, ...)
        end
        playerCard.Poll = state.playerCardPollWrapper
        diagnostic("player-card-ergonomic-installed", "Installed ProjectRPGExpanded HUD compatibility for Ergonomic UI")
    end
    return true
end

function Integration.install()
    if state.installed then return true end
    local ok, pda = pcall(require, "PRPGE_PDA")
    if not ok then state.failure = "could not load PRPGE_PDA: " .. tostring(pda); return false end
    if type(RPGSkillTreeUI) ~= "table" then
        state.failure = "RPGSkillTreeUI is unavailable"
        return false
    end
    local ui = RPGSkillTreeUI
    local failure = hookReady(pda, ui)
    if failure then state.failure = failure; return false end
    state.pda, state.ui = pda, ui
    installExtractionStartTab(pda)
    installPlayerCardCompatibility()
    state.dashboard = Dashboard.new({text = dashboardText, state = stateFor, town = townName,
        admin = adminControlsVisible, navigate = navigate,
        open = function(name) return invoke(name, pack(0)) end})
    if not installPageHooks(ui, pda) then
        state.failure = "could not hook the PDA render and input methods"
        return false
    end
    installDockSkin(pda)
    installHUDVisibility()
    installExtractionModeLocalization()
    local routeCount = installRoutes()
    state.installed = true
    state.failure = nil
    print("[Extraction Mode PDA] ProjectRPGExpanded PDA integration active; routed "
        .. tostring(routeCount) .. " Extraction Mode screens; native HUD disabled")
    return true
end

local function tick()
    if not state.installed then
        state.attempts = state.attempts + 1
        if state.attempts % 30 == 0 then
            local installed = Integration.install()
            if not installed and state.attempts >= 120 then
                print("[Extraction Mode PDA] ProjectRPGExpanded PDA integration unavailable: "
                    .. tostring(state.failure or "unknown compatibility error"))
                if Events and Events.OnTick and Events.OnTick.Remove then Events.OnTick.Remove(tick) end
                return
            end
        end
    else
        installPageHooks(state.ui, state.pda)
        syncDockedPanels()
    end

    local ui, pda = state.ui, state.pda
    if not ui or not pda or #state.pending == 0 then return end
    local now = getTimestampMs and getTimestampMs() or 0
    local remaining = {}
    for _, pending in ipairs(state.pending) do
        local instance = ui.instance
        if instance and instance._pda and instance._pda.phase == "ready" then
            pda.Tab = "extraction"
            runOriginal(pending.route, pending.original, pending.args, pda, ui)
        elseif now - pending.requestedAt > 8000 then
            pending.original(unpackArgs(pending.args))
        else
            remaining[#remaining + 1] = pending
        end
    end
    state.pending = remaining
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(Integration.install) end
if Events and Events.OnTick then Events.OnTick.Add(tick) end

return Integration
