-- Smoke test: run LevelBuilder.Build() against Lune's Roblox instance model.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local repo = process.args[1]
local source = fs.readFile(repo .. "/src/server/Services/LevelBuilder.luau")

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")

-- Optional 3rd argument: a saved place whose ServerStorage.RiftfallAssets
-- (real models added in Studio) is copied in, to test the library swap.
if process.args[3] then
	local saved = roblox.deserializePlace(fs.readFile(process.args[3]))
	local assets = saved:GetService("ServerStorage"):FindFirstChild("RiftfallAssets")
	assert(assets, "saved place has no RiftfallAssets")
	assets.Parent = game:GetService("ServerStorage")
	-- Lune lacks GetBoundingBox: approximate it from the parts' boxes.
	roblox.implementMethod("Model", "GetBoundingBox", function(model)
		local mn, mx
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local p, h = d.CFrame.Position, d.Size / 2
				mn = if mn then mn:Min(p - h) else p - h
				mx = if mx then mx:Max(p + h) else p + h
			end
		end
		return roblox.CFrame.new((mn + mx) / 2), mx - mn
	end)
	-- Placement is not checked here.
	roblox.implementMethod("Model", "PivotTo", function() end)
	roblox.implementMethod("Model", "GetPivot", function()
		return roblox.CFrame.new()
	end)
end

local tagCounts = {}
local CollectionService = {
	AddTag = function(_, inst, tag)
		inst:AddTag(tag)
		tagCounts[tag] = (tagCounts[tag] or 0) + 1
	end,
}
local fakeGame = {
	GetService = function(_, name)
		if name == "CollectionService" then
			return CollectionService
		elseif name == "Lighting" then
			return lighting
		elseif name == "ReplicatedStorage" then
			return { Shared = { Config = "Config" } }
		end
		return game:GetService(name)
	end,
}

local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	math.randomseed(seed or 0)
	return setmetatable({}, RandomShim)
end
function RandomShim:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + math.random() * (b - a)
end
function RandomShim:NextInteger(a, b)
	return math.random(a, b)
end

local configChunk = luau.load(fs.readFile(repo .. "/src/shared/Config.luau"), {
	debugName = "Config",
	environment = { Color3 = roblox.Color3, Enum = roblox.Enum, Vector3 = roblox.Vector3 },
})
local Config = configChunk()

local env
local modules = {}
local function loadModule(path)
	if not modules[path] then
		local chunk = luau.load(fs.readFile(repo .. path), { debugName = path, environment = env })
		modules[path] = chunk()
	end
	return modules[path]
end
env = {
	require = function(target)
		if target == "SceneryKit" then
			return loadModule("/src/server/Util/SceneryKit.luau")
		end
		assert(target == "Config", "unexpected require")
		return Config
	end,
	game = fakeGame,
	workspace = workspace,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim2 = roblox.UDim2,
	NumberSequence = roblox.NumberSequence,
	Random = (roblox :: any).Random or RandomShim,
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
	error = error,
	pcall = pcall,
	select = select,
	setmetatable = setmetatable,
	script = { Parent = { Parent = { Util = { SceneryKit = "SceneryKit" } } } },
}

local chunk = luau.load(source, { debugName = "LevelBuilder", environment = env })
local LevelBuilder = chunk()
LevelBuilder.SetupLighting()
local level = LevelBuilder.Build()

local parts, lights, prompts = 0, 0, 0
for _, d in level:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lights += 1
	elseif d.ClassName == "ProximityPrompt" then
		prompts += 1
	end
end
print("parts", parts, "lights", lights, "prompts", prompts)
local names = {}
for tag, n in tagCounts do
	table.insert(names, tag .. "=" .. n)
end
table.sort(names)
print("tags", table.concat(names, " "))
local fromLibrary = {}
for _, d in level:GetDescendants() do
	local slot = d:IsA("Model") and d.Name:match("^(%a+)_%d+$")
	if slot then
		fromLibrary[slot] = (fromLibrary[slot] or 0) + 1
		assert(not d:FindFirstChildWhichIsA("LuaSourceContainer", true), "script left in " .. d.Name)
	end
end
for slot, n in fromLibrary do
	print("library", slot, n)
end

-- Rebuild must replace, not duplicate.
LevelBuilder.Build()
local count = 0
for _, c in workspace:GetChildren() do
	if c.Name == "RiftfallLevel" then
		count += 1
	end
end
print("levels after rebuild", count)
LevelBuilder.SpawnPickup("Battery", "Battery", roblox.Vector3.new(0, 1, 0), roblox.Color3.new(1, 1, 1))
print("dropped folder", workspace.RiftfallLevel:FindFirstChild("Dropped") ~= nil)

if process.args[2] then
	fs.writeFile(process.args[2], roblox.serializePlace(game, true))
	print("wrote", process.args[2])
end
