local Visibility = {}
local option
local ensureWrapper
local pollWrapper

local function inventoryOpen()
    local screen = ViewpointInvScreen
    if not option or not option:getValue() or type(screen) ~= "table"
        or type(screen.isUp) ~= "function" then return false end
    local ok, open = pcall(screen.isUp)
    return ok and open == true
end

local function sync(card)
    if not card then return end
    if inventoryOpen() then
        card._vesInventoryHidden = true
        card:setVisible(false)
        if card.portrait then card.portrait:setVisible(false) end
        if card.levelBadge then card.levelBadge:setVisible(false) end
    elseif card._vesInventoryHidden then
        card._vesInventoryHidden = nil
        card:setVisible(card._shown == true and not card._empdaErgonomicHidden)
    end
end

function Visibility.install(setting)
    option = setting
    local api = package.loaded["PRPGE_PlayerCard"]
    if type(api) ~= "table" or type(api.Ensure) ~= "function" then return end
    if api.Ensure ~= ensureWrapper then
        local original = api.Ensure
        ensureWrapper = function(...)
            local card = original(...)
            sync(card)
            return card
        end
        api.Ensure = ensureWrapper
    end
    if type(api.Poll) == "function" and api.Poll ~= pollWrapper then
        local original = api.Poll
        pollWrapper = function(...)
            if inventoryOpen() then return false end
            return original(...)
        end
        api.Poll = pollWrapper
    end
    sync(api.card)
end

return Visibility
