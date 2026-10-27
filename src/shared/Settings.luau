--!strict
-- Settings: the player's options (volumes, subtitle size, brightness,
-- graphics). Shared so the client menu and the server's save code agree on
-- the defaults and on what a valid value is. The server only ever stores
-- values that pass Sanitize, so a modified client cannot save junk.

export type Values = {
	MusicVolume: number, -- 0 to 1
	EffectsVolume: number, -- 0 to 1 (thunder, creature, footsteps, rumble)
	AmbienceVolume: number, -- 0 to 1 (rain, jungle)
	SubtitleSize: string, -- "Small" | "Normal" | "Large"
	Brightness: string, -- "Normal" | "Bright" | "Brightest"
	Graphics: string, -- "Best" | "Fast"
}

local Settings = {}

Settings.Defaults = {
	MusicVolume = 0.6,
	EffectsVolume = 0.8,
	AmbienceVolume = 0.7,
	SubtitleSize = "Normal",
	Brightness = "Normal",
	Graphics = "Best",
} :: Values

Settings.Choices = {
	SubtitleSize = { "Small", "Normal", "Large" },
	Brightness = { "Normal", "Bright", "Brightest" },
	Graphics = { "Best", "Fast" },
}

Settings.SubtitleTextSize = { Small = 15, Normal = 18, Large = 24 }
Settings.BrightnessExposure = { Normal = 0, Bright = 0.6, Brightest = 1.2 }

local VOLUME_KEYS = { MusicVolume = true, EffectsVolume = true, AmbienceVolume = true }

-- Returns a clean copy: unknown keys dropped, bad values replaced by defaults.
function Settings.Sanitize(input: any): Values
	local out = table.clone(Settings.Defaults) :: any
	if type(input) ~= "table" then
		return out
	end
	for key in VOLUME_KEYS do
		local v = input[key]
		if type(v) == "number" and v == v then -- v == v rejects NaN
			out[key] = math.clamp(math.round(v * 100) / 100, 0, 1)
		end
	end
	for key, choices in Settings.Choices do
		local v = input[key]
		if type(v) == "string" and table.find(choices, v) then
			out[key] = v
		end
	end
	return out
end

return Settings
