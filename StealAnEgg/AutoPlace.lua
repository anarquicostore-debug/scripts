-- Steal An Egg - Auto Place Eggs
-- Mesmo fluxo do EggPlacementController: equipa o egg (AskWearTool) e planta (AskPlaceEgg)
-- com LocalCFrame = CenterPoint:ToObjectSpace(ponto em cima do PetArea).
local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local N = RS.Packages.Networking
local Snapshot, Wear, Place = N["RF/EggWorld/AskLiveSnapshot"], N["RF/EggWorld/AskWearTool"], N["RF/EggWorld/AskPlaceEgg"]
local PlotState = require(RS.Client.PlotState)

getgenv().AutoPlace = true
local SPACING = 5 -- distância mínima entre eggs (studs)
local eggs = {}

for _, row in ipairs(Snapshot:InvokeServer()) do
	if row.OwnerUserId == P.UserId then eggs = row.Records end
end
N["RE/EggWorld/OwnerShifted"].OnClientEvent:Connect(function(d)
	if d.OwnerUserId == P.UserId then eggs = d.Records end
end)

local function localPos(placement)
	local cf = placement.LocalCFrame
	return typeof(cf) == "CFrame" and cf.Position or Vector3.new(cf[1], cf[2], cf[3])
end

-- acha um ponto livre do PetArea, varrendo em grade
local function freeSpot(plot, taken)
	local area, center = plot.PetArea, plot.CenterPoint.CFrame
	local half = area.Size / 2
	for x = -half.X + SPACING / 2, half.X - SPACING / 2, SPACING do
		for z = -half.Z + SPACING / 2, half.Z - SPACING / 2, SPACING do
			local rel = center:ToObjectSpace(CFrame.new((area.CFrame * CFrame.new(x, half.Y, z)).Position))
			local ok = true
			for _, pos in ipairs(taken) do
				if (pos - rel.Position).Magnitude < SPACING then ok = false break end
			end
			if ok then return rel end
		end
	end
end

while getgenv().AutoPlace do
	local plot = PlotState.ResolvePlot()
	if plot then
		local taken, toPlace = {}, {}
		for uid, e in pairs(eggs) do
			if e.Placement then table.insert(taken, localPos(e.Placement)) else table.insert(toPlace, uid) end
		end
		for _, uid in ipairs(toPlace) do
			local spot = freeSpot(plot, taken)
			if not spot then break end -- base cheia
			pcall(Wear.InvokeServer, Wear, uid)
			local s, ok = pcall(Place.InvokeServer, Place, { Uid = uid, LocalCFrame = spot })
			if s and ok == true then table.insert(taken, spot.Position) end
			task.wait(0.3)
		end
	end
	task.wait(1)
end
