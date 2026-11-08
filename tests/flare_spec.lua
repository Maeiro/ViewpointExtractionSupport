local function event()
    local handlers = {}
    return { Add = function(fn) handlers[#handlers + 1] = fn end,
        fire = function(...) for _, fn in ipairs(handlers) do fn(...) end end }
end
Events = {}
for _, name in ipairs({ "OnServerCommand", "OnClientCommand", "OnGameStart", "OnTick", "OnDisconnect",
    "OnMainMenuEnter", "OnGameBoot", "OnCreatePlayer", "OnEquipPrimary", "OnEquipSecondary" }) do
    Events[name] = event()
end
local wall, simulation, multiplayer = 0, 0, false
getTimestampMs = function() return wall end
isClient = function() return multiplayer end
local nativeCalls, sent, rendered = {}, {}, {}
ExtractionMode = {
    Client = { sendCommand = function(player, command, args)
        nativeCalls[#nativeCalls + 1] = { player, command, args }
        return "native-result"
    end },
    Util = { timerNowMs = function() return simulation end },
}
ViewpointExtractionSupportBridge = {
    beginFlares = function() rendered = {} end,
    flare = function(...) rendered[#rendered + 1] = { ... } end,
    endFlares = function() end,
    clearFlares = function() rendered = {} end,
}
sendClientCommand = function(...) sent[#sent + 1] = { ... } end
local weapon = { ammo = 1, damage = 0, data = {} }
function weapon:getFullType() return "ExtractionMode.ExtractionFlareGun" end
local player = { dead = false, weapon = weapon }
function player:isDead() return self.dead end
function player:getPrimaryHandItem() return self.weapon end
function player:getX() return 100 end
function player:getY() return 200 end
function player:getZ() return 2 end
function player:getForwardDirectionX() return 1 end
function player:getForwardDirectionY() return 0 end

local Effects = require "ViewpointExtractionSupport/FlareEffects"
local args = { source = "ammo-consumed" }
assert(ExtractionMode.Client.sendCommand(player, "FireFlare", args) == "native-result")
ExtractionMode.Client.sendCommand(player, "FireFlare", args)
Effects.update()
assert(#nativeCalls == 2 and nativeCalls[1][3] == args)
assert(#rendered == 1 and rendered[1][1] == 100 and rendered[1][3] == 2)
wall, simulation = 5000, 5000
Effects.update()
assert(rendered[1][6] == 5)
wall = 10000
Effects.update()
assert(rendered[1][6] == 5, "pause must not age the signal")
Effects.configure(false)
assert(#rendered == 0)
Effects.configure(true)
assert(#rendered == 1)
assert(weapon.ammo == 1 and weapon.damage == 0)

Effects.reset()
multiplayer = true
ExtractionMode.Client.sendCommand(player, "FireFlare", args)
Effects.update()
assert(#rendered == 1 and #sent == 1, "local MP signal must not wait for an acknowledgement")
assert(next(sent[1][4]) == nil, "client must not supply coordinates")
Events.OnServerCommand.fire("ViewpointExtractionSupport", "FlareShot", { x = nil, y = 0, z = 0, dx = 1, dy = 0 })
Effects.update()
assert(#rendered == 1)

local function list(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end
local near = { getX = function() return 110 end, getY = function() return 200 end }
local far = { getX = function() return 500 end, getY = function() return 200 end }
getOnlinePlayers = function() return list({ player, near, far }) end
local broadcast = {}
sendServerCommand = function(...) broadcast[#broadcast + 1] = { ... } end
dofile(projectClientPath .. "/../server/ViewpointExtractionSupport.lua")
Events.OnClientCommand.fire("ViewpointExtractionSupport", "FlareShot", player, { x = 9999 })
assert(#broadcast == 1 and broadcast[1][1] == near)
assert(broadcast[1][4].x == 100, "server must derive the position")
Events.OnClientCommand.fire("ViewpointExtractionSupport", "FlareShot", player)
assert(#broadcast == 1, "server must limit duplicate requests")
wall = wall + 2000
player.weapon = { getFullType = function() return "Base.Pistol" end }
Events.OnClientCommand.fire("ViewpointExtractionSupport", "FlareShot", player)
assert(#broadcast == 1)
player.weapon = weapon
player.dead = true
Events.OnClientCommand.fire("ViewpointExtractionSupport", "FlareShot", player)
assert(#broadcast == 1)
player.dead = false
Events.OnServerCommand.fire("ViewpointExtractionSupport", "FlareShot", broadcast[1][4])
Effects.update()
assert(#rendered == 2)
for i = 1, 10 do Events.OnServerCommand.fire("ViewpointExtractionSupport", "FlareShot", broadcast[1][4]) end
Effects.update()
assert(#rendered == 8, "active signals must be bounded")
simulation = simulation + 20000
Effects.update()
assert(#rendered == 0, "expired signals must be removed")
Events.OnMainMenuEnter.fire()
assert(#rendered == 0)

local script = { ammo = 1, damage = 0 }
function script:DoParam(key, value) self[key] = value end
function script:setWeaponSprite(value) self.WeaponSprite = value end
ScriptManager = { instance = { getItem = function(_, name)
    assert(name == "ExtractionMode.ExtractionFlareGun")
    return script
end } }
local texture = {}
getTexture = function(path) assert(path == "media/textures/Item_VESExtractionFlareGun.png"); return texture end
function weapon:setWeaponSprite(value) self.sprite = value end
function weapon:setOriginalWeaponSprite(value) self.originalSprite = value end
function weapon:setWorldStaticModel(value) self.world = value end
function weapon:setTexture(value) self.texture = value end
local Appearance = dofile(projectClientPath .. "/../shared/ViewpointExtractionSupport/FlareAppearance.lua")
Events.OnGameBoot.fire()
assert(script.Icon == "VESExtractionFlareGun" and script.WorldStaticModel == "Base.VESExtractionFlareGun")
assert(script.ammo == 1 and script.damage == 0)
Appearance.apply(weapon)
assert(weapon.sprite == "VESExtractionFlareGun" and weapon.originalSprite == weapon.sprite)
assert(weapon.world == "Base.VESExtractionFlareGun" and weapon.texture == texture)
assert(weapon.ammo == 1 and weapon.damage == 0 and next(weapon.data) == nil)
Appearance.apply({ getFullType = function() return "Base.Pistol" end })
print("PASS: flare appearance, native command preservation, SP pause/expiry, MP authority/range/deduplication, bounds and cleanup")
