ExtractionMode = {
    UIVisibility = {
        updateHUD = function()
            ExtractionMode.HUDInstance.visible = true
        end,
    },
    HUDInstance = {
        visible = false,
        setVisible = function(self, value) self.visible = value end,
    },
}

local inventory = { visible = false, isCollapsed = false }
local loot = { visible = false, isCollapsed = false }
function inventory:isVisible() return self.visible end
function loot:isVisible() return self.visible end
getPlayerInventory = function() return inventory end
getPlayerLoot = function() return loot end

local option = { value = false }
function option:getValue() return self.value end

local Visibility = require "ViewpointExtractionSupport/HudVisibility"
assert(Visibility.install(option), "install the HUD visibility hook")
ExtractionMode.UIVisibility.updateHUD()
assert(ExtractionMode.HUDInstance.visible == true, "keep the HUD visible by default")

option.value = true
inventory.visible = false
loot.visible = false
ExtractionMode.UIVisibility.updateHUD()
assert(ExtractionMode.HUDInstance.visible == false, "hide the HUD when no inventory is open")

inventory.visible = true
ExtractionMode.UIVisibility.updateHUD()
assert(ExtractionMode.HUDInstance.visible == true, "show the HUD with the player inventory open")

inventory.visible = false
inventory.isCollapsed = true
ExtractionMode.UIVisibility.updateHUD()
assert(ExtractionMode.HUDInstance.visible == false, "do not count a collapsed inventory as open")

inventory.isCollapsed = false
loot.visible = true
ExtractionMode.UIVisibility.updateHUD()
assert(ExtractionMode.HUDInstance.visible == true, "show the HUD with the loot window open")
assert(Visibility.install(option), "keep the HUD hook idempotent")
print("hud_visibility_spec: default, inventory, loot, collapsed and idempotent behavior passed")
