local function event()
    local handlers = {}
    return {
        Add = function(fn) handlers[#handlers + 1] = fn end,
        Remove = function() end,
        fire = function(...) for _, fn in ipairs(handlers) do fn(...) end end,
    }
end

Events = { OnGameStart = event(), OnTick = event() }
local opened = false
ExtractionMode = {
    openControllerPanel = function() opened = true; return "native" end,
    HUDInstance = { visible = true },
    UIVisibility = { updateHUD = function() ExtractionMode.HUDInstance.visible = true end },
}

local integration = require "ViewpointExtractionSupport/ExtractionPDA"
Events.OnGameStart.fire()
assert(integration.install() == false, "missing PDA must leave the native Extraction Mode UI available")
ExtractionMode.UIVisibility.updateHUD()
assert(ExtractionMode.HUDInstance.visible, "missing PDA must retain the native HUD")
assert(ExtractionMode.openControllerPanel(0) == "native" and opened,
    "the original panel opener must remain untouched when the PDA is not installed")

local tabs = {
    { id = "home", key = "TabHome" },
    { id = "ops", key = "TabOps" },
    { id = "settings", key = "TabSettings" },
}
local Home = { Hide = function() end }
local function drawTabs() return tabs end
RPGSkillTreeUI = {
    render = function(ui) drawTabs(); Home.Hide(ui) end,
    onMouseDown = function() return true end,
    onMouseUp = function() return true end,
    open = function() return {} end,
}
package.preload["PRPGE_PDA"] = function()
    return {
        P = {}, DOCK = {},
        Panel = function() end,
        CanUse = function() return true end,
        KeepOpen = function() return true end,
        DockActive = function() return false end,
    }
end
local original = ExtractionMode.openControllerPanel
assert(integration.install() == false, "an incompatible PDA must not receive Extraction Mode hooks")
ExtractionMode.UIVisibility.updateHUD()
assert(ExtractionMode.HUDInstance.visible, "an incompatible PDA must retain the native HUD")
assert(ExtractionMode.openControllerPanel == original,
    "an incompatible PDA must leave the native panel opener untouched")
