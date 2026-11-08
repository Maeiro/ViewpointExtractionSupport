local Visibility = {}
local option
local ensureWrapper
local pollWrapper
local playerCard
local loadAttempted = false

local function pdaActive()
    if not getActivatedMods then return false end
    local mods = getActivatedMods()
    for index = 0, mods:size() - 1 do
        if tostring(mods:get(index)):gsub("^.*[\\/]", "") == "ProjectRPGExpanded" then return true end
    end
    return false
end

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
    if not loadAttempted then
        if not pdaActive() then return end
        loadAttempted = true
        local ok, api = pcall(require, "PRPGE_PlayerCard")
        if ok and type(api) == "table" then playerCard = api end
    end
    local api = playerCard
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
