--!strict
-- Items: the definition of every item in the demo. The server reads these
-- definitions to decide what an item does; the client only uses them for
-- names, colors, and descriptions in the UI.

export type ItemDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	MaxStack: number,
	Color: Color3,
	-- Key items cannot be dropped, so progress can never be soft-locked.
	KeyItem: boolean,
	-- Seconds the use action takes (the player is told it is in progress).
	UseTime: number,
	HealAmount: number?,
	BatteryAmount: number?,
}

local Items: { [string]: ItemDef } = {
	Bandage = {
		Id = "Bandage",
		DisplayName = "Bandage",
		Description = "Field dressing. Restores 35 health.",
		MaxStack = 3,
		Color = Color3.fromRGB(230, 225, 210),
		KeyItem = false,
		UseTime = 1.5,
		HealAmount = 35,
	},
	Battery = {
		Id = "Battery",
		DisplayName = "Battery",
		Description = "Recharges your flashlight by 50%.",
		MaxStack = 3,
		Color = Color3.fromRGB(120, 200, 255),
		KeyItem = false,
		UseTime = 0.8,
		BatteryAmount = 50,
	},
	RiftShard = {
		Id = "RiftShard",
		DisplayName = "Rift Shard",
		Description = "A warm, humming stone fragment. Evidence for the expedition.",
		MaxStack = 1,
		Color = Color3.fromRGB(190, 110, 255),
		KeyItem = true,
		UseTime = 0,
	},
}

return Items
