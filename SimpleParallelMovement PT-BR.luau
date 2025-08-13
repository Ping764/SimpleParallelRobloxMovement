--!strict
--!optimize 2

--[[
	"SimpleParallelMovement PT-BR.luau"
	
	GitHub: https://github.com/Ping764/SimpleParallelRobloxMovement
	
	// Lembrando que este código precisa ser dentro de um Actor,
	// para fazer todos calculos em paralelo.
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
	// O "DelayedCFrame" é o truque para o movimento dos modelos serem mais suaves,
	// caso ao contrario o movimento vai ficar picotando.
	//
	// Se você preferir um movimento mais "springy", você pode utilizar o ```:SmoothDamp``` do TweenService ao inves de Lerp.
]]
local function DelayedCFrame(CurrentCFrame: CFrame, GoalCFrame: CFrame, DeltaTime: number): CFrame
	return CurrentCFrame:Lerp(GoalCFrame, math.clamp(1 - math.pow(.5, DeltaTime), 0, 1))
end

--[[
	// Sua logica de raycast aqui, fiz essa daqui apenas de exemplo.
	// Talvez a sua precise ser no servidor, porém de preferencia faça no client.
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
	// Essa parte do código é para mover os modelos.
	// Ela precisa ser dentro do "task.synchronize" para sair de parelalelismo,
	// já que para mover os modelos ela precisa ser em sequencia.
]]

RunService.Stepped:Connect(function(): ()
	workspace:BulkMoveTo(
		BulkMovementModels,
		BulkMovementCFrames,
		Enum.BulkMoveMode.FireCFrameChanged --[[ Utilize apenas CFrameChanged para não atualizar mudanças desnecessarias. ]] 
	)
	BulkMovementModels = {}
	BulkMovementCFrames = {}
end)

task.desynchronize()
