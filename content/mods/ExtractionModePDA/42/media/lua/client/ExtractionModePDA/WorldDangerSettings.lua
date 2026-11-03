pcall(require, 'EMPD_WorldDangerConfig')

local ok, panel = pcall(require, 'PRPGE_SettingsPanel')
if not ok or type(panel) ~= 'table' or type(panel.GROUPS) ~= 'table' then return false end

local function ensureGroup()
    for _, group in ipairs(panel.GROUPS) do
        if group == 'ZombieRules' then return end
    end

    local insertAt = #panel.GROUPS + 1
    for index, group in ipairs(panel.GROUPS) do
        if group == 'Danger' then
            insertAt = index + 1
            break
        end
    end
    table.insert(panel.GROUPS, insertAt, 'ZombieRules')
end

ensureGroup()

if not panel._empdZombieRulesHint and type(panel.prerender) == 'function' then
    local originalPrerender = panel.prerender
    panel.prerender = function(self, ...)
        local result = originalPrerender(self, ...)
        local isCustom = math.floor(tonumber(self.draft and self.draft.WorldDangerDifficulty) or 2) == 6
        if self.group == 'ZombieRules' and not isCustom then
            local key = 'UI_PRPGE_ZombieRulesCustomOnly'
            local message = getText and getText(key) or key
            if message ~= key then self:drawText(message, 22, 115, 0.65, 0.70, 0.69, 1, UIFont.Small) end
        end
        return result
    end
    panel._empdZombieRulesHint = true
end

return true
