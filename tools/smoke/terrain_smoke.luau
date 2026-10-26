-- Smoke test: run the terrain builders in SceneryKit against a mock Terrain
-- that checks every call's argument types (Lune has no real terrain).
-- Usage: lune run tools/smoke/terrain_smoke.luau <repo>
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local repo = process.args[1]
local calls = {}
local function expect(method, args, types)
	for i, t in types do
		assert(typeof(args[i]) == t, `{method} arg {i}: expected {t}, got {typeof(args[i])}`)
	end
	calls[method] = (calls[method] or 0) + 1
end
local terrain = setmetatable({}, {
	__index = function(_, method)
		local signatures = {
			FillBlock = { "CFrame", "Vector3", "EnumItem" },
			FillBall = { "Vector3", "number", "EnumItem" },
			ReplaceMaterial = { "Region3", "number", "EnumItem", "EnumItem" },
			SetMaterialColor = { "EnumItem", "Color3" },
		}
		local types = assert(signatures[method], "unexpected Terrain method " .. tostring(method))
		return function(_, ...)
			expect(method, { ... }, types)
		end
	end,
	__newindex = function(_, key)
		error("script sets Terrain." .. tostring(key) .. " (check it is scriptable)")
	end,
})

local game = roblox.Instance.new("DataModel")
local env = {
	game = game,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Region3 = roblox.Region3,
	Enum = roblox.Enum,
	math = math,
	table = table,
	typeof = typeof,
	pairs = pairs,
}
local kit = luau.load(fs.readFile(repo .. "/src/server/Util/SceneryKit.luau"), {
	debugName = "SceneryKit",
	environment = env,
})()
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + math.random() * (b - a)
end
function RandomShim:NextInteger(a, b)
	return math.random(a, b)
end
local rng = setmetatable({}, RandomShim)
local folder = roblox.Instance.new("Folder")

kit.FillValley(terrain, rng)
kit.PaintGround(terrain, roblox.Vector3.new(0, 0, 10), roblox.Vector2.new(8, 6), roblox.Enum.Material.Mud)
kit.Terrain = terrain
kit.MudPatch(folder, roblox.Vector3.new(0, 0, 186), roblox.Vector2.new(44, 38), rng)
kit.CliffLine(folder, roblox.Vector3.new(-88, 0, -70), roblox.Vector3.new(-80, 0, 600), rng, terrain)
kit.Mountain(folder, roblox.Vector3.new(10, 0, 680), terrain)
local names = {}
for k, v in calls do
	table.insert(names, k .. "=" .. v)
end
table.sort(names)
print("terrain calls", table.concat(names, " "))
print("TERRAIN OK")
