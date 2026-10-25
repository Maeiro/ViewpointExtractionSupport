local panelRenders = 0
local buttonFills = 0
local buttonBorders = 0

NinePatchTexture = {
    getSharedTexture = function(path)
        return {
            render = function() panelRenders = panelRenders + 1 end,
        }
    end,
}

local button = {
    displayBackground = true,
    prerender = function() end,
    drawRect = function() buttonFills = buttonFills + 1 end,
    drawRectBorder = function() buttonBorders = buttonBorders + 1 end,
    setDisplayBackground = function(self, value) self.displayBackground = value end,
}

local panel = {
    x = 10,
    y = 20,
    width = 300,
    height = 200,
    background = true,
    visible = true,
    children = { button },
    prerender = function() end,
    isVisible = function(self) return self.visible end,
}
ExtractionMode = { HUDInstance = panel }

local option = { value = true }
function option:getValue() return self.value end

local NeatUI = require "ViewpointExtractionSupport/NeatUI"
assert(NeatUI.sync(option), "enable NeatUI when its panel textures are available")
assert(panel.background == false, "hide the vanilla panel background while NeatUI is active")
panel:prerender()
button:prerender()
assert(panelRenders == 2, "draw the NeatUI header and body")
assert(buttonFills == 1 and buttonBorders == 1, "draw rectangular NeatUI button styling")

option.value = false
assert(not NeatUI.sync(option), "disable NeatUI styling from the option")
assert(panel.background == true, "restore the vanilla panel background")
panel:prerender()
assert(panelRenders == 2, "do not draw NeatUI after disabling the option")

print("neat_ui_spec: optional styling, fallback and panel rendering passed")
