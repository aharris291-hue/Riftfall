-- Smoke test: load real modules under Lune with mocked Roblox services, to
-- catch bad property names/types in instance construction code.
local roblox = require("@lune/roblox")
-- Lune has no PivotTo; count calls so the sighting walk can be checked.
local pivotCalls = 0
roblox.implementMethod("Model", "PivotTo", function()
	pivotCalls += 1
end)
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
	ServerStorage = game:GetService("ServerStorage"),
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
	for _, ev in { "Activated", "MouseEnter", "MouseLeave", "HealthChanged", "Died", "Triggered", "DescendantAdded" } do
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
Remotes.RunComplete.OnClientEvent:Fire({
	Time = 600,
	Deaths = 2,
	NotesRead = 3,
	NotesTotal = 4,
	EvidenceFound = 4,
	EvidenceTotal = 4,
	FoundDaniel = true,
	FoundShard = true,
})
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
local hollow = workspace:FindFirstChild("RiftStalker")
print("hollow:", hollow ~= nil, hollow and #hollow:GetChildren(), hollow and hollow:GetAttribute("State"))
Stalker.StartHunt(4)
print("hunt state:", workspace.RiftStalker:GetAttribute("State"))
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
assert(Inventory.Remove(fakePlayer, "Bandage", 2) and Inventory.Count(fakePlayer, "Bandage") == 4, "remove 2")
assert(not Inventory.Remove(fakePlayer, "BoltCutters", 1), "cannot remove what you lack")
print("inventory rules ok")
-- Chapter 1 expansion services load, and the sighting creature cleans up.
local Gate = req(node("src/server/Services/GateService"))
local Distraction = req(node("src/server/Services/DistractionService"))
assert(type(Gate.OnTalk) == "function" and type(Distraction.Throw) == "function", "new services")
Stalker.PlaySighting(roblox.Vector3.new(30, 4, 150), roblox.Vector3.new(-30, 4, 150), 1)
assert(pivotCalls > 10, "sighting walks")
assert(workspace:FindFirstChild("RiftStalkerSighting") == nil, "sighting removed")
Stalker.ReportNoise(roblox.Vector3.new(0, 0, 0), 70, 14)
print("chapter 1 expansion ok")
-- Character designs (server): dress a fake R15 rig as every design.
local Character = req(node("src/server/Services/CharacterService"))
local R15 = {
	Head = { 1.2, 1.2, 1.2 },
	UpperTorso = { 2, 1.6, 1 },
	LowerTorso = { 2, 0.4, 1 },
	LeftUpperArm = { 1, 1.2, 1 },
	RightUpperArm = { 1, 1.2, 1 },
	LeftLowerArm = { 1, 1.1, 1 },
	RightLowerArm = { 1, 1.1, 1 },
	LeftHand = { 1, 0.3, 1 },
	RightHand = { 1, 0.3, 1 },
	LeftUpperLeg = { 1, 1.2, 1 },
	RightUpperLeg = { 1, 1.2, 1 },
	LeftLowerLeg = { 1, 1.1, 1 },
	RightLowerLeg = { 1, 1.1, 1 },
	LeftFoot = { 1, 0.3, 1 },
	RightFoot = { 1, 0.3, 1 },
}
-- Bind-pose centres (feet on Y = 0, facing -Z) so gear lands where it would
-- on a real character; also used for the preview render.
local POSE = {
	Head = { 0, 5.3 },
	UpperTorso = { 0, 3.9 },
	LowerTorso = { 0, 2.9 },
	LeftUpperArm = { -1.5, 4.1 },
	RightUpperArm = { 1.5, 4.1 },
	LeftLowerArm = { -1.5, 3.0 },
	RightLowerArm = { 1.5, 3.0 },
	LeftHand = { -1.5, 2.3 },
	RightHand = { 1.5, 2.3 },
	LeftUpperLeg = { -0.5, 2.1 },
	RightUpperLeg = { 0.5, 2.1 },
	LeftLowerLeg = { -0.5, 0.9 },
	RightLowerLeg = { 0.5, 0.9 },
	LeftFoot = { -0.5, 0.15 },
	RightFoot = { 0.5, 0.15 },
}
local dressed = {}
local designIds = {}
for id in req(node("src/shared/CharacterDesigns")).Designs do
	table.insert(designIds, id)
end
table.sort(designIds)
for _, id in designIds do
	local char = roblox.Instance.new("Model")
	for name, sz in R15 do
		local part = roblox.Instance.new("Part")
		part.Name = name
		part.Size = roblox.Vector3.new(sz[1], sz[2], sz[3])
		part.CFrame = roblox.CFrame.new(POSE[name][1], POSE[name][2], 0)
		part.Parent = char
	end
	local face = roblox.Instance.new("Decal")
	face.Name = "face"
	face.Parent = char.Head
	char.Parent = workspace
	assert(Character.DressModel(char, id), "dress " .. id)
	local count = 0
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 7) == "Outfit_" then
			count += 1
		end
	end
	assert(char.Head:FindFirstChild("face") == nil, "default face removed")
	assert(char.Head:FindFirstChild("OutfitFace") ~= nil, "face drawn")
	-- Re-applying must replace, not stack.
	Character.DressModel(char, id)
	local again = 0
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 7) == "Outfit_" then
			again += 1
		end
	end
	assert(again == count, "re-dress keeps the same part count for " .. id)
	print(string.format("design %-17s parts %d", id, count))
	dressed[id] = char
end

-- Flashlight visuals
local FV = req(node("src/shared/FlashlightVisuals"))
local torch = roblox.Instance.new("Part")
local rig = FV.Create(torch, 0.5)
FV.SetEnabled(rig, true)
print("flashlight rig:", rig.Light.Enabled, rig.Beam.Enabled, rig.Beam.Attachment1 ~= nil)
-- Optional: export dressed characters + the creature for the preview render.
if process.args[2] then
	local serde = require("@lune/serde")
	local function exportModel(model)
		local parts = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				local c = d.Color
				table.insert(parts, {
					name = d.Name,
					size = { d.Size.X, d.Size.Y, d.Size.Z },
					cf = { d.CFrame:GetComponents() },
					color = { c.R, c.G, c.B },
					transparency = d.Transparency,
					material = d.Material.Name,
				})
			end
			if d.Name == "OutfitFace" then
				for _, f in d:GetChildren() do
					table.insert(parts, {
						face = true,
						x = f.Position.X.Scale,
						y = f.Position.Y.Scale,
						w = f.Size.X.Scale,
						h = f.Size.Y.Scale,
						color = { f.BackgroundColor3.R, f.BackgroundColor3.G, f.BackgroundColor3.B },
					})
				end
			end
		end
		return parts
	end
	local out = {}
	for _, id in designIds do
		out[id] = exportModel(dressed[id])
	end
	out.RiftStalker = exportModel(workspace.RiftStalker)
	fs.writeFile(process.args[2], serde.encode("json", out))
	print("exported", process.args[2])
end
print("ALL OK")
