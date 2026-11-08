local Visibility = require "ViewpointExtractionSupport/PlayerHudVisibility"
local enabled, open = true, false
local setting = { getValue = function() return enabled end }
Visibility.install(setting)
local function element()
    return { setVisible = function(self, value) self.visible = value end }
end
local card = element()
card._shown, card.portrait, card.levelBadge = true, element(), element()
local polls = 0
local api = { card = card, Poll = function() polls = polls + 1; return true end }
api.Ensure = function() api.Poll(card); return card end
package.loaded["PRPGE_PlayerCard"] = api
ViewpointInvScreen = { isUp = function() return open end }
Visibility.install(setting)
local wrapper = api.Ensure
Visibility.install(setting)
assert(api.Ensure == wrapper, "installation must be idempotent")
assert(api.Ensure() == card and polls == 1)
open = true
api.Ensure()
assert(card.visible == false and card.portrait.visible == false and card.levelBadge.visible == false)
assert(polls == 1, "hidden HUD must not handle polled clicks")
open = false
api.Ensure()
assert(card.visible == true and polls == 2)
open = true
api.Ensure()
card._shown = false
open = false
api.Ensure()
assert(card.visible == false, "closing inventory must respect the native HUD preference")
card._shown = true
open = true
api.Ensure()
enabled = false
Visibility.install(setting)
assert(card.visible == true, "disabling the option restores the card immediately")
enabled = true
api.Ensure()
card._empdaErgonomicHidden = true
open = false
api.Ensure()
assert(card.visible == false, "another integration's hidden state must be respected")
card._empdaErgonomicHidden = nil
open = true
api.Ensure()
ViewpointInvScreen = nil
api.Ensure()
assert(card.visible == true, "missing Viewpoint screen must release the hidden state")
print("PDA player HUD visibility checks passed")
