-- Steal An Egg - Auto pegar eggs do campo
-- Fluxo do AreaEggsController: chega perto do egg (prompt de 8 studs) -> AskFieldEggCarry
-- -> leva até a base -> servidor dá o egg (FieldEggCarry volta IsCarrying = false).
local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local N = RS.Packages.Networking
local Snapshot, Carry = N["RF/EggWorld/AskFieldEggSnapshot"], N["RF/EggWorld/AskFieldEggCarry"]
local PlotState = require(RS.Client.PlotState)

getgenv().AutoFieldEggs = true
local WANT = {} -- ex: { "DragonEgg", "MonsterEgg" } (vazio = pega qualquer um)
local carrying = false

N["RE/EggWorld/FieldEggCarry"].OnClientEvent:Connect(function(s) carrying = s.IsCarrying end)

local function wanted(e)
	if e.State ~= "Slot" and e.State ~= "Dropped" then return false end
	local owner = e.Uid:match("^FirstAreaEgg_(-?%d+)_") -- egg da área inicial é só do dono
	if owner and tonumber(owner) ~= P.UserId then return false end
	return #WANT == 0 or table.find(WANT, e.AssetCategory) ~= nil
end

local function waitFor(cond, t)
	local limit = os.clock() + t
	while not cond() and os.clock() < limit do task.wait(0.1) end
	return cond()
end

while getgenv().AutoFieldEggs do
	local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
	local plot = PlotState.ResolvePlot()
	local ok, snap = pcall(Snapshot.InvokeServer, Snapshot)
	if hrp and plot and ok and snap then
		for _, e in ipairs(snap.Records) do
			if not getgenv().AutoFieldEggs or not hrp.Parent then break end
			if wanted(e) then
				hrp.CFrame = e.BottomCFrame + Vector3.new(0, 3, 0)
				task.wait(0.25)
				local slotKey = e.Uid:find("FirstAreaEgg_", 1, true) == 1 and (e.AreaId .. ":" .. e.NestId) or nil
				local s, got = pcall(Carry.InvokeServer, Carry, { Uid = e.Uid, FirstAreaSlotKey = slotKey })
				if s and got == true and waitFor(function() return carrying end, 2) then
					hrp.CFrame = plot.CenterPoint.CFrame + Vector3.new(0, 4, 0)
					waitFor(function() return not carrying end, 5)
				end
			end
		end
	end
	task.wait(1)
end
