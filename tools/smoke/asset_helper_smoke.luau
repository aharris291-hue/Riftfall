-- Smoke test for tools/studio/RiftfallAssetHelper.lua: simulates a free
-- model with a hidden script, clicks the "Torch" button, and checks the
-- result. Studio-only methods are stubbed with roblox.implementMethod.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local repo = process.args[1]
local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local serverStorage = game:GetService("ServerStorage")

roblox.implementMethod("Model", "GetBoundingBox", function(model)
	return roblox.CFrame.new(0, 2, 0), roblox.Vector3.new(2, 4, 2)
end)
local scales = {}
roblox.implementMethod("Model", "GetScale", function(model)
	return scales[model] or 1
end)
roblox.implementMethod("Model", "ScaleTo", function(model, s)
	scales[model] = s
end)

local selected = {}
local buttons = {}
local fakePlugin = {
	CreateToolbar = function()
		return {
			CreateButton = function(_, id, _, _, label)
				local button = { Click = {} }
				function button.Click:Connect(fn)
					buttons[label] = fn
				end
				return button
			end,
		}
	end,
}
local services = {
	ChangeHistoryService = {
		TryBeginRecording = function()
			return "rec"
		end,
		FinishRecording = function() end,
	},
	Selection = {
		Get = function()
			return selected
		end,
		Set = function(_, list)
			selected = list
		end,
	},
	ServerStorage = serverStorage,
}
local env = {
	game = {
		GetService = function(_, name)
			return assert(services[name], name)
		end,
	},
	plugin = fakePlugin,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	math = math,
	string = string,
	print = print,
	warn = function(...)
		error(table.concat({ ... }, " "))
	end,
	error = error,
	pcall = pcall,
	tostring = tostring,
}
luau.load(fs.readFile(repo .. "/tools/studio/RiftfallAssetHelper.lua"), { environment = env })()

-- A "free model" torch: a stick, a flame, and a sneaky script.
local model = roblox.Instance.new("Model")
model.Name = "Cool Torch"
local stick = roblox.Instance.new("Part")
stick.Parent = model
local flame = roblox.Instance.new("Part")
flame.CFrame = roblox.CFrame.new(0, 3, 0)
flame.Parent = model
roblox.Instance.new("Script").Parent = flame
model.Parent = workspace
selected = { model }

assert(buttons.Torch, "Torch button missing")
buttons.Torch()

local slot = serverStorage.RiftfallAssets.Torch
assert(model.Parent == slot, "model not moved to the Torch slot")
assert(model.Name == "Torch_1", model.Name)
assert(#model:GetDescendants() > 0 and not model:FindFirstChildWhichIsA("Script", true), "script not removed")
assert(stick.Anchored and flame.Anchored, "parts not anchored")
assert(flame:FindFirstChildWhichIsA("PointLight"), "torch light not added to the top part")
assert(math.abs(scales[model] - 6.5 / 4) < 1e-6, "not scaled to fit")
print("buttons", #(function()
	local t = {}
	for k in buttons do
		table.insert(t, k)
	end
	return t
end)())
print("ASSET HELPER OK")
