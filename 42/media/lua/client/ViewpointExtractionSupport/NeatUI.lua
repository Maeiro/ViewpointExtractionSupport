local NeatUI = {}

local HEADER_PATH = "media/ui/NeatUI/DefaultPanel/MainTitle_BG.png"
local BODY_PATH = "media/ui/NeatUI/DefaultPanel/MainPanelBG_FlatTop.png"
local HEADER_HEIGHT = 36

local panelTextureCache = {}
local whiteTexture
local openHooksInstalled = false
local requested = false
local available = false

local panelFields = {
    "HUDInstance",
    "ControllerPanelInstances",
    "TownPickerInstance",
    "UpgradePanelInstance",
    "QuestPanelInstance",
    "GaragePanelInstance",
    "AdminPanelInstance",
    "DebugPanelInstance",
    "CampaignEpilogueInstance",
    "RaidLocationEditorInstance",
}

local function loadPanelTexture(path)
    if panelTextureCache[path] then return panelTextureCache[path] end
    if not NinePatchTexture or type(NinePatchTexture.getSharedTexture) ~= "function" then return nil end
    local ok, texture = pcall(NinePatchTexture.getSharedTexture, path)
    if ok and texture then
        panelTextureCache[path] = texture
        return texture
    end
    return nil
end

local function optionEnabled(option)
    if not option or type(option.getValue) ~= "function" then return true end
    local ok, value = pcall(option.getValue, option)
    return ok and value == true
end

local function panelVisible(panel)
    if type(panel.isVisible) == "function" then
        local ok, visible = pcall(panel.isVisible, panel)
        if ok then return visible == true end
    end
    if type(panel.getIsVisible) == "function" then
        local ok, visible = pcall(panel.getIsVisible, panel)
        if ok then return visible == true end
    end
    return panel.visible ~= false
end

local function panelPosition(panel)
    local x, y = tonumber(panel.x) or 0, tonumber(panel.y) or 0
    if type(panel.getAbsoluteX) == "function" then
        local ok, absoluteX = pcall(panel.getAbsoluteX, panel)
        if ok and tonumber(absoluteX) then x = absoluteX end
    end
    if type(panel.getAbsoluteY) == "function" then
        local ok, absoluteY = pcall(panel.getAbsoluteY, panel)
        if ok and tonumber(absoluteY) then y = absoluteY end
    end
    return x, y
end

local function drawPanel(panel)
    local header = loadPanelTexture(HEADER_PATH)
    local body = loadPanelTexture(BODY_PATH)
    if not header or not body then return false end

    local width, height = tonumber(panel.width) or 0, tonumber(panel.height) or 0
    if width <= 0 or height <= 0 then return false end
    local headerHeight = math.min(HEADER_HEIGHT, height)
    local x, y = panelPosition(panel)
    header:render(x, y, width, headerHeight, 0.08, 0.08, 0.08, 1)
    if height > headerHeight then
        body:render(x, y + headerHeight, width, height - headerHeight, 0.15, 0.15, 0.15, 1)
    end
    return true
end

local function getWhiteTexture()
    if whiteTexture ~= nil then return whiteTexture or nil end
    local ok, texture = pcall(Texture.getWhite)
    whiteTexture = ok and texture or false
    return texture
end

local function drawCorner(ui, texture, centerX, centerY, radius, startAngle, endAngle, color)
    local segments = 3
    local step = (endAngle - startAngle) / segments
    for index = 0, segments - 1 do
        local first = math.rad(startAngle + step * index)
        local second = math.rad(startAngle + step * (index + 1))
        ui:drawPolygon(texture,
            centerX, centerY,
            centerX + math.cos(first) * radius, centerY + math.sin(first) * radius,
            centerX + math.cos(second) * radius, centerY + math.sin(second) * radius,
            centerX, centerY,
            color.r, color.g, color.b, color.a)
    end
end

local function drawRoundedRect(ui, x, y, width, height, radius, color)
    if width <= 0 or height <= 0 then return end
    radius = math.min(radius, math.min(width, height) / 2)
    local texture = getWhiteTexture()
    if not texture then
        ui:drawRect(x, y, width, height, color.a, color.r, color.g, color.b)
        return
    end

    ui:drawRect(x + radius, y, width - radius * 2, height, color.a, color.r, color.g, color.b)
    ui:drawRect(x, y + radius, radius, height - radius * 2, color.a, color.r, color.g, color.b)
    ui:drawRect(x + width - radius, y + radius, radius, height - radius * 2,
        color.a, color.r, color.g, color.b)
    drawCorner(ui, texture, x + radius, y + radius, radius, 180, 270, color)
    drawCorner(ui, texture, x + width - radius, y + radius, radius, 270, 360, color)
    drawCorner(ui, texture, x + width - radius, y + height - radius, radius, 0, 90, color)
    drawCorner(ui, texture, x + radius, y + height - radius, radius, 90, 180, color)
end

local function drawButton(button)
    local red, green, blue = 0.08, 0.09, 0.10
    if button.enable == false then
        red, green, blue = 0.05, 0.05, 0.06
    elseif button.pressed then
        red, green, blue = 0.04, 0.04, 0.05
    elseif button.mouseOver or (type(button.isMouseOver) == "function" and button:isMouseOver()) then
        red, green, blue = 0.20, 0.20, 0.21
    end
    drawRoundedRect(button, 0, 0, button.width, button.height, 5,
        { a = 0.85, r = 0.42, g = 0.42, b = 0.42 })
    drawRoundedRect(button, 1, 1, button.width - 2, button.height - 2, 4,
        { a = 0.90, r = red, g = green, b = blue })
end

local function styleButton(button, enabled)
    if type(button) ~= "table" or type(button.prerender) ~= "function" then return end
    if not button._viewpointExtractionSupportNeatButtonHook then
        local original = button.prerender
        button._viewpointExtractionSupportNeatButtonHook = true
        button._viewpointExtractionSupportNeatButtonOriginal = original
        button.prerender = function(self, ...)
            if self._viewpointExtractionSupportNeatButtonEnabled then drawButton(self) end
            return original(self, ...)
        end
    end

    if button._viewpointExtractionSupportNeatButtonEnabled == enabled then return end
    if button._viewpointExtractionSupportNeatButtonOriginalDisplayBackground == nil then
        button._viewpointExtractionSupportNeatButtonOriginalDisplayBackground = button.displayBackground
    end
    button._viewpointExtractionSupportNeatButtonEnabled = enabled
    if type(button.setDisplayBackground) == "function" then
        if enabled then
            button:setDisplayBackground(false)
        else
            button:setDisplayBackground(button._viewpointExtractionSupportNeatButtonOriginalDisplayBackground ~= false)
        end
    else
        button.displayBackground = enabled and false
            or button._viewpointExtractionSupportNeatButtonOriginalDisplayBackground
    end
end

local function styleChildren(element, enabled)
    local children = element and element.children
    if type(children) ~= "table" then return end
    for _, child in pairs(children) do
        if type(child) == "table" then
            if type(child.setDisplayBackground) == "function" and type(child.prerender) == "function" then
                styleButton(child, enabled)
            end
            styleChildren(child, enabled)
        end
    end
end

local function stylePanel(panel, enabled)
    if type(panel) ~= "table" or type(panel.prerender) ~= "function" then return end
    if not panel._viewpointExtractionSupportNeatPanelHook then
        local original = panel.prerender
        panel._viewpointExtractionSupportNeatPanelHook = true
        panel._viewpointExtractionSupportNeatPanelOriginal = original
        panel.prerender = function(self, ...)
            local result = original(self, ...)
            if self._viewpointExtractionSupportNeatPanelEnabled and panelVisible(self) then
                drawPanel(self)
            end
            return result
        end
    end

    panel._viewpointExtractionSupportNeatPanelEnabled = enabled
    if enabled then
        if panel._viewpointExtractionSupportNeatPanelOriginalBackground == nil then
            panel._viewpointExtractionSupportNeatPanelOriginalBackground = panel.background
        end
        panel.background = false
    elseif panel._viewpointExtractionSupportNeatPanelOriginalBackground ~= nil then
        panel.background = panel._viewpointExtractionSupportNeatPanelOriginalBackground
    end
    styleChildren(panel, enabled)
end

local function collectPanels(extraction)
    local panels = {}
    local seen = {}
    local function add(panel)
        if type(panel) ~= "table" or seen[panel] then return end
        seen[panel] = true
        panels[#panels + 1] = panel
    end
    for _, field in ipairs(panelFields) do
        local value = extraction[field]
        if field == "ControllerPanelInstances" and type(value) == "table" then
            for _, panel in pairs(value) do add(panel) end
        else
            add(value)
        end
    end
    return panels
end

local function installOpenHooks(extraction)
    if openHooksInstalled or type(extraction.openDeployPanel) ~= "function" then return end
    local original = extraction.openDeployPanel
    extraction.openDeployPanel = function(...)
        local panel = original(...)
        if panel then stylePanel(panel, requested and available) end
        return panel
    end
    openHooksInstalled = true
end

function NeatUI.sync(option)
    requested = optionEnabled(option)
    local header = loadPanelTexture(HEADER_PATH)
    local body = loadPanelTexture(BODY_PATH)
    available = header ~= nil and body ~= nil
    local extraction = ExtractionMode
    if not extraction then return false end

    installOpenHooks(extraction)
    local enabled = requested and available
    for _, panel in ipairs(collectPanels(extraction)) do
        stylePanel(panel, enabled)
    end
    return enabled
end

function NeatUI.isAvailable()
    return available
end

function NeatUI.isRequested()
    return requested
end

return NeatUI
