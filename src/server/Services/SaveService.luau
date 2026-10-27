--!strict
-- SaveService: saves each player's progress with DataStoreService so it is
-- still there next time they play.
--
-- What is saved (and only this; the server builds it, never the client):
--   Checkpoint   furthest checkpoint reached this run (0 = start, 1 = camp,
--                2 = temple). Rejoining puts you back there.
--   Evidence     every expedition ID tag you have ever found
--   Completed    whether you have finished Chapter 1, and your best time
--   Settings     volumes, subtitle size, brightness, graphics (validated)
--
-- Saves happen at checkpoints, when evidence is found, when you finish, when
-- you leave, and a few seconds after you change a setting. Every save is
-- retried, and the player is told honestly whether it worked. In a place
-- that has never been published, Roblox does not allow saving at all; the
-- player is told so once and the game carries on normally.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Story = require(ReplicatedStorage.Shared.Story)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)
local CheckpointService = require(script.Parent.CheckpointService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SaveService = {}

local STORE_NAME = "RiftfallProgress_v1"
local RETRIES = 3
local SETTINGS_SAVE_DELAY = 6

-- The objective to show when resuming from each checkpoint.
local RESUME_OBJECTIVE = { [1] = "Gate", [2] = "Puzzle" }
local RESUME_NAME = { [1] = "the camp", [2] = "the temple" }

export type Profile = {
	Version: number,
	Checkpoint: number,
	Evidence: { [string]: boolean },
	Completed: boolean,
	BestTime: number?,
	Settings: Settings.Values,
}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}
local settingsSaveQueued: { [Player]: boolean } = {}
local toldUnavailable: { [Player]: boolean } = {}

local function newProfile(): Profile
	return {
		Version = 1,
		Checkpoint = 0,
		Evidence = {},
		Completed = false,
		BestTime = nil,
		Settings = table.clone(Settings.Defaults),
	}
end

-- Rebuilds a profile from stored data, keeping only known, valid fields.
local function cleanProfile(raw: any): Profile
	local profile = newProfile()
	if type(raw) ~= "table" then
		return profile
	end
	if type(raw.Checkpoint) == "number" and RESUME_OBJECTIVE[raw.Checkpoint] then
		profile.Checkpoint = raw.Checkpoint
	end
	if type(raw.Evidence) == "table" then
		for _, id in Story.Evidence do
			if raw.Evidence[id] == true then
				profile.Evidence[id] = true
			end
		end
	end
	profile.Completed = raw.Completed == true
	if type(raw.BestTime) == "number" and raw.BestTime > 0 then
		profile.BestTime = raw.BestTime
	end
	profile.Settings = Settings.Sanitize(raw.Settings)
	return profile
end

local function retry<T>(action: () -> T): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, RETRIES do
		ok, result = pcall(action)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	return false, result
end

local function isUnavailableError(err: any): boolean
	local text = string.lower(tostring(err))
	return string.find(text, "publish", 1, true) ~= nil
		or string.find(text, "api services", 1, true) ~= nil
		or string.find(text, "studio access", 1, true) ~= nil
		or string.find(text, "403", 1, true) ~= nil
end

local function tellUnavailable(player: Player)
	if toldUnavailable[player] then
		return
	end
	toldUnavailable[player] = true
	StoryService.Toast(player, "Saving is off in this test copy (publish the game to turn it on)", "warning")
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

-- Saves the player's profile. Returns true only if it really saved.
function SaveService.Save(player: Player, announce: boolean?): boolean
	local profile = profiles[player]
	if not profile or not loaded[player] then
		return false
	end
	if not store then
		if announce then
			tellUnavailable(player)
		end
		return false
	end
	local snapshot = table.clone(profile)
	local ok, err = retry(function()
		return (store :: DataStore):UpdateAsync(key(player), function()
			return snapshot
		end)
	end)
	if not ok then
		warn("[SaveService] Save failed for", player.Name, err)
	end
	if announce and player.Parent then
		if ok then
			StoryService.Toast(player, "Progress saved", "good")
		else
			StoryService.Toast(player, "Couldn't save progress. It will try again at the next checkpoint.", "warning")
		end
	end
	return ok
end

local function sendSettings(player: Player)
	local profile = profiles[player]
	if profile then
		Remotes.SettingsLoaded:FireClient(player, profile.Settings)
	end
end

-- Puts a returning player back at their saved checkpoint.
local function resume(player: Player, profile: Profile)
	local order = profile.Checkpoint
	if order <= 0 then
		return
	end
	for _, zone in CollectionService:GetTagged("Checkpoint") do
		local spawnPos = zone:GetAttribute("SpawnPosition")
		if zone:GetAttribute("Order") == order and typeof(spawnPos) == "Vector3" then
			CheckpointService.Set(player, order, spawnPos, nil)
			StoryService.SetObjective(RESUME_OBJECTIVE[order])
			StoryService.Toast(player, "Welcome back. Continuing from " .. RESUME_NAME[order] .. ".", "checkpoint")
			local character = player.Character
			if character then
				character:PivotTo(CFrame.new(spawnPos) * CFrame.Angles(0, math.pi, 0))
			end
			return
		end
	end
end

local function onPlayerAdded(player: Player)
	local profile = newProfile()
	profiles[player] = profile
	if store then
		local ok, result = retry(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if not player.Parent then
			return
		end
		if ok then
			profile = cleanProfile(result)
			profiles[player] = profile
		elseif isUnavailableError(result) then
			-- Unpublished place, or Studio access to saving switched off.
			store = nil
		else
			warn("[SaveService] Load failed for", player.Name, result)
			StoryService.Toast(player, "Couldn't load your saved progress. Starting fresh.", "warning")
		end
	end
	loaded[player] = true
	sendSettings(player)
	if not store then
		task.delay(6, tellUnavailable, player)
		return
	end
	-- Wait for the first character so the resume teleport lands.
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(1)
	if player.Parent then
		resume(player, profile)
	end
end

local function onSettings(player: Player, values: any)
	if not PlayerData.RateLimit(player, "Settings", 0.25) then
		return
	end
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Settings = Settings.Sanitize(values)
	if settingsSaveQueued[player] then
		return
	end
	settingsSaveQueued[player] = true
	task.delay(SETTINGS_SAVE_DELAY, function()
		settingsSaveQueued[player] = nil
		if player.Parent then
			SaveService.Save(player, false)
		end
	end)
end

-- Called by other services when something worth saving happens.
function SaveService.OnCheckpoint(player: Player, order: number)
	local profile = profiles[player]
	if profile and RESUME_OBJECTIVE[order] and order > profile.Checkpoint then
		profile.Checkpoint = order
		task.spawn(SaveService.Save, player, true)
	end
end

function SaveService.OnEvidence(player: Player, id: string)
	local profile = profiles[player]
	if profile and table.find(Story.Evidence, id) and not profile.Evidence[id] then
		profile.Evidence[id] = true
		task.spawn(SaveService.Save, player, false)
	end
end

function SaveService.OnFinished(player: Player, seconds: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Completed = true
	profile.Checkpoint = 0 -- Next time, start the chapter from the beginning.
	if not profile.BestTime or seconds < profile.BestTime then
		profile.BestTime = math.floor(seconds)
	end
	task.spawn(SaveService.Save, player, true)
end

function SaveService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[SaveService] Saving unavailable:", result)
	end

	Remotes.SaveSettings.OnServerEvent:Connect(onSettings)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		SaveService.Save(player, false)
		profiles[player] = nil
		loaded[player] = nil
		settingsSaveQueued[player] = nil
		toldUnavailable[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				SaveService.Save(player, false)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return SaveService
