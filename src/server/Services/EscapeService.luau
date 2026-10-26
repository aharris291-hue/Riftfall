--!strict
-- EscapeService: the collapse set-piece after the door opens.
--
--  * Falling debris in the tunnel. Every rock is announced by a red warning
--    circle on the floor first, so it can always be dodged.
--  * The Hollow is released behind the players after a short head start.
--  * The rope bridge planks fall away behind players as they cross.
--
-- If a player dies, they respawn at the temple door; the creature is moved
-- back and gives them the same head start again, and any fallen bridge
-- planks are restored, so the sequence can always be retried.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StalkerService = require(script.Parent.StalkerService)
local CheckpointService = require(script.Parent.CheckpointService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local EscapeService = {}

local active = false
local rng = Random.new()

-- Tunnel bounds that debris may land in.
local TUNNEL_MIN_X, TUNNEL_MAX_X = -6, 6
local TUNNEL_MIN_Z, TUNNEL_MAX_Z = 363, 428
local CEILING_Y = 15.5
local DEBRIS_RADIUS = 4

local function effectsFolder(): Folder
	local folder = workspace:FindFirstChild("EscapeEffects")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "EscapeEffects"
	newFolder.Parent = workspace
	return newFolder
end

local function dropDebris(landing: Vector3)
	local folder = effectsFolder()
	local warning = Instance.new("Part")
	warning.Name = "DebrisWarning"
	warning.Shape = Enum.PartType.Cylinder
	warning.Size = Vector3.new(0.1, DEBRIS_RADIUS * 2, DEBRIS_RADIUS * 2)
	warning.CFrame = CFrame.new(landing + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanQuery = false
	warning.Material = Enum.Material.Neon
	warning.Color = Color3.fromRGB(255, 50, 40)
	warning.Transparency = 0.5
	warning.Parent = folder
	Debris:AddItem(warning, Config.Escape.DebrisWarningTime + 1)

	task.delay(Config.Escape.DebrisWarningTime, function()
		if not active then
			warning:Destroy()
			return
		end
		local rock = Instance.new("Part")
		rock.Name = "FallingRock"
		rock.Size = Vector3.new(3.5, 3, 3.5)
		rock.CFrame = CFrame.new(landing.X, CEILING_Y, landing.Z)
			* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0)
		rock.Anchored = true
		-- Rocks never collide, so they can never wall off the tunnel.
		rock.CanCollide = false
		rock.CanQuery = false
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(80, 74, 70)
		rock.Parent = folder
		local fall = TweenService:Create(rock, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(landing.X, 1.5, landing.Z) * rock.CFrame.Rotation,
		})
		fall:Play()
		fall.Completed:Once(function()
			warning:Destroy()
			for _, player in Players:GetPlayers() do
				local _, humanoid, root = PlayerData.GetAliveCharacter(player)
				if humanoid and root then
					local offset = root.Position - landing
					if Vector3.new(offset.X, 0, offset.Z).Magnitude <= DEBRIS_RADIUS and root.Position.Y < 9 then
						humanoid:TakeDamage(Config.Escape.DebrisDamage)
						Remotes.CameraShake:FireClient(player, 0.5, 1.5)
					end
				end
			end
			TweenService:Create(rock, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			Debris:AddItem(rock, 1.6)
		end)
	end)
end

local function playersInTunnel(): { BasePart }
	local roots = {}
	local zone = Zones.FirstTagged("EscapeZone")
	if not zone then
		return roots
	end
	for _, player in Players:GetPlayers() do
		local _, _, root = PlayerData.GetAliveCharacter(player)
		if root and Zones.Contains(zone, root.Position) then
			table.insert(roots, root)
		end
	end
	return roots
end

local function restoreBridge()
	for _, plank in CollectionService:GetTagged("BridgePlank") do
		if plank:IsA("BasePart") then
			local home = plank:GetAttribute("HomeCFrame")
			if typeof(home) == "CFrame" and (plank:GetAttribute("Fallen") or not plank.Anchored) then
				plank.Anchored = true
				plank.CFrame = home
				plank.AssemblyLinearVelocity = Vector3.zero
				plank.AssemblyAngularVelocity = Vector3.zero
				plank.Transparency = 0
				plank.CanCollide = true
				plank:SetAttribute("Fallen", nil)
			end
		end
	end
end

local function collapsePlank(plank: BasePart)
	plank:SetAttribute("Fallen", true)
	plank.Anchored = false
	-- Once it has fallen out of sight, hide it (kept for restoreBridge).
	task.delay(4, function()
		if plank.Parent and plank:GetAttribute("Fallen") then
			plank.Anchored = true
			plank.Transparency = 1
			plank.CanCollide = false
		end
	end)
end

-- Planks fall once every player who is on the bridge or beyond has passed
-- them, and nobody is still behind them on the route.
local function updateBridge()
	local furthestBack = math.huge
	local anyoneOnBridgeOrBeyond = false
	for _, player in Players:GetPlayers() do
		local _, _, root = PlayerData.GetAliveCharacter(player)
		if root then
			local pos = root.Position
			if pos.Z > 460 and pos.Y > 18 then
				anyoneOnBridgeOrBeyond = true
			end
			furthestBack = math.min(furthestBack, pos.Z)
		end
	end
	if not anyoneOnBridgeOrBeyond then
		return
	end
	for _, plank in CollectionService:GetTagged("BridgePlank") do
		if plank:IsA("BasePart") and plank.Anchored and not plank:GetAttribute("Fallen") then
			if plank.Position.Z < furthestBack - 6 then
				collapsePlank(plank)
			end
		end
	end
end

-- Someone standing on the cliff top while planks are missing means they
-- were left behind: rebuild the bridge so they are never stranded.
local function rescueStragglers()
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		local _, _, root = PlayerData.GetAliveCharacter(player)
		if root and data and not data.Finished then
			local pos = root.Position
			if pos.Z > 445 and pos.Z < 461 and pos.Y > 18 then
				for _, plank in CollectionService:GetTagged("BridgePlank") do
					if plank:GetAttribute("Fallen") then
						restoreBridge()
						return
					end
				end
			end
		end
	end
end

function EscapeService.Begin()
	if active then
		return
	end
	active = true
	StalkerService.StartHunt(Config.Escape.HuntDelay)
end

function EscapeService.IsActive(): boolean
	return active
end

function EscapeService.Reset()
	active = false
	local folder = workspace:FindFirstChild("EscapeEffects")
	if folder then
		folder:ClearAllChildren()
	end
end

-- Called when a player dies during the escape.
local function onPlayerDied(player: Player)
	if not active then
		return
	end
	-- If nobody else is still running, put the creature back so the
	-- respawned player gets a fair head start again.
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local _, _, root = PlayerData.GetAliveCharacter(other)
			if root and root.Position.Z > 300 and root.Position.Z < 447 and root.Position.Y < 18 then
				return
			end
		end
	end
	StalkerService.StartHunt(Config.Escape.HuntDelay + Players.RespawnTime)
	restoreBridge()
end

function EscapeService.Init()
	CheckpointService.OnPlayerDied(onPlayerDied)

	task.spawn(function()
		local lastDebris = 0
		while true do
			task.wait(0.2)
			if not active then
				continue
			end
			local now = os.clock()
			if now - lastDebris >= Config.Escape.DebrisInterval then
				local roots = playersInTunnel()
				if #roots > 0 then
					lastDebris = now
					local root = roots[rng:NextInteger(1, #roots)]
					-- Aim near (and slightly ahead of) a running player.
					local x = math.clamp(root.Position.X + rng:NextNumber(-5, 5), TUNNEL_MIN_X, TUNNEL_MAX_X)
					local z = math.clamp(root.Position.Z + rng:NextNumber(-3, 12), TUNNEL_MIN_Z, TUNNEL_MAX_Z)
					dropDebris(Vector3.new(x, 0, z))
					if rng:NextNumber() < 0.35 then
						Remotes.CameraShake:FireAllClients(0.8, 0.5)
					end
				end
			end
			updateBridge()
			rescueStragglers()
		end
	end)
end

return EscapeService
