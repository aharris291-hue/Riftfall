--!strict
-- Main (client): starts every client controller. Runs once per player, from
-- StarterPlayerScripts, and survives respawns.

local Controllers = script.Parent.Controllers
local ClientSettings = require(script.Parent.ClientSettings)

local HUDController = require(Controllers.HUDController)
local MovementController = require(Controllers.MovementController)
local FlashlightController = require(Controllers.FlashlightController)
local AtmosphereController = require(Controllers.AtmosphereController)
local AudioController = require(Controllers.AudioController)
local CrouchPose = require(Controllers.CrouchPose)

ClientSettings.Init()
AudioController.Init()
HUDController.Init()
MovementController.Init()
CrouchPose.Init()
FlashlightController.Init()
AtmosphereController.Init()

print("[Riftfall] Client ready.")
