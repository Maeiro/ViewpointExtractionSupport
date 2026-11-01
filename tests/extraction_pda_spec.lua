local function event()
    local handlers = {}
    return {
        Add = function(fn) handlers[#handlers + 1] = fn end,
        Remove = function(fn)
            for i = #handlers, 1, -1 do if handlers[i] == fn then table.remove(handlers, i) end end
        end,
        fire = function(...) for _, fn in ipairs(handlers) do fn(...) end end,
    }
end

Events = { OnGameStart = event(), OnTick = event() }
UIFont = { Small = 1, Medium = 2 }
getSpecificPlayer = function() return {} end
getMouseX = function() return -1 end
getMouseY = function() return -1 end
getText = function(key) return key end
getTextManager = function()
    return {
        MeasureStringX = function(_, _, text) return #tostring(text) * 6 end,
        MeasureStringY = function() return 12 end,
    }
end

local TABS = {
    { id = "home", key = "TabHome" },
    { id = "ops", key = "TabOps" },
    { id = "settings", key = "TabSettings" },
}
local TAB_ICON = {}
local function tabIcon(id) return TAB_ICON[id] end
local function drawTabs() return TABS, tabIcon end
local Home = { Hide = function(ui) ui.homeHidden = true end }

local function newUi()
    return {
        width = 1000,
        height = 700,
        _pda = { phase = "ready" },
        _tabRects = TABS,
        getAbsoluteX = function() return 0 end,
        getAbsoluteY = function() return 0 end,
        drawText = function() end,
        drawTextZoomed = function() end,
        drawRect = function() end,
        drawRectBorder = function() end,
    }
end

local nextPhase = "ready"
RPGSkillTreeUI = {
    _PRPGE_INTERFACE_1022 = true,
    render = function(ui) ui._tabRects = drawTabs(); Home.Hide(ui) end,
    onMouseDown = function() return true end,
    onMouseUp = function() return true end,
    open = function()
        RPGSkillTreeUI.instance = newUi()
        RPGSkillTreeUI.instance._pda.phase = nextPhase
        return RPGSkillTreeUI.instance
    end,
}

local palette = {
    panel = { 0.01, 0.04, 0.03 }, row = { 0.02, 0.06, 0.04 },
    button = { 0.02, 0.07, 0.04 }, buttonHover = { 0.05, 0.15, 0.09 },
    edge = { 0.17, 0.5, 0.34 }, text = { 0.84, 0.95, 0.87 },
    muted = { 0.5, 0.66, 0.57 }, accent = { 0.62, 0.97, 0.75 }, phosphor = { 0.36, 0.92, 0.6 },
}
pda = {
    P = palette,
    Tab = "home",
    DOCK = {},
    _docked = {},
    Panel = function() end,
    CanUse = function(player) return player ~= nil end,
    KeepOpen = function() return true end,
    Back = function() end,
    Transition = function() end,
    Controls = function() return { {}, {}, { x = 980 } } end,
    ScreenTitle = function() return "" end,
    DockRect = function() return { x = 0, y = 0, w = 900, h = 600 } end,
    TransitionActive = function() return false end,
    DockActive = function(ui) return ui._pdaDocked and #ui._pdaDocked > 0 end,
    Sound = function() end,
    DockTick = function(ui)
        local active = {}
        for _, entry in ipairs(pda.DOCK) do
            local window = entry.get()
            if window and window:isVisible() then active[#active + 1] = window end
        end
        ui._pdaDocked = active
        return active
    end,
}
package.preload["PRPGE_PDA"] = function() return pda end

local panel
local clientState = { state = "HIDEOUT", selectedTownKey = "Rosewood" }
ExtractionMode = {
    Client = { stateFor = function() return clientState end },
    Config = {},
    ControllerPanelInstances = {},
    openAdminPanel = function() return "native-admin" end,
    TownPickerInstance = nil,
    openTownPicker = function()
        local townPanel = {
            visible = true,
            children = {},
            isVisible = function(self) return self.visible end,
            setVisible = function(self, value) self.visible = value end,
        }
        ExtractionMode.TownPickerInstance = townPanel
        return townPanel
    end,
    openControllerPanel = function(playerNum)
        panel = {
            visible = true,
            backgroundColor = { r = 0.025, g = 0.03, b = 0.035, a = 0.96 },
            borderColor = { r = 0.82, g = 0.58, b = 0.16, a = 0.9 },
            children = {},
            isVisible = function(self) return self.visible end,
            setVisible = function(self, value) self.visible = value end,
        }
        ExtractionMode.ControllerPanelInstances[playerNum] = panel
        return panel
    end,
}

local integration = require "ViewpointExtractionSupport/ExtractionPDA"
Events.OnGameStart.fire()
assert(integration.install(), "the compatible PDA hooks should install")

local found = false
for _, tab in ipairs(RPGSkillTreeUI.instance._tabRects) do if tab.id == "extraction" then found = true end end
assert(found, "the Extraction tab should be added before Settings")
assert(RPGSkillTreeUI.instance._tabRects[1].id == "home" and RPGSkillTreeUI.instance._tabRects[2].id == "extraction",
    "the Extraction tab should appear immediately after the Dossier tab")
assert(TAB_ICON.extraction == "Pin", "the tab should use the PDA pin icon")

local opened = ExtractionMode.openControllerPanel(0)
assert(opened == panel, "panel open requests should keep returning the Extraction Mode panel")
assert(pda.Tab == "extraction", "opening an Extraction Mode screen should select the PDA Extraction tab")
assert(RPGSkillTreeUI.instance._pdaDocked[1] == panel, "the Extraction panel should be docked in the PDA")
assert(panel.backgroundColor.r == palette.panel[1] and panel.borderColor.g == palette.edge[2],
    "docked panels should inherit the PDA palette")
panel.children[1] = {
    Type = "ISButton",
    backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 },
    borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 },
    children = {},
}
pda.DockTick(RPGSkillTreeUI.instance)
assert(panel.children[1].backgroundColor.r == palette.button[1],
    "controls created after a panel opens should inherit the PDA palette")
assert(ExtractionMode.openAdminPanel() == "native-admin" and pda.Tab == "extraction",
    "admin-only routes must retain their original gate when the client is not an admin")

panel:setVisible(false)
pda.DockTick(RPGSkillTreeUI.instance)
RPGSkillTreeUI.render(RPGSkillTreeUI.instance)
assert(RPGSkillTreeUI.instance.homeHidden and #RPGSkillTreeUI.instance._vesExtractionHits > 0,
    "the Extraction tab should render its PDA dashboard when no subpage is open")
for _, hit in ipairs(RPGSkillTreeUI.instance._vesExtractionHits) do
    assert(hit.route ~= "openHideoutSocial" and hit.route ~= "openDeployPanel",
        "social and deployment actions should stay hidden when their features are unavailable")
end
clientState.hideoutSocial = {}
clientState.pvpveLobby = true
RPGSkillTreeUI.render(RPGSkillTreeUI.instance)
local foundDeploy = false
for _, hit in ipairs(RPGSkillTreeUI.instance._vesExtractionHits) do
    if hit.route == "openDeployPanel" then
        foundDeploy = true
        assert(#hit.args == 1, "dashboard deployment should open the page rather than toggle it closed")
    end
end
assert(foundDeploy, "hideout social and deployment actions should appear when available")

local button = RPGSkillTreeUI.instance._vesExtractionHits[1]
assert(RPGSkillTreeUI.onMouseDown(RPGSkillTreeUI.instance, button.x + 2, button.y + 2),
    "dashboard actions should capture mouse presses")
assert(RPGSkillTreeUI.onMouseUp(RPGSkillTreeUI.instance, button.x + 2, button.y + 2),
    "dashboard actions should open their Extraction Mode page")
assert(RPGSkillTreeUI.instance._pdaDocked[1] ~= nil,
    "dashboard actions should open their panel in the PDA")

panel:setVisible(false)
RPGSkillTreeUI.instance._pdaDocked = {}
RPGSkillTreeUI.instance = nil
nextPhase = "opening"
assert(ExtractionMode.openTownPicker(0) == nil, "opening requests should wait for the PDA boot animation")
assert(not RPGSkillTreeUI.instance._pdaDocked or RPGSkillTreeUI.instance._pdaDocked[1] == nil,
    "an opening page should wait until the PDA is ready")
RPGSkillTreeUI.instance._pda.phase = "ready"
Events.OnTick.fire()
assert(RPGSkillTreeUI.instance._pdaDocked[1] == ExtractionMode.TownPickerInstance,
    "queued screens should be docked once the PDA finishes opening")
