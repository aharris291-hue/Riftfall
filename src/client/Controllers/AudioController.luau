--!strict
-- AudioController: music, jungle ambience and creature sounds, all on this
-- player's machine only.
--
-- Every sound belongs to one of three SoundGroups (Music, Effects, Ambience)
-- whose volumes follow the Settings menu sliders.
--
-- Music has three moods, crossfaded smoothly rather than cut:
--   Explore   low drone while things are quiet
--   Suspense  tense drones while the Rift Stalker is searching or nearby
--   Chase     drums while it is chasing you, and during the escape
-- The mood is read from what the client can already see (the creature's
-- State attribute, its distance, and the story Phase), so no extra network
-- traffic is needed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ClientState = require(script.Parent.Parent.ClientState)
local ClientSettings = require(script.Parent.Parent.ClientSettings)

local player = Players.LocalPlayer

local AudioController = {}

type Mood = "Explore" | "Suspense" | "Chase"

local groups: { [string]: SoundGroup } = {}
local GROUP_SETTING = { Music = "MusicVolume", Effects = "EffectsVolume", Ambience = "AmbienceVolume" }

local MUSIC_VOLUME: { [Mood]: number } = { Explore = 0.45, Suspense = 0.5, Chase = 0.55 }
local FADE_TIME = 2.5
local ROAR_COOLDOWN = 8

-- Returns the SoundGroup by name (Music, Effects or Ambience).
function AudioController.Group(name: string): SoundGroup?
	return groups[name]
end

-- Creates a Sound for a Config.Sounds entry, or nil if no ID is set.
function AudioController.MakeSound(key: string, groupName: string, looped: boolean, volume: number, parent: Instance?): Sound?
	local id = (Config.Sounds :: any)[key]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = id
	sound.Looped = looped
	sound.Volume = volume
	sound.SoundGroup = groups[groupName]
	sound.Parent = parent or SoundService
	return sound
end

local function buildGroups()
	for name, settingKey in GROUP_SETTING do
		local group = SoundService:FindFirstChild(name)
		if not (group and group:IsA("SoundGroup")) then
			group = Instance.new("SoundGroup")
			group.Name = name
			group.Parent = SoundService
		end
		groups[name] = group :: SoundGroup
		(group :: SoundGroup).Volume = ClientSettings.Get(settingKey)
	end
	ClientSettings.OnChanged(function(key, value)
		for name, settingKey in GROUP_SETTING do
			if key == settingKey and type(value) == "number" then
				groups[name].Volume = value
			end
		end
	end)
end

-- Inside the temple and tunnel the jungle is muffled (matches Atmosphere).
local function isIndoors(position: Vector3): boolean
	-- The Chapter 2 facility (Z > 1300) is indoors too.
	return (position.Z > 298 and position.Z < 432 and position.Y < 24) or position.Z > 1300
end

local function stalkerInfo(): (string?, number)
	local stalker = workspace:FindFirstChild("RiftStalker")
	local root = stalker and stalker:FindFirstChild("HumanoidRootPart")
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not (stalker and root and root:IsA("BasePart") and myRoot and myRoot:IsA("BasePart")) then
		return nil, math.huge
	end
	local state = stalker:GetAttribute("State")
	return if type(state) == "string" then state else nil, (root.Position - myRoot.Position).Magnitude
end

local function pickMood(): Mood
	local state, distance = stalkerInfo()
	if ReplicatedStorage:GetAttribute("Phase") == "Escape" then
		return "Chase"
	end
	if (state == "Chase" or state == "Attack" or state == "Hunt") and distance < 140 then
		return "Chase"
	end
	if state == "Investigate" or state == "Search" or distance < 60 or ClientState.Danger > 0.15 then
		return "Suspense"
	end
	return "Explore"
end

local function startMusic()
	local tracks: { [Mood]: Sound } = {}
	for _, mood in { "Explore", "Suspense", "Chase" } :: { Mood } do
		local sound = AudioController.MakeSound("Music" .. mood, "Music", true, 0)
		if sound then
			sound:Play()
			tracks[mood] = sound
		end
	end
	local current: Mood? = nil
	local candidate: Mood = "Explore"
	local candidateSince = 0
	task.spawn(function()
		while true do
			task.wait(0.5)
			local mood = pickMood()
			-- Calm down slowly (the music should not flicker back to calm the
			-- instant the creature turns away), but react to danger at once.
			if mood ~= candidate then
				candidate = mood
				candidateSince = os.clock()
			end
			local wait = if mood == "Explore" then 6 elseif mood == "Suspense" and current == "Chase" then 4 else 0
			if mood ~= current and os.clock() - candidateSince >= wait then
				current = mood
				for trackMood, sound in tracks do
					local target = if trackMood == mood then MUSIC_VOLUME[trackMood] else 0
					TweenService:Create(sound, TweenInfo.new(FADE_TIME), { Volume = target }):Play()
				end
			end
		end
	end)
end

local function startAmbience()
	local jungle = AudioController.MakeSound("Jungle", "Ambience", true, 0.5)
	if not jungle then
		return
	end
	jungle:Play()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local camera = workspace.CurrentCamera
			local indoors = camera ~= nil and isIndoors(camera.CFrame.Position)
			local target = if indoors then 0.08 else 0.5
			if math.abs(jungle.Volume - target) > 0.01 then
				TweenService:Create(jungle, TweenInfo.new(1.5), { Volume = target }):Play()
			end
		end
	end)
end

-- The creature roars (from where it stands) when it starts chasing.
local function watchCreature()
	local lastRoar = 0
	local function bind(stalker: Instance)
		if stalker.Name ~= "RiftStalker" or not stalker:IsA("Model") then
			return
		end
		stalker:GetAttributeChangedSignal("State"):Connect(function()
			local state = stalker:GetAttribute("State")
			if (state == "Chase" or state == "Hunt") and os.clock() - lastRoar > ROAR_COOLDOWN then
				local root = stalker:FindFirstChild("HumanoidRootPart")
				if root then
					lastRoar = os.clock()
					local roar = AudioController.MakeSound("CreatureRoar", "Effects", false, 1, root)
					if roar then
						roar.RollOffMaxDistance = 220
						roar.RollOffMinDistance = 20
						roar:Play()
						roar.Ended:Once(function()
							roar:Destroy()
						end)
					end
				end
			end
		end)
	end
	workspace.ChildAdded:Connect(bind)
	for _, child in workspace:GetChildren() do
		bind(child)
	end
end

-- Splintering wood as the rope bridge collapses behind the players.
local function watchBridge()
	local lastCrack = 0
	local function bind(plank: Instance)
		plank:GetAttributeChangedSignal("Fallen"):Connect(function()
			if plank:GetAttribute("Fallen") ~= true or os.clock() - lastCrack < 4 or not plank:IsA("BasePart") then
				return
			end
			lastCrack = os.clock()
			local crack = AudioController.MakeSound("BridgeCrack", "Effects", false, 0.9, plank)
			if crack then
				crack.RollOffMaxDistance = 150
				crack:Play()
				task.delay(5, function()
					crack:Destroy()
				end)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal("BridgePlank"):Connect(bind)
	for _, plank in CollectionService:GetTagged("BridgePlank") do
		bind(plank)
	end
end

function AudioController.Init()
	buildGroups()
	startAmbience()
	startMusic()
	watchCreature()
	watchBridge()
end

return AudioController
