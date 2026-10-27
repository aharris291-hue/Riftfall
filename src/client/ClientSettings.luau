--!strict
-- ClientSettings: this player's current options. Controllers read values
-- with Get and react to changes with OnChanged. Changes are sent to the
-- server (which validates and saves them); the server sends saved settings
-- back when the player joins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientSettings = {}

local values: Settings.Values = table.clone(Settings.Defaults)
local listeners: { (string, any) -> () } = {}

local function notify(key: string)
	for _, listener in listeners do
		task.spawn(listener, key, (values :: any)[key])
	end
end

function ClientSettings.Get(key: string): any
	return (values :: any)[key]
end

-- Calls `listener(key, value)` whenever a setting changes.
function ClientSettings.OnChanged(listener: (string, any) -> ())
	table.insert(listeners, listener)
end

-- Changes a setting locally and asks the server to save it.
function ClientSettings.Set(key: string, value: any)
	local candidate = table.clone(values) :: any
	candidate[key] = value
	local clean = Settings.Sanitize(candidate) :: any
	if clean[key] == (values :: any)[key] then
		return
	end
	values = clean
	notify(key)
	Remotes.SaveSettings:FireServer(values)
end

function ClientSettings.Init()
	Remotes.SettingsLoaded.OnClientEvent:Connect(function(saved)
		values = Settings.Sanitize(saved)
		for key in values :: any do
			notify(key)
		end
	end)
end

return ClientSettings
