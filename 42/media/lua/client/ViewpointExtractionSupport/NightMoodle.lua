local moodleId = "viewpointextractionsupport:night_luck"
local iconPath = "media/ui/Moodles/128/ViewpointExtractionSupport_NightLuck.png"

local function installIcon()
    local framework = ISMoodlesInLua
    if not framework then return end

    local iconSets = framework.MoodleIconMap_Custom
    if type(iconSets) == "table" then
        iconSets[moodleId] = {
            [1] = iconPath,
            [2] = iconPath,
            [3] = iconPath,
            [4] = iconPath,
        }
    end

    local original = framework.getIconTexturePath
    if type(original) ~= "function" or framework.nightLuckIconHook == original then return end

    local patched = function(self, moodleTranslationName)
        if tostring(moodleTranslationName) == moodleId then return iconPath end
        return original(self, moodleTranslationName)
    end
    framework.getIconTexturePath = patched
    framework.nightLuckIconHook = patched
end

installIcon()
Events.OnGameStart.Add(installIcon)
