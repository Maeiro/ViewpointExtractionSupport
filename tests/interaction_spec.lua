local actionCalls = 0
local vehicle = nil
local playerX = 100.5
local player = {
    getVehicle = function() return vehicle end,
    getX = function() return playerX end,
    getY = function() return 200.5 end,
}

local state = {
    state = "BOARDING",
    isParticipant = true,
    boardingPendingSelf = false,
    extractionRope = { x = 100, y = 200, z = 0, radius = 3 },
}

ExtractionMode = {
    Config = { STATE_BOARDING = "BOARDING" },
    Client = {
        stateFor = function() return state end,
        boardExtraction = function() actionCalls = actionCalls + 1 end,
    },
    Util = {
        playerNear = function(target, point, radius)
            local dx = target:getX() - point.x
            local dy = target:getY() - point.y
            return dx * dx + dy * dy <= radius * radius
        end,
    },
}

getText = function(key)
    return ({
        ContextMenu_ExtractionMode_Board = "Board Extraction Helicopter",
        ContextMenu_ExtractionMode_Boarding = "Boarding Extraction Helicopter...",
        IGUI_ExtractionMode_ExitVehicleToBoard = "Exit Vehicle to Board",
    })[key] or key
end

ViewpointInteract = { actions = {} }
function ViewpointInteract.harvest(_, object)
    ViewpointInteract.actions = { { name = "Climb through", enabled = true } }
    return { title = "Window Frame", labels = { "Climb through" }, enabled = { true }, seen = 2,
        object = object }
end
function ViewpointInteract.run(_, index)
    local action = ViewpointInteract.actions[index]
    if action and action.enabled then action.fn() end
end
package.preload["Viewpoint_Interact"] = function() end

local Interaction = require "ViewpointExtractionSupport/Interaction"
local target = { getSquare = function()
    return { getX = function() return 100 end, getY = function() return 200 end,
        getZ = function() return 0 end }
end }
local outside = { getSquare = function()
    return { getX = function() return 110 end, getY = function() return 200 end,
        getZ = function() return 0 end }
end }

local Target = require "ViewpointExtractionSupport/InteractionTarget"
local temporaryTarget = {}
Target.isTarget = function(object) return object == temporaryTarget end

local menu = ViewpointInteract.harvest(player, target)
assert(Interaction.install(), "the interaction hook should be idempotent")
assert(#menu.labels == 2 and menu.labels[2] == "Board Extraction Helicopter",
    "the boarding option should be added to the Viewpoint menu")
assert(menu.enabled[2] == true and #ViewpointInteract.actions == 2)
ViewpointInteract.run(player, 2)
assert(actionCalls == 1, "the Viewpoint action should use Extraction Mode's boarding helper")

menu = ViewpointInteract.harvest(player, temporaryTarget)
assert(#menu.labels == 1 and menu.labels[1] == "Board Extraction Helicopter",
    "the temporary extraction target should bypass vanilla hooks")
assert(#ViewpointInteract.actions == 1, "the temporary extraction target should expose only boarding")

local previousHarvest = ViewpointInteract.harvest
ViewpointInteract.harvest = function(currentPlayer, object)
    return previousHarvest(currentPlayer, object)
end
assert(Interaction.install(), "the interaction hook should reinstall after another wrapper replaces it")
menu = ViewpointInteract.harvest(player, target)
assert(#menu.labels == 2 and menu.labels[2] == "Board Extraction Helicopter",
    "the boarding option should survive another menu wrapper")

menu = ViewpointInteract.harvest(player, outside)
assert(#menu.labels == 2, "the boarding option should follow the player's extraction-line proximity")

playerX = 110.5
menu = ViewpointInteract.harvest(player, target)
assert(#menu.labels == 1, "the boarding option should not appear outside the extraction area")
playerX = 100.5

state.boardingPendingSelf = true
menu = ViewpointInteract.harvest(player, target)
assert(#menu.labels == 2 and menu.enabled[2] == false,
    "an already queued boarding action should remain disabled")
state.boardingPendingSelf = false

vehicle = {}
menu = ViewpointInteract.harvest(player, target)
assert(#menu.labels == 2 and menu.enabled[2] == false,
    "boarding from a vehicle should remain disabled")
vehicle = nil

state.state = "RAID"
menu = ViewpointInteract.harvest(player, target)
assert(#menu.labels == 1, "the boarding option should require the boarding state")
state.state = "BOARDING"
state.extractionRope = nil
menu = ViewpointInteract.harvest(player, target)
assert(#menu.labels == 1, "a boarding state without a rope must not create an interaction")
print("interaction_spec: Viewpoint boarding action, target area, pending and vehicle guards passed")
