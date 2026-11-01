local Tracking = {}
local KEY = "ExtractionModePDATrackedQuest"
local LEGACY_KEY = "ViewpointExtractionSupportTrackedQuest"

local function modData(player)
    local saved = player:getModData()
    if saved[KEY] == nil and saved[LEGACY_KEY] ~= nil then saved[KEY] = saved[LEGACY_KEY] end
    saved[LEGACY_KEY] = nil
    return saved
end

local function quests()
    return ExtractionMode and ExtractionMode.Quests
end

function Tracking.available(data)
    local api = quests()
    local result = {}
    if not api or data.state == nil or type(data.quests) ~= "table" then return result end
    for _, definition in ipairs(api.acquiredDefinitions(data.quests)) do
        if not api.isCompleted(data.quests, definition.id) then result[#result + 1] = definition end
    end
    return result
end

function Tracking.get(player, data)
    if not player then return nil end
    local saved = modData(player)
    local id = saved[KEY]
    if not id or data.state == nil or type(data.quests) ~= "table" then return nil end
    for _, definition in ipairs(Tracking.available(data)) do
        if definition.id == id then return definition end
    end
    saved[KEY] = nil
    return nil
end

function Tracking.set(player, data, id)
    if not player then return false end
    if id == nil then modData(player)[KEY] = nil; return true end
    for _, definition in ipairs(Tracking.available(data)) do
        if definition.id == id then
            modData(player)[KEY] = id
            return true
        end
    end
    return false
end

function Tracking.installPanel(panel, text)
    if panel._empdaQuestTracking or type(panel.questRow) ~= "function"
        or type(panel.layoutRows) ~= "function" then return end
    panel._empdaQuestTracking = true
    local originalRow, originalLayout = panel.questRow, panel.layoutRows
    panel.questRow = function(self, definition)
        local row = originalRow(self, definition)
        local api = quests()
        local data = ExtractionMode.Client.stateFor(self.playerNum or 0)
        if self._pdaDock and api.isAcquired(data.quests, definition)
            and not api.isCompleted(data.quests, definition.id) and not row._empdaTrackingY then
            row._empdaTrackingY = row.height - 8
            row.height = row.height + (self.buttonHeight or 30) + 8
        end
        return row
    end
    panel.layoutRows = function(self, ...)
        originalLayout(self, ...)
        self._empdaTrackButtons = self._empdaTrackButtons or {}
        for _, button in pairs(self._empdaTrackButtons) do button:setVisible(false) end
        if not self._pdaDock then return end
        local data = ExtractionMode.Client.stateFor(self.playerNum or 0)
        local player = getSpecificPlayer(self.playerNum or 0)
        local tracked = Tracking.get(player, data)
        local y = 0
        for _, definition in ipairs(self:acquiredDefinitions()) do
            local row = self:questRow(definition)
            if row._empdaTrackingY then
                local button = self._empdaTrackButtons[definition.id]
                if not button or button.parent ~= self.questList then
                    button = ISButton:new(12, 0, 220, self.buttonHeight or 30, "", self, function(owner, clicked)
                        local currentData = ExtractionMode.Client.stateFor(owner.playerNum or 0)
                        local currentPlayer = getSpecificPlayer(owner.playerNum or 0)
                        local current = Tracking.get(currentPlayer, currentData)
                        local id = clicked.questId
                        if current and current.id == id then id = nil end
                        Tracking.set(currentPlayer, currentData, id)
                        owner:layoutRows(false)
                    end)
                    button:initialise()
                    button:instantiate()
                    button.questId = definition.id
                    self.questList:addChild(button)
                    self._empdaTrackButtons[definition.id] = button
                end
                button:setTitle(tracked and tracked.id == definition.id
                    and text("Untrack", "STOP TRACKING") or text("Track", "TRACK MISSION"))
                button:setWidth(math.min(self.questList.width - 38,
                    getTextManager():MeasureStringX(UIFont.Small, button.title) + 28))
                button:setHeight(self.buttonHeight or 30)
                button:setY(y + row._empdaTrackingY)
                button:setVisible(true)
            end
            y = y + row.height
        end
        local compatibility = ExtractionMode.UICompatibility
        if compatibility and compatibility.refreshJoypadButtons then compatibility.refreshJoypadButtons(self) end
    end
end

return Tracking
