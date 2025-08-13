--!strict
--!optimize 2

--[[
	"SimpleParallelMovement EN-US.luau"
	
	GitHub: https://github.com/Ping764/SimpleParallelRobloxMovement
	
	// Remember that this code needs to be inside an Actor,
	// to perform all calculations in parallel.
]]

local RunService: RunService = game:GetService('RunService')

local Actor: Actor = script.Parent

local AddedModels: {Model} = {}
local ModelsTarget: {[Model]: CFrame} = {}

local BulkMovementModels: {Model} = {}
local BulkMovementCFrames: {CFrame} = {}

local RayParameters: RaycastParams = RaycastParams.new()
RayParameters.RespectCanCollide = true
RayParameters.FilterType = Enum.RaycastFilterType.Exclude
RayParameters.FilterDescendantsInstances = {}

--[[
	// The "DelayedCFrame" is the trick to make the movement of the models smoother,
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
	local RaycastResult: RaycastResult = workspace:Raycast(RayCFrame.Position, Vector3.new(0, -100, 0), RayParameters)
	if not RaycastResult then return RayCFrame end
	return CFrame.new(RaycastResult.Position) * RayCFrame.Rotation
end

Actor:BindToMessageParallel('UpdateModelCFrame', function(Model: Model, ModelCFrame: CFrame): ()
	if not table.find(AddedModels, Model) then return end
	ModelsTarget[Model] = ModelCFrame
end)

Actor:BindToMessageParallel('AddModel', function(Model: Model): ()
	if table.find(AddedModels, Model) then return end
	table.insert(AddedModels, Model)
end)

Actor:BindToMessageParallel('RemoveModel', function(Model: Model): ()
	local Index: number? = table.find(AddedModels, Model)
	if not Index then return end
	table.remove(AddedModels, Index)
end)

RunService.Stepped:Connect(function(DeltaTime: number): ()
	for Model, TargetCFrame in ModelsTarget do
		local DelayedCFrame: CFrame = DelayedCFrame(Model:GetPivot(), TargetCFrame, DeltaTime)
		local GroundCFrame: CFrame = RaycastToBottom(DelayedCFrame)
		table.insert(BulkMovementModels, Model)
		table.insert(BulkMovementCFrames, GroundCFrame)
	end
end)

task.synchronize()

--[[
	// This part of the code is for moving the models.
	// It needs to be inside "task.synchronize" to exit parallelism,
	// since moving the models has to be done sequentially.
]]

RunService.Stepped:Connect(function(): ()
	workspace:BulkMoveTo(
		BulkMovementModels,
		BulkMovementCFrames,
		Enum.BulkMoveMode.FireCFrameChanged --[[ Use CFrameChanged to discard unnecessary updates in the properties. ]] 
	)
	BulkMovementModels = {}
	BulkMovementCFrames = {}
end)

task.desynchronize()
