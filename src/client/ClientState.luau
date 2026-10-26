--!strict
-- ClientState: small shared table so client controllers can read each
-- other's local values (for example, the HUD shows the stamina that the
-- MovementController simulates). Nothing here is trusted by the server.

local ClientState = {
	Stamina = 100,
	Crouching = false,
	-- 0 = the Rift Stalker is far away, 1 = it is right next to you.
	Danger = 0,
	-- True while a full-screen panel (note, end screen) is open.
	ModalOpen = false,
}

return ClientState
