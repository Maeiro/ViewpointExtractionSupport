UIFont = {Small = 1, Medium = 2}
local now, commands, inventory = 1000, {}, {gasoline = 5, parts = 0}
local survivor = {saved = {}}
function survivor:getModData() return self.saved end
function survivor:getInventory() return inventory end
getSpecificPlayer = function() return survivor end
getTimestampMs = function() return now end
getTextManager = function() return {MeasureStringX = function(_, _, value) return #value * 6 end} end
local Layout = {height = function() return 16 end, fit = function(value) return value end}
function Layout.wrap(value, _, width)
    local result, size = {}, math.max(1, math.floor(width / 6))
    for start = 1, #value, size do result[#result + 1] = value:sub(start, start + size - 1) end
    return result
end
function Layout.flow(width)
    local flow = {y = 0, runs = {}}
    function flow:add(value, font)
        for _, part in ipairs(Layout.wrap(value, font, width)) do
            self.runs[#self.runs + 1] = {text = part, y = self.y, x = 0}
            self.y = self.y + 16
        end
    end
    return flow
end
function Layout.draw(ui, flow, x, y)
    for _, run in ipairs(flow.runs) do ui:drawText(run.text, x, y + run.y) end
end
local definitions = {
    {id = "radio", contactId = "pilot", requirements = {{label = "Parts", amount = 2}}},
    {id = "locked", prerequisites = {"radio"}, requirements = {}},
}
local data = {state = "HIDEOUT", selectedTownKey = "Rosewood", quests = {}, upgrades = {}, generator = {fuel = 0, capacity = 40},
    townChoices = {{key = "Rosewood", name = "Rosewood"}, {key = "Louisville", name = "Louisville"}}}
local canOpen, inHideout = true, true
ExtractionMode = {
    TextLayout = Layout,
    Config = {STATE_HIDEOUT = "HIDEOUT", STATE_COUNTDOWN = "COUNTDOWN", STATE_RAID = "RAID", STATE_EXTRACTING = "EXTRACTING", STATE_BOARDING = "BOARDING",
        townDisplayName = function(_, name) return name end},
    Localization = {get = function(_, fallback, ...)
        local args = {...}
        return (fallback:gsub("%%(%d)", function(n) return tostring(args[tonumber(n)]) end))
    end},
    Infection = {playerInsideHideout = function() return inHideout end},
    UIVisibility = {canOpen = function() return canOpen end},
    Client = {stateFor = function() return data end, sendCommand = function(_, command, args)
        commands[#commands + 1] = {command = command, args = args}
    end},
    Generator = {availableGasoline = function(value) return value.gasoline end},
    Upgrades = {definitions = function() return {} end},
    Quests = {
        isCompleted = function(completed, id) return completed and completed[id] == true end,
        isAcquired = function(completed, definition)
            return definition.id == "radio" or completed.radio == true
        end,
        acquiredDefinitions = function(completed)
            return completed.radio and definitions or {definitions[1]}
        end,
        name = function(d) return d.id end, contactDisplayName = function() return "Pilot" end,
        description = function() return "Repair the radio" end, label = function(r) return r.label end,
        skillRequirementsMet = function() return true end, objectivesMet = function() return true end,
        requirementCounts = function() return {inventory.parts} end,
    },
}
local Tracking = require "ExtractionModePDA/QuestTracking"
assert(not Tracking.set(survivor, data, "locked"), "locked quests cannot be tracked")
assert(not Tracking.set(survivor, data, "missing"), "unknown quest IDs cannot be tracked")
assert(Tracking.set(survivor, data, "radio"))
assert(Tracking.get(survivor, data).id == "radio")
local other = {getModData = function() return {} end}
assert(Tracking.get(other, data) == nil, "tracking is personal even when quest progress is shared")
assert(Tracking.get(survivor, {}) == nil)
assert(Tracking.get(survivor, {quests = {}}) == nil)
assert(Tracking.get(survivor, data).id == "radio", "waiting for a snapshot must not erase the preference")
package.loaded["ExtractionModePDA/QuestTracking"] = nil
Tracking = require "ExtractionModePDA/QuestTracking"
assert(Tracking.get(survivor, data).id == "radio", "selection survives recreating the client module")

local pda = {P = {text = {1,1,1}, edge = {1,1,1}, accent = {1,1,1}, muted = {1,1,1},
    screen = {0,0,0}, row = {0,0,0}, phosphor = {1,1,1}, panel = {0,0,0}, button = {0,0,0}, buttonHover = {0,0,0}}}
local ui = {width = 1100, height = 1400, labels = {}, text = {}, fills = {}}
function ui:drawRect(x, y, w, h, a, r, g, b)
    self.fills[#self.fills + 1] = {x=x, y=y, w=w, h=h, r=r, g=g, b=b}
end
function ui:drawRectBorder() end
function ui:setStencilRect() end
function ui:clearStencilRect() end
function ui:drawTextRight() end
function ui:drawText(value, x, y)
    self.text[#self.text + 1] = value
    self.labels[#self.labels + 1] = {label = value, x = x, y = y}
end
function ui:drawTextCentre(value, x, y) self.labels[#self.labels + 1] = {label = value, x = x, y = y} end
local selectedPage
local view = require("ExtractionModePDA/Dashboard").new({
    text = function(_, fallback, ...)
        local args = {...}
        return (fallback:gsub("%%(%d)", function(n) return tostring(args[tonumber(n)]) end))
    end,
    state = function() return data end, town = function() return "Rosewood" end,
    admin = function() return false end, navigate = function(page) selectedPage = page end,
})
local function render()
    ui.labels, ui.text, ui.fills = {}, {}, {}
    view.render(ui, pda, view.navigation(ui, pda, "home"))
end
local function action(label)
    for _, control in ipairs(ui.labels) do
        if control.label == label then
            for _, rect in ipairs(ui._empdaExtractionHits) do
                if control.x >= rect.x and control.x <= rect.x + rect.w
                    and control.y >= rect.y and control.y <= rect.y + rect.h then return rect.action end
            end
        end
    end
end
render()
assert(action("OVERVIEW") and action("MISSIONS"), "persistent navigation is rendered")
assert(action("READY FOR RAID"), "readiness must render before a native HUD has ever been drawn")
assert(table.concat(ui.text, " "):find("HIDEOUT", 1, true) and table.concat(ui.text, " "):find("TRACKED MISSION", 1, true),
    "the complete overview must include both lower panels")
local cards, primary = {}, false
for _, fill in ipairs(ui.fills) do
    if fill.h >= 180 and fill.w < ui.width * 0.6 then cards[#cards+1] = fill end
    if fill.r == pda.P.accent[1] and fill.g == pda.P.accent[2] and fill.h == view.buttonH then primary = true end
end
assert(#cards == 2 and cards[1].y == cards[2].y and cards[1].x < cards[2].x,
    "hideout and mission summaries must occupy two framed columns on a wide PDA")
assert(primary, "the ready action must have the solid accent fill from the approved layout")
assert(not action("TURN IN"), "missing items must disable home turn-in")
local choose = assert(action("Louisville"))
data.townChoices[2].deathBlocked = true
choose()
assert(#commands == 0, "a destination blocked after rendering must not be submitted")
data.townChoices[2].deathBlocked = false
choose()
assert(commands[1].command == "SelectTown" and commands[1].args.townKey == "Louisville")
local refuel = assert(action("REFUEL"))
data.canContributeHideout = false
refuel()
assert(#commands == 1, "membership changes between draw and click must be respected")
data.canContributeHideout = true
refuel()
assert(commands[2].command == "AddGeneratorFuel")
inventory.parts, now = 2, now + 501
render()
local turnIn = assert(action("TURN IN"))
inHideout = false
turnIn()
assert(#commands == 2, "leaving the hideout before clicking must prevent turn-in")
inHideout = true
turnIn()
assert(commands[3].command == "CompleteQuest" and commands[3].args.questId == "radio")
data.quests.radio = true
render()
assert(Tracking.get(survivor, data) == nil, "completion clears the tracked quest")
assert(action("CHOOSE MISSION"), "the empty state lets the player choose another quest")
assert(Tracking.set(survivor, data, "locked"))
assert(Tracking.set(survivor, data, nil) and Tracking.get(survivor, data) == nil)

ui.width, ui.height, ui._empdaExtractionScroll = 400, 360, 350
render()
for _, rect in ipairs(ui._empdaExtractionHits) do
    assert(rect.w > 0 and rect.h > 0)
    assert(rect.navigation or (rect.y >= ui._empdaExtractionViewport.y and rect.y + rect.h <= ui.height - 18),
        "scrolled content must not create invisible or partially clipped click targets")
end
print("extraction_dashboard_spec: tracking lifecycle, live permissions and scrolling passed")

ISButton = {}
function ISButton:new(x, y, width, height, title, owner, callback)
    return setmetatable({x = x, y = y, width = width, height = height, title = title,
        owner = owner, callback = callback}, {__index = self})
end
function ISButton:initialise() end
function ISButton:instantiate() end
function ISButton:setVisible(v) self.visible = v end
function ISButton:setTitle(v) self.title = v end
function ISButton:setWidth(v) self.width = v end
function ISButton:setHeight(v) self.height = v end
function ISButton:setY(v) self.y = v end
data.quests, ui._empdaExtractionScroll = {}, 0
local panel = {_pdaDock = true, playerNum = 0, buttonHeight = 30, cache = {}, questList = {width = 800}}
function panel.questList:addChild(button) button.parent = self end
function panel:acquiredDefinitions() return definitions end
function panel:questRow(definition)
    self.cache[definition.id] = self.cache[definition.id] or {height = 100}
    return self.cache[definition.id]
end
function panel:layoutRows() self.cache = {} end
Tracking.installPanel(panel, function(_, fallback) return fallback end)
panel:layoutRows()
local track = assert(panel._empdaTrackButtons.radio)
assert(track.visible and not panel._empdaTrackButtons.locked, "only acquired unfinished quests get a tracking button")
local row = panel:questRow(definitions[1])
assert(row.height == 138 and panel:questRow(definitions[1]).height == 138,
    "repeated rendering must not keep growing the mission row")
track.callback(panel, track)
assert(Tracking.get(survivor, data).id == "radio")
assert(track.title == "STOP TRACKING")
track.callback(panel, track)
assert(Tracking.get(survivor, data) == nil)
panel._pdaDock = nil
panel:layoutRows()
assert(not track.visible and panel:questRow(definitions[1]).height == 100,
    "a panel released from the PDA must retain its native row layout")
print("extraction_dashboard_spec: native mission-row tracking controls passed")

ui.width, ui.height, ui._empdaExtractionScroll = 1100, 1400, 0
ExtractionMode.HUDInstance = {minimized = true, action = {title = "READY", isVisible = function() return true end}}
local hud = ExtractionMode.HUDInstance
function hud:updateContent(current) self.action.enable = current.canReady ~= false end
function hud:textFlow() error("hidden HUD layout must never be rendered") end
function hud:onAction() commands[#commands + 1] = {command = "NativeRaidAction"} end
render()
assert(hud.minimized == true, "dashboard must preserve the HUD preference")
local ready, before = assert(action("READY FOR RAID")), #commands
data.state = "RAID"
ready()
assert(#commands == before, "a phase change must not execute a different contextual action")
data.state, data.canReady = "HIDEOUT", false
ready()
assert(#commands == before, "ready availability must be refreshed on click")
data.canReady = true
ready()
assert(commands[#commands].command == "SetReady" and commands[#commands].args.ready == true,
    "readiness must use the server command without depending on native HUD layout")
data.selfReady, data.state, data.countdownSeconds = true, "COUNTDOWN", 8
render()
assert(action("CANCEL READY"))()
assert(commands[#commands].command == "SetReady" and commands[#commands].args.ready == false)
assert(table.concat(ui.text, " "):find("Departing in 8 s", 1, true))
ExtractionMode.HUDInstance = nil
data.selfReady, data.state = false, "HIDEOUT"
render()
assert(action("READY FOR RAID"), "ready must remain available even if no native HUD exists")
ExtractionMode.HUDInstance = hud
data.state, hud.action.title = "RAID", "BOARD HELICOPTER"
render()
assert(action("BOARD HELICOPTER"))()
assert(commands[#commands].command == "NativeRaidAction", "in-raid contextual actions must keep the native handler")
assert(not action("BARTER"), "barter must remain unavailable in raid reference mode")
print("extraction_dashboard_spec: independent ready, cancellation, countdown and native raid actions passed")
