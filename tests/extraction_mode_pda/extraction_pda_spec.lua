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
getTexture = function() return nil end
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
    screen = {0.01, 0.03, 0.02},
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
    DrawScreen = function() end,
    TransitionActive = function() return false end,
    DockActive = function(ui) return ui._pdaDocked and #ui._pdaDocked > 0 end,
    Sound = function() end,
    DockTick = function(ui)
        local active = {}
        for _, entry in ipairs(pda.DOCK) do
            local window = entry.get()
            if window and window:isVisible() then
                active[#active + 1] = window
                window._pdaDock = true
                pda._docked[window] = {entry = entry}
            end
        end
        ui._pdaDocked = active
        ui._pdaTop = active[#active]
        return active
    end,
}
pda.Back = function(ui)
    if ui._pdaTop then ui._pdaTop:setVisible(false) end
    pda.DockTick(ui)
end
package.preload["PRPGE_PDA"] = function() return pda end

local panel
local clientState = { state = "HIDEOUT", selectedTownKey = "Rosewood" }
ExtractionMode = {
    TextLayout = { viewport = function() return 900, 600 end, height = function() return 16 end },
    Client = { stateFor = function() return clientState end, sendCommand = function() end },
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

ExtractionMode.openUpgradePanel = function()
    local window = {visible = true, children = {}, playerNum = 0}
    function window:isVisible() return self.visible end
    function window:setVisible(v) self.visible = v end
    function window:prerender()
        self.layoutW, self.layoutH = ExtractionMode.TextLayout.viewport(0, 960, 900)
        if self.fail then error("native layout error") end
    end
    ExtractionMode.UpgradePanelInstance = window
    return window
end

ExtractionMode.openGaragePanel = function(player, bypassControlTile)
    assert(player ~= nil, "the garage must receive the local player")
    local window = {visible = true, children = {}, requiresControlTile = bypassControlTile ~= true}
    function window:isVisible() return self.visible end
    function window:setVisible(value) self.visible = value end
    ExtractionMode.GaragePanelInstance = window
    return window
end

local dashboardContext
package.preload["ExtractionModePDA/Dashboard"] = function()
    return { new = function(context)
        dashboardContext = context
        return {
            navigation = function(ui)
                ui._empdaExtractionHits = {{x = 20, y = 80, w = 160, h = 32,
                    action = function() context.open("openTownPicker") end}}
                return 124
            end,
            bodyTop = function() return 124 end,
            render = function() end,
        }
    end }
end

local integration = require "ExtractionModePDA/Integration"
Events.OnGameStart.fire()
assert(integration.install(), "the compatible PDA hooks should install")
RPGSkillTreeUI.open()
RPGSkillTreeUI.render(RPGSkillTreeUI.instance)

local found = false
for _, tab in ipairs(RPGSkillTreeUI.instance._tabRects) do if tab.id == "extraction" then found = true end end
assert(found, "the Extraction tab should be added before Settings")
assert(RPGSkillTreeUI.instance._tabRects[1].id == "home" and RPGSkillTreeUI.instance._tabRects[2].id == "extraction",
    "the Extraction tab should appear immediately after the Dossier tab")

ExtractionMode.openControllerPanel(0)
assert(panel == nil, "controller menu must become the dashboard rather than a duplicate launcher")
assert(pda.Tab == "extraction", "controller shortcut should select the dashboard")
local opened = ExtractionMode.openTownPicker(0)
assert(opened == ExtractionMode.TownPickerInstance, "dedicated pages should retain native return values")
assert(RPGSkillTreeUI.instance._pdaDocked[1] == opened, "dedicated pages should remain docked")
assert(ExtractionMode.openAdminPanel() == "native-admin", "admin permissions must stay with the original gate")
opened:setVisible(false)
pda.DockTick(RPGSkillTreeUI.instance)
RPGSkillTreeUI.render(RPGSkillTreeUI.instance)
assert(RPGSkillTreeUI.instance.homeHidden and #RPGSkillTreeUI.instance._empdaExtractionHits > 0,
    "dashboard must be available after closing a dedicated page")

local button = RPGSkillTreeUI.instance._empdaExtractionHits[1]
assert(RPGSkillTreeUI.onMouseDown(RPGSkillTreeUI.instance, button.x + 2, button.y + 2),
    "dashboard actions should capture mouse presses")
assert(RPGSkillTreeUI.onMouseUp(RPGSkillTreeUI.instance, button.x + 2, button.y + 2),
    "dashboard actions should open their Extraction Mode page")
assert(RPGSkillTreeUI.instance._pdaDocked[1] ~= nil,
    "dashboard actions should open their panel in the PDA")

ExtractionMode.TownPickerInstance:setVisible(false)
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

dashboardContext.navigate("upgrades")
local upgrades = ExtractionMode.UpgradePanelInstance
assert(RPGSkillTreeUI.instance._pdaTop == upgrades, "navigation must close the previous page")
assert(not ExtractionMode.TownPickerInstance:isVisible(), "previous windows must not remain behind the new page")
upgrades:prerender()
local rect = pda.DockRect(RPGSkillTreeUI.instance)
assert(upgrades.layoutW == rect.w and upgrades.layoutH == rect.h, "native lists must fill the PDA body below navigation")
local _, originalHeight = ExtractionMode.TextLayout.viewport(0, 960, 900)
assert(originalHeight == 600, "native viewport behavior must remain unchanged outside the docked layout")
upgrades.fail = true
assert(not pcall(upgrades.prerender, upgrades))
local _, restoredHeight = ExtractionMode.TextLayout.viewport(0, 960, 900)
assert(restoredHeight == 600, "a layout error must restore the viewport scope")
upgrades.fail = false
dashboardContext.navigate("home")
assert(not pda.DockActive(RPGSkillTreeUI.instance), "returning home must close the native subpage")
for _ = 1, 3 do
    dashboardContext.navigate("garage")
    local garage = ExtractionMode.GaragePanelInstance
    assert(not garage.requiresControlTile, "PDA garage access must not auto-close away from the world control tile")
    assert(RPGSkillTreeUI.instance._pdaTop == garage and #RPGSkillTreeUI.instance._pdaDocked == 1,
        "reopening the garage must consistently display exactly one page")
    dashboardContext.navigate("home")
end
