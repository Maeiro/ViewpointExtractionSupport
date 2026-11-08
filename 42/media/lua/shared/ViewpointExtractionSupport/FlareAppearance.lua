local Appearance = {}
local fullType = "ExtractionMode.ExtractionFlareGun"
local model = "VESExtractionFlareGun"

function Appearance.install()
    if not ScriptManager or not ScriptManager.instance then return end
    local script = ScriptManager.instance:getItem(fullType)
    if not script then return end
    script:DoParam("Icon", model)
    script:setWeaponSprite(model)
    script:DoParam("WorldStaticModel", "Base." .. model)
end

function Appearance.apply(item)
    if not item or item:getFullType() ~= fullType then return end
    item:setWeaponSprite(model)
    item:setOriginalWeaponSprite(model)
    item:setWorldStaticModel("Base." .. model)
    local texture = getTexture("media/textures/Item_" .. model .. ".png")
    if texture then item:setTexture(texture) end
end

local function inventory(container)
    if not container then return end
    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        Appearance.apply(item)
        if instanceof(item, "InventoryContainer") then inventory(item:getInventory()) end
    end
end

local function playerCreated(_, player)
    if player then inventory(player:getInventory()) end
end

Events.OnGameBoot.Add(Appearance.install)
Events.OnGameStart.Add(function()
    Appearance.install()
    for index = 0, (getNumActivePlayers and getNumActivePlayers() or 1) - 1 do
        playerCreated(index, getSpecificPlayer(index))
    end
end)
Events.OnCreatePlayer.Add(playerCreated)
Events.OnEquipPrimaryHand.Add(function(_, item) Appearance.apply(item) end)
Events.OnEquipSecondaryHand.Add(function(_, item) Appearance.apply(item) end)

return Appearance
