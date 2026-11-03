local okSettings, settings = pcall(require, 'PRPGE_Settings')
local okRules, rules = pcall(require, 'PRPGE_DangerRules')
local okDanger, danger = pcall(require, 'RPG_Shared_WorldDanger')
local okLayout, layout = pcall(require, 'PRPGE_SettingsLayout')

if not okSettings or type(settings) ~= 'table'
    or type(settings.Get) ~= 'function'
    or not okRules or type(rules) ~= 'table' or type(rules.Values) ~= 'function' or type(rules.Sandbox) ~= 'function'
    or not okDanger or type(danger) ~= 'table' or type(danger.custom) ~= 'function'
    or not okLayout or type(layout) ~= 'table' or type(layout.SECTIONS) ~= 'table' then
    return false
end

local stages = {
    { strength = 2, toughness = 2, transmission = 1, mortality = 6, sight = 3, hearing = 3, memory = 3, cognition = 3, doors = 0, dragDown = false, fenceLunge = false, respawnHours = 0, respawnPercent = 0 },
    { strength = 2, toughness = 2, transmission = 1, mortality = 5, sight = 2, hearing = 2, memory = 2, cognition = 3, doors = 0, dragDown = true, fenceLunge = false, respawnHours = 0, respawnPercent = 0 },
    { strength = 2, toughness = 2, transmission = 1, mortality = 5, sight = 2, hearing = 2, memory = 2, cognition = 3, doors = 0, dragDown = true, fenceLunge = true, respawnHours = 72, respawnPercent = 5 },
    { strength = 2, toughness = 2, transmission = 1, mortality = 4, sight = 2, hearing = 2, memory = 1, cognition = 1, doors = 50, dragDown = true, fenceLunge = true, respawnHours = 48, respawnPercent = 10 },
    { strength = 1, toughness = 2, transmission = 1, mortality = 4, sight = 1, hearing = 1, memory = 1, cognition = 1, doors = 100, dragDown = true, fenceLunge = true, respawnHours = 24, respawnPercent = 15 },
}

local fields = {
    { suffix = 'Strength', property = 'strength', min = 1, max = 3, choices = { 'ZombieRule_StrengthSuperhuman', 'ZombieRule_Normal', 'ZombieRule_StrengthWeak' }, needs = 'DangerZombieRules' },
    { suffix = 'Toughness', property = 'toughness', min = 1, max = 4, choices = { 'ZombieRule_Tough', 'ZombieRule_Normal', 'ZombieRule_Fragile', 'ZombieRule_Random' }, needs = 'DangerZombieRules' },
    { suffix = 'Transmission', property = 'transmission', min = 1, max = 4, choices = { 'ZombieRule_BloodAndSaliva', 'ZombieRule_SalivaOnly', 'ZombieRule_EveryoneInfected', 'ZombieRule_NoTransmission' }, needs = 'DangerZombieInfection' },
    { suffix = 'Mortality', property = 'mortality', min = 1, max = 7, choices = { 'ZombieRule_Instant', 'ZombieRule_ThirtySeconds', 'ZombieRule_OneMinute', 'ZombieRule_TwelveHours', 'ZombieRule_ThreeDays', 'ZombieRule_TwoWeeks', 'ZombieRule_Never' }, needs = 'DangerZombieInfection' },
    { suffix = 'Sight', property = 'sight', min = 1, max = 3, choices = { 'ZombieRule_Eagle', 'ZombieRule_Normal', 'ZombieRule_Poor' }, needs = 'DangerZombieRules' },
    { suffix = 'Hearing', property = 'hearing', min = 1, max = 3, choices = { 'ZombieRule_Pinpoint', 'ZombieRule_Normal', 'ZombieRule_Poor' }, needs = 'DangerZombieRules' },
    { suffix = 'Memory', property = 'memory', min = 1, max = 3, choices = { 'ZombieRule_Long', 'ZombieRule_Normal', 'ZombieRule_Short' }, needs = 'DangerZombieRules' },
    { suffix = 'Cognition', property = 'cognition', min = 1, max = 3, choices = { 'ZombieRule_NavigateDoors', 'ZombieRule_Navigate', 'ZombieRule_BasicNavigation' }, needs = 'DangerZombieRules' },
    { suffix = 'DoorOpeningPercentage', property = 'doors', min = 0, max = 100, needs = 'DangerZombieRules' },
    { suffix = 'DragDown', property = 'dragDown', boolean = true, needs = 'DangerZombieRules' },
    { suffix = 'FenceLunge', property = 'fenceLunge', boolean = true, needs = 'DangerZombieRules' },
    { suffix = 'RespawnHours', property = 'respawnHours', min = 0, max = 8760, decimal = true, needs = 'DangerZombieRespawn' },
    { suffix = 'RespawnPercent', property = 'respawnPercent', min = 0, max = 100, needs = 'DangerZombieRespawn', scale = 100 },
}

local definitions = settings.DEFS
local byKey = settings.BY_KEY
if type(definitions) ~= 'table' or type(byKey) ~= 'table' then return false end

for stage, defaults in ipairs(stages) do
    for _, field in ipairs(fields) do
        local key = 'WorldDangerS' .. stage .. field.suffix
        if not byKey[key] then
            local definition = {
                key = key,
                group = 'ZombieRules',
                default = defaults[field.property],
                min = field.min,
                max = field.max,
                custom = true,
                needs = field.needs,
            }
            if field.boolean then
                definition.min = 0
                definition.max = 1000
            end
            if field.decimal then definition.decimal = true end
            if field.choices then
                definition.choices = {}
                for _, choice in ipairs(field.choices) do
                    definition.choices[#definition.choices + 1] = choice
                end
            end
            definitions[#definitions + 1] = definition
            byKey[key] = definition
        end
    end
end

layout.BY_ID = layout.BY_ID or {}
layout.FALLBACK = layout.FALLBACK or {}
local zombieSection = layout.BY_ID.ZombieRules
if not zombieSection then
    for _, section in ipairs(layout.SECTIONS) do
        if section.id == 'ZombieRules' then
            zombieSection = section
            break
        end
    end
end
if not zombieSection then
    zombieSection = { id = 'ZombieRules', key = 'ZombieRules', fb = 'ZOMBIES', icon = 'ZHealth', main = {}, more = {} }
    local insertAt = #layout.SECTIONS + 1
    for index, section in ipairs(layout.SECTIONS) do
        if section.id == 'Danger' then
            insertAt = index + 1
            break
        end
    end
    table.insert(layout.SECTIONS, insertAt, zombieSection)
end
layout.BY_ID.ZombieRules = zombieSection
layout.FALLBACK.ZombieRules = 'ZombieRules'

if not rules._empdCustomZombieValues then
    local originalValues = rules.Values
    rules.Values = function(stage)
        local values = originalValues(stage)
        if type(values) ~= 'table' or not danger.custom() then return values end

        local index = math.max(1, math.min(5, math.floor(tonumber(stage) or 1)))
        for _, field in ipairs(fields) do
            local value = settings.Get('WorldDangerS' .. index .. field.suffix)
            if field.boolean then
                if type(value) == 'boolean' then values[field.property] = value end
            elseif type(value) == 'number' then
                values[field.property] = value / (field.scale or 1)
            end
        end
        return values
    end
    rules._empdCustomZombieValues = true
end

if not rules._empdCustomZombieSandbox then
    local originalSandbox = rules.Sandbox
    rules.Sandbox = function(stage)
        local values = originalSandbox(stage)
        if type(values) ~= 'table' or not danger.custom() then return values end

        local index = math.max(1, math.min(5, math.floor(tonumber(stage) or 1)))
        local toughness = settings.Get('WorldDangerS' .. index .. 'Toughness')
        if type(toughness) == 'number' then values['ZombieLore.Toughness'] = toughness end
        return values
    end
    rules._empdCustomZombieSandbox = true
end

return true
