local Integration = {}

local routes = {
    {
        name = "openControllerPanel",
        title = "VES_ExtractionController",
        fallback = "EXTRACTION CONTROLS",
        icon = "Pin",
        resolve = function(mode) return mode.ControllerPanelInstances and mode.ControllerPanelInstances[0] end,
    },
    {
        name = "openTownPicker",
        title = "VES_ExtractionDestinations",
        fallback = "RAID DESTINATIONS",
        icon = "Pin",
        resolve = function(mode) return mode.TownPickerInstance end,
    },
    {
        name = "openUpgradePanel",
        title = "VES_HideoutUpgrades",
        fallback = "HIDEOUT UPGRADES",
        icon = "Gear",
        resolve = function(mode) return mode.UpgradePanelInstance end,
    },
    {
        name = "openQuestPanel",
        title = "VES_Contacts",
        fallback = "CONTACTS",
        icon = "Mail",
        resolve = function(mode) return mode.QuestPanelInstance end,
    },
    {
        name = "openHideoutSocial",
        title = "VES_HideoutSocial",
        fallback = "HIDEOUT / INVITATIONS",
        icon = "Contacts",
        social = true,
    },
    {
        name = "openDeployPanel",
        title = "VES_Deploy",
        fallback = "DEPLOYMENT",
        icon = "Contract",
        lobby = true,
    },
    {
        name = "openGaragePanel",
        title = "VES_Garage",
        fallback = "HIDEOUT GARAGE",
        icon = "Gear",
        resolve = function(mode) return mode.GaragePanelInstance end,
        playerObject = true,
    },
    {
        name = "openAdminPanel",
        title = "VES_Admin",
        fallback = "EXTRACTION ADMIN",
        icon = "Server",
        resolve = function(mode) return mode.AdminPanelInstance end,
        admin = true,
    },
    {
        name = "openAdminOperations",
        title = "VES_AdminOperations",
        fallback = "ADMIN OPERATIONS",
        icon = "Contract",
        admin = true,
    },
    {
        name = "openAdminTools",
        title = "VES_AdminTools",
        fallback = "ADMIN TOOLS",
        icon = "Gear",
        resolve = function(mode) return mode.AdminToolsInstance end,
        admin = true,
    },
    {
        name = "openDebugPanel",
        title = "VES_Debug",
        fallback = "EXTRACTION DEBUG",
        icon = "Danger",
        resolve = function(mode) return mode.DebugPanelInstance end,
        debug = true,
    },
    {
        name = "openRaidLocationEditor",
        title = "VES_RaidLocations",
        fallback = "RAID LOCATIONS",
        icon = "Pin",
        resolve = function(mode) return mode.RaidLocationEditorInstance end,
        admin = true,
    },
    {
        name = "openContentEditor",
        title = "VES_ContentEditor",
        fallback = "CONTENT EDITOR",
        icon = "Contract",
        resolve = function(mode) return mode.ContentEditorInstance end,
        admin = true,
    },
    {
        name = "openAdminBandits",
        title = "VES_BanditControls",
        fallback = "BANDIT CONTROLS",
        icon = "Danger",
        admin = true,
    },
    {
        name = "openAdminALife",
        title = "VES_ALifeControls",
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
}

local function diagnostic(key, message)
    if state.diagnostics[key] then return end
    state.diagnostics[key] = true
    print("[Viewpoint Extraction Support] " .. message)
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

local function readLanguageFile(code, filename)
    local cacheKey = code .. "/" .. filename
    if state.languageFiles[cacheKey] then return state.languageFiles[cacheKey] end
    local ok, language = pcall(require, "PRPGE_PDALang")
    if not ok or type(language.Parse) ~= "function" or not getModFileReader then return nil end
    local read, values = pcall(function()
        local reader = getModFileReader("ViewpointExtractionSupport",
            "media/lua/shared/Translate/" .. cacheKey, false)
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
    local values = readLanguageFile(code, filename)
    if values and values[key] then return values[key] end
    if code ~= "EN" then
        values = readLanguageFile("EN", filename)
        if values and values[key] then return values[key] end
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

local function addHit(ui, rect, route, args)
    ui._vesExtractionHits = ui._vesExtractionHits or {}
    ui._vesExtractionHits[#ui._vesExtractionHits + 1] = {
        x = rect.x, y = rect.y, w = rect.w, h = rect.h, route = route, args = args,
    }
end

local function actionRows(data)
    local rows = {
        { key = "Controller", route = "openControllerPanel", args = { 0 } },
        { key = "Destinations", route = "openTownPicker", args = { 0 } },
        { key = "Upgrades", route = "openUpgradePanel", args = { 0 } },
        { key = "Contacts", route = "openQuestPanel", args = { 0 } },
        { key = "Garage", route = "openGaragePanel", args = { playerFor(0), false } },
    }
    if data.hideoutSocial then
        rows[#rows + 1] = { key = "Social", route = "openHideoutSocial", args = { 0 } }
    end
    if data.pvpveLobby == true then
        rows[#rows + 1] = { key = "Deploy", route = "openDeployPanel", args = { 0 } }
    end
    if adminControlsVisible(data) then
        rows[#rows + 1] = { key = "Admin", route = "openAdminPanel", args = {} }
    end
    if data.debugEnabled == true then
        rows[#rows + 1] = { key = "Debug", route = "openDebugPanel", args = {} }
    end
    return rows
end

local function townName(data)
    local key = data.selectedTownKey or data.destinationTownKey
    local fallback = data.selectedTownName or data.destinationTownName
    if not key then
        return fallback or translation("UI_ViewpointExtractionSupport_ExtractionPDA_NoDestination", "No destination selected")
    end
    local config = ExtractionMode and ExtractionMode.Config
    if config and config.townDisplayName then
        local ok, name = pcall(config.townDisplayName, key, fallback or key)
        if ok and name then return tostring(name) end
    end
    return tostring(fallback or key)
end

local function drawButton(ui, rect, label, selected, palette)
    local mx = getMouseX and getMouseX() - ui:getAbsoluteX() or -1
    local my = getMouseY and getMouseY() - ui:getAbsoluteY() or -1
    local hover = isInside(mx, my, rect)
    local fill = hover and palette.buttonHover or palette.button
    ui:drawRect(rect.x, rect.y, rect.w, rect.h, 1, fill[1], fill[2], fill[3])
    local edge = selected and palette.phosphor or palette.edge
    ui:drawRectBorder(rect.x, rect.y, rect.w, rect.h, hover and 0.95 or 0.65, edge[1], edge[2], edge[3])
    local manager = getTextManager()
    local width = manager:MeasureStringX(UIFont.Small, label)
    local scale = math.min(1, (rect.w - 20) / math.max(1, width))
    local height = manager:MeasureStringY(UIFont.Small, "Ag") * scale
    ui:drawTextZoomed(label, rect.x + (rect.w - width * scale) / 2,
        rect.y + (rect.h - height) / 2, scale, palette.text[1], palette.text[2], palette.text[3], 1, UIFont.Small)
end

local function renderHome(ui, pda)
    ui._vesExtractionHits = {}
    local palette = pda.P
    local data = stateFor(0)
    local page = { x = 18, y = 76, w = ui.width - 36, h = ui.height - 94 }
    pda.Panel(ui, page.x, page.y, page.w, page.h, palette.edge)

    ui:drawText(translation("UI_ViewpointExtractionSupport_ExtractionPDA_Title", "EXTRACTION MODE"),
        page.x + 18, page.y + 12, palette.accent[1], palette.accent[2], palette.accent[3], 1, UIFont.Medium)
    ui:drawText(translation("UI_ViewpointExtractionSupport_ExtractionPDA_Intro",
        "Field operations, hideout services and deployment."),
        page.x + 18, page.y + 38, palette.muted[1], palette.muted[2], palette.muted[3], 1, UIFont.Small)

    local statusY = page.y + 66
    local statusH = 52
    pda.Panel(ui, page.x + 12, statusY, page.w - 24, statusH, palette.muted)
    local phase = tostring(data.state or "—")
    local status = data.selfReady == true
        and translation("UI_ViewpointExtractionSupport_ExtractionPDA_Ready", "READY")
        or translation("UI_ViewpointExtractionSupport_ExtractionPDA_NotReady", "NOT READY")
    ui:drawText(phase .. "  |  " .. status, page.x + 24, statusY + 8,
        palette.text[1], palette.text[2], palette.text[3], 1, UIFont.Small)
    ui:drawText(translation("UI_ViewpointExtractionSupport_ExtractionPDA_Destination", "DESTINATION") .. ": " .. townName(data),
        page.x + 24, statusY + 28, palette.muted[1], palette.muted[2], palette.muted[3], 1, UIFont.Small)

    local actions = actionRows(data)
    local columns = ui.width >= 900 and 3 or 2
    local gap = 8
    local buttonW = math.floor((page.w - 24 - gap * (columns - 1)) / columns)
    local rows = math.ceil(#actions / columns)
    local gridY = statusY + statusH + 14
    local availableH = page.y + page.h - gridY - 12
    local buttonH = math.max(26, math.min(54, math.floor((availableH - gap * (rows - 1)) / math.max(rows, 1))))
    local labels = {
        Controller = "UI_ViewpointExtractionSupport_ExtractionPDA_Controller",
        Destinations = "UI_ViewpointExtractionSupport_ExtractionPDA_Destinations",
        Upgrades = "UI_ViewpointExtractionSupport_ExtractionPDA_Upgrades",
        Contacts = "UI_ViewpointExtractionSupport_ExtractionPDA_Contacts",
        Garage = "UI_ViewpointExtractionSupport_ExtractionPDA_Garage",
        Social = "UI_ViewpointExtractionSupport_ExtractionPDA_Social",
        Deploy = "UI_ViewpointExtractionSupport_ExtractionPDA_Deploy",
        Admin = "UI_ViewpointExtractionSupport_ExtractionPDA_Admin",
        Debug = "UI_ViewpointExtractionSupport_ExtractionPDA_Debug",
    }
    for index, action in ipairs(actions) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local rect = {
            x = page.x + 12 + column * (buttonW + gap),
            y = gridY + row * (buttonH + gap),
            w = buttonW,
            h = buttonH,
        }
        local fallback = action.key == "Controller" and "CONTROL PANEL"
            or action.key == "Destinations" and "DESTINATIONS"
            or action.key == "Upgrades" and "HIDEOUT UPGRADES"
            or action.key == "Contacts" and "CONTACTS / BARTER"
            or action.key == "Garage" and "HIDEOUT GARAGE"
            or action.key == "Social" and "HIDEOUT / INVITATIONS"
            or action.key == "Deploy" and "DEPLOY"
            or action.key == "Admin" and "ADMINISTRATION" or "DEBUG"
        drawButton(ui, rect, translation(labels[action.key], fallback), false, palette)
        addHit(ui, rect, action.route, action.args)
    end
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
            if not element._vesExtractionStyled then
                local isRoot = element == root
                local kind = tostring(element.Type or element.type or "")
                local isButton = kind:find("Button", 1, true) ~= nil or element.onClick ~= nil
                recolor(element, "backgroundColor", isRoot and palette.panel or isButton and palette.button or palette.row)
                recolor(element, "borderColor", palette.edge)
                if isButton then
                    recolor(element, "backgroundColorMouseOver", palette.buttonHover)
                    recolor(element, "textColor", palette.text)
                end
                element._vesExtractionStyled = true
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
    if panel then state.instances[route.name] = panel end
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
    if instance._pda and instance._pda.phase == "ready" then
        diagnostic("route-docked:" .. routeName, routeName .. " opened through the PDA")
        return runOriginal(route, original, args, pda, ui)
    end
    state.pending[#state.pending + 1] = {
        route = route, original = original, args = args, requestedAt = getTimestampMs and getTimestampMs() or 0,
    }
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
        _viewpointExtractionSupport = route.name,
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
                if existing._viewpointExtractionSupport == route.name then found = true; break end
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
        return translation("UI_ViewpointExtractionSupport_ExtractionPDA_Tab", "EXTRACTION")
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
        if rect.id == "extraction" then ui._vesExtractionTabRect = placed end
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
            if pda.Tab == "extraction" and not pda.DockActive(owner) then
                renderHome(owner, pda)
            end
            if syncDockedPanels then syncDockedPanels(owner) end
            return unpackArgs(result)
        end
        ui.render = state.renderWrapper
    end
    if ui.onMouseDown ~= state.downWrapper then
        local oldDown = ui.onMouseDown
        state.downWrapper = function(owner, x, y, ...)
            owner._vesExtractionPressed = nil
            owner._vesExtractionTabPressed = nil
            local tab = owner._vesExtractionTabRect
            if tab and isInside(x, y, tab) then
                owner._vesExtractionTabPressed = true
                if pda.DockActive(owner) then pda.Back(owner) end
                if pda.Tab ~= "extraction" then
                    pda.Tab = "extraction"
                    if pda.Sound then pda.Sound("Key") end
                    pda.Transition(owner, translation("UI_ViewpointExtractionSupport_ExtractionPDA_Tab", "EXTRACTION"))
                end
                return true
            end
            if pda.Tab == "extraction" and not pda.DockActive(owner) then
                for _, rect in ipairs(owner._vesExtractionHits or {}) do
                    if isInside(x, y, rect) then
                        owner._vesExtractionPressed = rect
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
            local tabPressed = owner._vesExtractionTabPressed
            owner._vesExtractionTabPressed = nil
            if tabPressed then return true end
            local pressed = owner._vesExtractionPressed
            owner._vesExtractionPressed = nil
            if pressed then
                if isInside(x, y, pressed) then invoke(pressed.route, pack(unpack(pressed.args))) end
                return true
            end
            return oldUp(owner, x, y, ...)
        end
        ui.onMouseUp = state.upWrapper
    end
    state.pageHooksInstalled = true
    return true
end

local function installDockSkin(pda)
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
            print("[Viewpoint Extraction Support] Dock probe found no visible registered Extraction Mode panels; active PDA pages="
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
        or type(pda._docked) ~= "table" then
        return "required ProjectRPGExpanded navigation methods are missing"
    end
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
            if type(key) == "string" and key:sub(1, 13) == "UI_PRPGE_VES_" then
                local value = pdaTranslation(key, "UI.json")
                if value then return formatPdaTranslation(value, ...) end
            end
            return originalGetText(key, ...)
        end
        getText = state.getTextHook
    end
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
    print("[Viewpoint Extraction Support] ProjectRPGExpanded PDA integration active; routed "
        .. tostring(routeCount) .. " Extraction Mode screens; native HUD disabled")
    return true
end

local function tick()
    if not state.installed then
        state.attempts = state.attempts + 1
        if state.attempts % 30 == 0 then
            local installed = Integration.install()
            if not installed and state.attempts >= 120 then
                print("[Viewpoint Extraction Support] ProjectRPGExpanded PDA integration unavailable: "
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
