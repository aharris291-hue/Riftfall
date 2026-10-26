-- Smoke test: load real modules under Lune with mocked Roblox services, to
-- catch bad property names/types in instance construction code.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local repo = process.args[1]
local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")

-- Signal mock that records connections so tests can fire them.
local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Once(fn)
		return self:Connect(fn)
	end
	function s:Fire(...)
		for _, fn in self.handlers do
			fn(...)
		end
	end
	return s
end

local function remotesMock()
	local r = {}
	return setmetatable(r, {
		__index = function(t, k)
			local ev = { OnClientEvent = Signal(), OnServerEvent = Signal(), Name = k }
			function ev:FireServer() end
			function ev:FireClient() end
			function ev:FireAllClients() end
			rawset(t, k, ev)
			return ev
		end,
	})
end
local Remotes = remotesMock()

local attrs = {}
local attrSignals = {}
local function attrObj(extra)
	local o = extra or {}
	function o:GetAttribute(k)
		return attrs[k]
	end
	function o:SetAttribute(k, v)
		attrs[k] = v
	end
	function o:GetAttributeChangedSignal(k)
		attrSignals[k] = attrSignals[k] or Signal()
		return attrSignals[k]
	end
	return o
end

local playerGui = roblox.Instance.new("Folder")
local LocalPlayer = attrObj({
	Character = nil,
	CharacterAdded = Signal(),
	WaitForChild = function(_, name)
		return playerGui
	end,
})

-- Module loading: map Rojo paths to files.
local loaded = {}
local function makeScript(path)
	return { __path = path }
end
local scriptMeta
local function node(path)
	return setmetatable({ __path = path }, scriptMeta)
end
scriptMeta = {
	__index = function(t, k)
		local p = rawget(t, "__path")
		if k == "Parent" then
			local parts = string.split(p, "/")
			table.remove(parts)
			return node(table.concat(parts, "/"))
		end
		return node(p .. "/" .. k)
	end,
}

local ReplicatedStorage = attrObj({
	Shared = node("src/shared"),
	WaitForChild = function(_, name)
		return Remotes
	end,
})

local RenderStepped = Signal()
local Heartbeat = Signal()
local services = {
	Players = {
		LocalPlayer = LocalPlayer,
		GetPlayers = function()
			return {}
		end,
		PlayerAdded = Signal(),
		RespawnTime = 3,
	},
	ReplicatedStorage = ReplicatedStorage,
	RunService = {
		RenderStepped = RenderStepped,
		Heartbeat = Heartbeat,
		BindToRenderStep = function() end,
	},
	TweenService = {
		Create = function()
			return { Play = function() end, Completed = Signal() }
		end,
	},
	UserInputService = { TouchEnabled = false, KeyboardEnabled = true, InputBegan = Signal() },
	ContextActionService = { BindAction = function() end, SetTitle = function() end, SetPosition = function() end },
	CollectionService = {
		GetTagged = function()
			return {}
		end,
		AddTag = function(_, i, t)
			i:AddTag(t)
		end,
		GetInstanceAddedSignal = function()
			return Signal()
		end,
	},
	PathfindingService = {
		CreatePath = function()
			return {}
		end,
	},
	Lighting = game:GetService("Lighting"),
	SoundService = game:GetService("SoundService"),
	Debris = { AddItem = function() end },
}
local fakeGame = {
	GetService = function(_, name)
		return services[name] or error("no mock service " .. name)
	end,
}

local function fileFor(path)
	for _, suffix in { ".luau", ".server.luau", ".client.luau" } do
		local f = repo .. "/" .. path .. suffix
		if fs.isFile(f) then
			return f
		end
	end
	error("no file for " .. path)
end

local env
local function req(n)
	local path = rawget(n, "__path")
	path = path:gsub("^ReplicatedStorage/Shared", "src/shared")
	if loaded[path] then
		return loaded[path]
	end
	local src = fs.readFile(fileFor(path))
	for _, ev in { "Activated", "MouseEnter", "MouseLeave", "HealthChanged", "Died", "Triggered" } do
		src = src:gsub("([%w_]+)%." .. ev .. ":Connect%(", '__sig(%1, "' .. ev .. '"):Connect(')
	end
	local e = table.clone(env)
	e.script = node(path)
	local result = luau.load(src, { debugName = path, environment = e })()
	loaded[path] = result
	return result
end

local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new()
	return setmetatable({}, RandomShim)
end
function RandomShim:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + math.random() * (b - a)
end
function RandomShim:NextInteger(a, b)
	return math.random(a, b)
end

env = {
	__sig = function()
		return Signal()
	end,
	game = fakeGame,
	workspace = workspace,
	require = req,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence,
	TweenInfo = {
		new = function()
			return {}
		end,
	},
	Random = RandomShim,
	task = {
		spawn = function() end,
		delay = function() end,
		defer = function() end,
		wait = function() end,
	},
	os = os,
	math = math,
	table = table,
	string = string,
	print = print,
	warn = print,
	pairs = pairs,
	ipairs = ipairs,
	type = type,
	typeof = typeof,
	tostring = tostring,
	tonumber = tonumber,
	error = error,
	pcall = pcall,
	select = select,
	setmetatable = setmetatable,
}

-- HUD
local HUD = req(node("src/client/Controllers/HUDController"))
HUD.Init()
local gui = playerGui:FindFirstChild("RiftfallHUD")
print("HUD built:", gui ~= nil, "descendants:", #gui:GetDescendants())
-- Exercise handlers.
Remotes.Toast.OnClientEvent:Fire("Picked up Battery", "good")
Remotes.InventoryChanged.OnClientEvent:Fire({
	{ Id = "Bandage", Count = 2 },
	false,
	{ Id = "RiftShard", Count = 1 },
	false,
})
Remotes.ShowNote.OnClientEvent:Fire("Journal")
Remotes.RunComplete.OnClientEvent:Fire({ Time = 600, Deaths = 2, NotesRead = 3, NotesTotal = 4, FoundShard = true })
attrs.Battery = 40
attrs.FlashlightOn = true
RenderStepped:Fire(1 / 60)
print("slot1:", gui.Inventory.Slot1.ItemName.Text, gui.Inventory.Slot1.Count.Text)
print("note:", gui.NoteReader.Visible, "end:", gui.EndScreen.Visible)
print(gui.EndScreen:GetChildren()[3].Text)

-- Other client controllers
req(node("src/client/Controllers/MovementController")).Init()
req(node("src/client/Controllers/FlashlightController")).Init()
req(node("src/client/Controllers/AtmosphereController")).Init()
print("client controllers ok")

-- Stalker model
local Stalker = req(node("src/server/Services/StalkerService"))
Stalker.SpawnPatrol()
local hollow = workspace:FindFirstChild("Hollow")
print("hollow:", hollow ~= nil, hollow and #hollow:GetChildren(), hollow and hollow:GetAttribute("State"))
Stalker.StartHunt(4)
print("hunt state:", workspace.Hollow:GetAttribute("State"))
-- Inventory rules (server)
local fakePlayer = attrObj({ Name = "Tester" })
fakePlayer.Parent = services.Players
local Inventory = req(node("src/server/Services/InventoryService"))
assert(Inventory.Add(fakePlayer, "Bandage", 3), "add 3 bandages")
assert(Inventory.Add(fakePlayer, "Bandage", 1), "4th bandage opens slot 2")
assert(Inventory.Add(fakePlayer, "Battery", 3), "batteries slot 3")
assert(Inventory.Add(fakePlayer, "RiftShard", 1), "shard slot 4")
assert(not Inventory.Add(fakePlayer, "Battery", 1), "battery stack full and no free slot")
assert(Inventory.Add(fakePlayer, "Bandage", 2), "fills bandage stack 2")
assert(not Inventory.Add(fakePlayer, "Bandage", 1), "bandages now full")
assert(Inventory.Count(fakePlayer, "Bandage") == 6, "6 bandages")
assert(not Inventory.Add(fakePlayer, "Nope", 1), "unknown item rejected")
print("inventory rules ok")
-- Character outfit (server)
local Character = req(node("src/server/Services/CharacterService"))
local char = roblox.Instance.new("Model")
char.Name = "TesterCharacter"
for _, name in { "Head", "UpperTorso", "LowerTorso", "LeftFoot", "RightFoot", "LeftHand", "RightHand", "LeftUpperArm" } do
	local part = roblox.Instance.new("Part")
	part.Name = name
	part.Size = roblox.Vector3.new(2, 1.6, 1)
	part.Parent = char
end
roblox.Instance.new("Humanoid").Parent = char
char.Parent = workspace
fakePlayer.UserId = 12345
fakePlayer.DisplayName = "Tester"
Character.Dress(fakePlayer, char)
local gearCount = 0
for _, d in char:GetDescendants() do
	if d:IsA("BasePart") and string.sub(d.Name, 1, 5) == "Gear_" then
		gearCount += 1
	end
end
print("outfit:", char:GetAttribute("ExpeditionRole"), "gear parts:", gearCount, char.Humanoid.DisplayName)

-- Flashlight visuals
local FV = req(node("src/shared/FlashlightVisuals"))
local torch = roblox.Instance.new("Part")
local rig = FV.Create(torch, 0.5)
FV.SetEnabled(rig, true)
print("flashlight rig:", rig.Light.Enabled, rig.Beam.Enabled, rig.Beam.Attachment1 ~= nil)
print("ALL OK")
