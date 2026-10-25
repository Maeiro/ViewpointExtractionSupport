pcall(require, "Viewpoint_Interact")

local Interaction = {}
local Target = require "ViewpointExtractionSupport/InteractionTarget"
local Config = ExtractionMode.Config or {}
local Util = ExtractionMode.Util or {}

local function stateFor(player)
    if ExtractionMode.Client and ExtractionMode.Client.stateFor then
        return ExtractionMode.Client.stateFor(player) or {}
    end
    return ExtractionMode.ClientState or {}
end

local function playerInRope(player, rope)
    return Util.playerNear and Util.playerNear(player, rope, tonumber(rope.radius) or 3) or false
end

local function text(key, fallback)
    if getText then return getText(key) end
    return fallback
end

local function optionFor(player, object)
    local data = stateFor(player)
    local rope = data.extractionRope
    if data.state ~= Config.STATE_BOARDING or data.isParticipant ~= true or type(rope) ~= "table"
        or not playerInRope(player, rope) then
        return nil
    end

    local inVehicle = player:getVehicle() ~= nil
    local pending = data.boardingPendingSelf == true
    local name = inVehicle and text("IGUI_ExtractionMode_ExitVehicleToBoard", "Exit Vehicle to Board")
        or pending and text("ContextMenu_ExtractionMode_Boarding", "Boarding Extraction Helicopter...")
        or text("ContextMenu_ExtractionMode_Board", "Board Extraction Helicopter")
    return {
        name = name,
        fn = function() ExtractionMode.Client.boardExtraction(player) end,
        args = {},
        n = 0,
        enabled = not inVehicle and not pending,
    }
end

function Interaction.sync()
    local player = getSpecificPlayer and getSpecificPlayer(0)
    local data = player and stateFor(player) or nil
    local rope = data and data.state == Config.STATE_BOARDING and data.isParticipant == true
        and data.boardingPendingSelf ~= true and data.extractionRope
    Target.sync(rope)
end

function Interaction.clear()
    Target.clear()
end

function Interaction.install()
    pcall(require, "Viewpoint_Interact")
    if not ViewpointInteract or type(ViewpointInteract.harvest) ~= "function" then return false end
    if ViewpointInteract._viewpointExtractionSupportBoardingInstalled
        or ViewpointInteract._viewpointExtractionSupportBoarding then
        return true
    end

    local original = ViewpointInteract.harvest
    ViewpointInteract.harvest = function(player, object)
        local option = optionFor(player, object)
        if Target.isTarget(object) then
            if not option then return { why = "extraction boarding is unavailable" } end
            ViewpointInteract.actions = { option }
            return {
                title = option.name,
                labels = { option.name },
                enabled = { option.enabled },
                seen = 0,
            }
        end

        local depth = tonumber(ViewpointInteract._viewpointExtractionSupportHarvestDepth) or 0
        if depth > 0 then return { why = "interaction harvest is already running" } end
        ViewpointInteract._viewpointExtractionSupportHarvestDepth = depth + 1
        local ok, result = pcall(original, player, object)
        ViewpointInteract._viewpointExtractionSupportHarvestDepth = depth
        if not ok then error(result, 0) end
        if not option or type(result) ~= "table" then return result end

        for _, label in ipairs(result.labels or {}) do
            if label == option.name then return result end
        end
        ViewpointInteract.actions[#ViewpointInteract.actions + 1] = option
        result.labels = result.labels or {}
        result.enabled = result.enabled or {}
        result.labels[#result.labels + 1] = option.name
        result.enabled[#result.enabled + 1] = option.enabled
        result.seen = (tonumber(result.seen) or 0) + 1
        return result
    end
    ViewpointInteract._viewpointExtractionSupportBoarding = ViewpointInteract.harvest
    ViewpointInteract._viewpointExtractionSupportBoardingInstalled = true
    return true
end

ViewpointExtractionSupportInteraction = Interaction
Interaction.install()
return Interaction
