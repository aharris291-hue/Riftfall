--!strict
-- Main (client): starts every client controller. Runs once per player, from
-- StarterPlayerScripts, and survives respawns.

local Controllers = script.Parent.Controllers

local HUDController = require(Controllers.HUDController)
local MovementController = require(Controllers.MovementController)
local FlashlightController = require(Controllers.FlashlightController)
local AtmosphereController = require(Controllers.AtmosphereController)

HUDController.Init()
MovementController.Init()
FlashlightController.Init()
AtmosphereController.Init()

print("[Riftfall] Client ready.")
