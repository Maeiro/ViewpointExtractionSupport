local Visibility = {}

local function visible(window)
    if not window or type(window.isVisible) ~= "function" then return false end
    local ok, result = pcall(window.isVisible, window)
    return ok and result == true
end

local function inventoryVisible(getter)
    if type(getter) ~= "function" then return false end
    local ok, window = pcall(getter, 0)
    if not ok or not visible(window) then return false end

    local collapsed = window.isCollapsed
    if type(collapsed) == "function" then
        local collapsedOk, value = pcall(collapsed, window)
        if collapsedOk then collapsed = value end
    elseif collapsed == nil then
        collapsed = window.collapsed
    end
    return collapsed ~= true
end

local function ergonomicInventoryVisible()
    local panel = ErgonomicUI and ErgonomicUI.panel
    if not visible(panel) then return false end
    if type(panel.isBodyVisible) == "function" then
        local ok, result = pcall(panel.isBodyVisible, panel)
        if ok and result == false then return false end
    end
    return panel._viewpointSupportInventoryOpen == true
end

function Visibility.inventoryOpen()
    return inventoryVisible(getPlayerInventory)
        or inventoryVisible(getPlayerLoot)
        or ergonomicInventoryVisible()
end

function Visibility.install(option)
    local extraction = ExtractionMode
    local ui = extraction and extraction.UIVisibility
    if not ui then
        pcall(require, "ExtractionMode/UIVisibility")
        extraction = ExtractionMode
        ui = extraction and extraction.UIVisibility
    end
    if type(ui) ~= "table" or type(ui.updateHUD) ~= "function" then return false end
    if ui._viewpointExtractionSupportHUDHookInstalled then return true end

    local original = ui.updateHUD
    local wrapper = function(...)
        local result = original(...)
        local onlyWithInventory = false
        if option and type(option.getValue) == "function" then
            local ok, value = pcall(option.getValue, option)
            onlyWithInventory = ok and value == true
        end
        if onlyWithInventory and not Visibility.inventoryOpen() then
            local hud = ExtractionMode and ExtractionMode.HUDInstance
            if hud and type(hud.setVisible) == "function" then hud:setVisible(false) end
        end
        return result
    end
    ui.updateHUD = wrapper
    ui._viewpointExtractionSupportHUDHook = wrapper
    ui._viewpointExtractionSupportHUDHookInstalled = true
    return true
end

return Visibility
