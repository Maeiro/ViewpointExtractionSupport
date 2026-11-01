local function event()
    return { Add = function() end }
end

Events = { OnGameStart = event(), OnTick = event() }
local function noop() end
RPGSkillTreeUI = { render = noop, onMouseDown = noop, onMouseUp = noop, open = noop }
local pda = {
    P = {}, DOCK = {}, _docked = {}, Panel = noop, DockTick = noop,
    CanUse = noop, KeepOpen = noop, DockActive = noop, Back = noop,
    Transition = noop, Controls = noop, ScreenTitle = noop,
    DockRect = noop, DrawScreen = noop, TransitionActive = noop,
}
package.preload["PRPGE_PDA"] = function() return pda end

local hudAllowed = true
local updates = 0
local function newHUD()
    return { setVisible = function(self, value) self.visible = value end }
end
ExtractionMode = {
    TextLayout = { viewport = noop },
    HUDInstance = newHUD(),
    UIVisibility = {
        updateHUD = function()
            updates = updates + 1
            ExtractionMode.HUDInstance:setVisible(hudAllowed)
        end,
    },
}

local integration = require "ExtractionModePDA/Integration"
assert(integration.install())
assert(ExtractionMode.HUDInstance.visible == false, "installing PDA mode must immediately hide the native HUD")
local updateHUD = ExtractionMode.UIVisibility.updateHUD
assert(integration.install() and ExtractionMode.UIVisibility.updateHUD == updateHUD,
    "reinstalling must not stack HUD hooks")

updateHUD()
assert(not ExtractionMode.HUDInstance.visible, "PDA mode must hide the native HUD even before the PDA opens")

local ui = { visible = true, isVisible = function(self) return self.visible end }
RPGSkillTreeUI.instance = ui
for _, phase in ipairs({ "opening", "ready", "closing" }) do
    ui._pda = { phase = phase }
    updateHUD()
    assert(not ExtractionMode.HUDInstance.visible,
        "the persistent HUD must not cover the PDA during " .. phase)
end

ExtractionMode.HUDInstance = newHUD()
updateHUD()
assert(not ExtractionMode.HUDInstance.visible, "a recreated HUD must also stay hidden behind the PDA")

ui.visible = false
updateHUD()
assert(not ExtractionMode.HUDInstance.visible, "hiding the PDA must not restore the native HUD")
ui.visible = true
ui._pda = nil
updateHUD()
assert(not ExtractionMode.HUDInstance.visible, "the native HUD must stay hidden regardless of the current PDA window")

RPGSkillTreeUI.instance = nil
updateHUD()
assert(not ExtractionMode.HUDInstance.visible, "closing the PDA must not restore the native HUD")
hudAllowed = false
updateHUD()
assert(not ExtractionMode.HUDInstance.visible, "closing must preserve native pause/death visibility rules")
assert(updates == 10, "every HUD update must still run the original visibility rules")
print("extraction_pda_hud_spec: native HUD stays hidden throughout PDA mode")
