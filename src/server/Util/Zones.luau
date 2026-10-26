--!strict
-- Zones: small helpers for "is this point inside that box?" checks and for
-- binding code to tagged instances (including ones created later, e.g. when
-- the level is rebuilt for Play Again).

local CollectionService = game:GetService("CollectionService")

local Zones = {}

-- True if a world position lies inside a part's (possibly rotated) box.
function Zones.Contains(part: BasePart, point: Vector3): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- True if the point is inside any part carrying the given tag.
function Zones.InAnyTagged(tag: string, point: Vector3): boolean
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and Zones.Contains(inst, point) then
			return true
		end
	end
	return false
end

-- Calls `callback` for every instance with `tag`, now and in the future.
function Zones.BindTag(tag: string, callback: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(callback, inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(callback)
end

-- First tagged BasePart (used for single markers such as spawn points).
function Zones.FirstTagged(tag: string): BasePart?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			return inst
		end
	end
	return nil
end

return Zones
