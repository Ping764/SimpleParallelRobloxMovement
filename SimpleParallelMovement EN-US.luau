
--!strict
--!optimize 2

--[[
	"SimpleParallelMovement EN-US.luau"
	
	GitHub: https://github.com/Ping764/SimpleParallelRobloxMovement
	
	// Remember that this code needs to be inside an Actor,
	// to perform all calculations in parallel.
]]

local RunService: RunService = game:GetService('RunService')

local Actor: Actor = script.Parent :: Actor

local AddedBaseParts: {BasePart} = {}
local BasePartsTarget: {[BasePart]: CFrame} = {}

local BulkMovementTarget: {BasePart} = {}
local BulkMovementCFrames: {CFrame} = {}

local RayParameters: RaycastParams = RaycastParams.new()
RayParameters.RespectCanCollide = true
RayParameters.FilterType = Enum.RaycastFilterType.Exclude
RayParameters.FilterDescendantsInstances = {}

--[[
	// The "DelayedCFrame" is the trick to make the movement of the BaseParts smoother,
	// otherwise the movement will look choppy.
	//
	// If you prefer a more "springy" movement, you can use ```:SmoothDamp``` from TweenService instead of Lerp.
]]
local function DelayedCFrame(CurrentCFrame: CFrame, GoalCFrame: CFrame, DeltaTime: number): CFrame
	return CurrentCFrame:Lerp(GoalCFrame, math.clamp(1 - math.pow(.5, DeltaTime), 0, 1))
end

--[[
	// Your raycast logic here.
  // I made this one just as an example.
	// Maybe yours will need to run on the server, but preferably do it on the client.
]]
local function RaycastToBottom(RayCFrame: CFrame): CFrame
	local RaycastResult: RaycastResult? = workspace:Raycast(RayCFrame.Position, Vector3.new(0, -100, 0), RayParameters)
	if not RaycastResult then return RayCFrame end
	return CFrame.new(RaycastResult.Position) * RayCFrame.Rotation
end

Actor:BindToMessageParallel('UpdateBasePartCFrame', function(BasePart: BasePart, BasePartCFrame: CFrame): ()
	if not table.find(AddedBaseParts, BasePart) then return end
	BasePartsTarget[BasePart] = BasePartCFrame
end)

Actor:BindToMessageParallel('AddBasePart', function(BasePart: BasePart): ()
	if table.find(AddedBaseParts, BasePart) then return end
	table.insert(AddedBaseParts, BasePart)
end)

Actor:BindToMessageParallel('RemoveBasePart', function(BasePart: BasePart): ()
	local Index: number? = table.find(AddedBaseParts, BasePart)
	if not Index then return end
	table.remove(AddedBaseParts, Index)
	BasePartsTarget[BasePart] = nil
end)

RunService.Stepped:Connect(function(_, DeltaTime: number): ()
	for BasePart, TargetCFrame in BasePartsTarget do
		local DelayedCFrame: CFrame = DelayedCFrame(BasePart.CFrame, TargetCFrame, DeltaTime)
		local GroundCFrame: CFrame = RaycastToBottom(DelayedCFrame)
		table.insert(BulkMovementTarget, BasePart)
		table.insert(BulkMovementCFrames, GroundCFrame)
	end
end)

task.synchronize()

--[[
	// This part of the code is for moving the BaseParts.
	// It needs to be inside "task.synchronize" to exit parallelism,
	// since moving the BaseParts has to be done sequentially.
]]
RunService.Stepped:Connect(function(): ()
	workspace:BulkMoveTo(
		BulkMovementTarget,
		BulkMovementCFrames,
		Enum.BulkMoveMode.FireCFrameChanged --[[ Use CFrameChanged to discard unnecessary updates in the properties. ]] 
	)
	BulkMovementTarget = {}
	BulkMovementCFrames = {}
end)

task.desynchronize()
