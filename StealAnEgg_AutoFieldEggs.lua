-- Steal An Egg - Auto pegar eggs do campo (pathfinding)
-- Anda (sem fly/teleporte) até o melhor egg do mapa -> AskFieldEggCarry -> anda até a base -> servidor entrega o egg.
-- Usa PathfindingService + Humanoid:MoveTo, então o personagem se move como um jogador normal
-- (respeita paredes, cercas, WalkSpeedGovernor e o anti-TP do servidor).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local RS = game:GetService("ReplicatedStorage")
local P = Players.LocalPlayer
local N = RS.Packages.Networking
local Snapshot, Carry = N["RF/EggWorld/AskFieldEggSnapshot"], N["RF/EggWorld/AskFieldEggCarry"]
local PlotState = require(RS.Client.PlotState)
local Assets = require(RS.Data.Assets).Directory

getgenv().AutoFieldEggs = true
local WANT = {} -- AssetCategory que quer pegar (vazio = qualquer um)

local AGENT = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = true,
	WaypointSpacing = 6,
	Costs = { Water = 50 }, -- evita nadar sem bloquear o caminho de vez
}
local PICKUP_REACH = 5 -- o prompt do jogo ativa em 8 studs; fica bem dentro disso
local BASE_REACH = 4
-- estados em que o Humanoid está caído/ragdoll (guarda bateu): espera em vez de tentar andar
local HOLD = {
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
}

local carrying, gone, skip = false, {}, {}
pcall(function() carrying = require(RS.Client.EggState).ReadCarryState().IsCarrying end)
N["RE/EggWorld/FieldEggCarry"].OnClientEvent:Connect(function(s) carrying = s.IsCarrying end)
N["RE/EggWorld/FieldEggGone"].OnClientEvent:Connect(function(uid) gone[uid] = true end)

local function char()
	local c = P.Character
	local hrp, hum = c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return c, hrp, hum end
end

local function arrived(pos, goal, reach)
	local flat = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z).Magnitude
	return flat <= reach and math.abs(goal.Y - pos.Y) <= 8
end

local function computePath(from, to)
	local path = PathfindingService:CreatePath(AGENT)
	local ok = pcall(path.ComputeAsync, path, from, to)
	if ok and path.Status == Enum.PathStatus.Success then return path end
end

-- o ponto exato do egg (ninho/cerca) pode estar fora da navmesh: tenta o ponto e depois um anel ao redor
local function findPath(from, goal)
	local path = computePath(from, goal)
	if path then return path end
	for i = 0, 7 do
		local a = i * math.pi / 4
		path = computePath(from, goal + Vector3.new(math.cos(a) * 5, 0, math.sin(a) * 5))
		if path then return path end
	end
end

-- segue os waypoints de um path. Retorna "arrived", "repath" (travou/bloqueou) ou "abort"
local function follow(path, goalFn, reach, shouldAbort)
	local blocked = false
	local conn = path.Blocked:Connect(function() blocked = true end)

	local function run()
		local wps = path:GetWaypoints()
		for i = 2, #wps do
			local wp = wps[i]
			local _, hrp, hum = char()
			if not hrp then return "abort" end
			hum:MoveTo(wp.Position)
			local t0, nextMove = os.clock(), os.clock() + 1
			local lastPos, lastT, stuck = hrp.Position, os.clock(), 0
			while true do
				RunService.Heartbeat:Wait()
				if not hrp.Parent or hum.Health <= 0 or not getgenv().AutoFieldEggs or shouldAbort() then
					return "abort"
				end
				local pos = hrp.Position
				if arrived(pos, goalFn(), reach) then return "arrived" end
				if blocked then return "repath" end

				if HOLD[hum:GetState()] then -- ragdoll/queda: não conta como travado
					t0, lastT, lastPos = os.clock(), os.clock(), pos
					continue
				end

				local flat = Vector3.new(wp.Position.X - pos.X, 0, wp.Position.Z - pos.Z).Magnitude
				if wp.Action == Enum.PathWaypointAction.Jump and flat < 5 then hum.Jump = true end
				if flat < 3.5 and math.abs(wp.Position.Y - pos.Y) < 6 then break end

				if os.clock() >= nextMove then -- MoveTo expira em 8s, então renova
					hum:MoveTo(wp.Position)
					nextMove = os.clock() + 1
				end
				if os.clock() - lastT > 1 then -- detector de travamento
					if (pos - lastPos).Magnitude < 1.5 then
						stuck += 1
						hum.Jump = true
						if stuck >= 3 then return "repath" end
					else
						stuck = 0
					end
					lastPos, lastT = pos, os.clock()
				end
				if os.clock() - t0 > 10 then return "repath" end
			end
		end
		local _, hrp = char()
		return hrp and arrived(hrp.Position, goalFn(), reach) and "arrived" or "repath"
	end

	local result = run()
	conn:Disconnect()
	return result
end

-- anda até goalFn() (recalcula o caminho se travar/bloquear). true = chegou
local function walkTo(goalFn, reach, shouldAbort)
	local deadline, fails = os.clock() + 120, 0
	while fails < 4 do
		local _, hrp = char()
		if not hrp or not getgenv().AutoFieldEggs or shouldAbort() or os.clock() > deadline then return false end
		if arrived(hrp.Position, goalFn(), reach) then return true end

		local path = findPath(hrp.Position, goalFn())
		local res = path and follow(path, goalFn, reach, shouldAbort) or "repath"
		if res == "arrived" then return true end
		if res == "abort" then return false end
		fails += 1
		task.wait(0.5)
	end
	return false
end

local function stop()
	local _, hrp, hum = char()
	if hrp then hum:MoveTo(hrp.Position) end
end

local function wanted(e)
	if gone[e.Uid] or (skip[e.Uid] or 0) > os.clock() or (e.State ~= "Slot" and e.State ~= "Dropped") then return false end
	local owner = e.Uid:match("^FirstAreaEgg_(-?%d+)_") -- egg da área inicial é só do dono
	if owner and tonumber(owner) ~= P.UserId then return false end
	return #WANT == 0 or table.find(WANT, e.AssetCategory) ~= nil
end

-- "melhor" = mais dinheiro/s; empate -> raridade, mutações, tamanho
local function score(e)
	local cfg = Assets[e.AssetCategory]
	local earn = cfg and cfg.EarningRate or 0
	local rank = cfg and cfg.Rarity and cfg.Rarity.Rank or 0
	return earn, rank, #(e.Mutations or {}), e.AssetScale or 0
end

local function better(a, b)
	local a1, a2, a3, a4 = score(a)
	local b1, b2, b3, b4 = score(b)
	if a1 ~= b1 then return a1 > b1 end
	if a2 ~= b2 then return a2 > b2 end
	if a3 ~= b3 then return a3 > b3 end
	return a4 > b4
end

local function waitFor(cond, t)
	local limit = os.clock() + t
	while not cond() and os.clock() < limit do task.wait(0.1) end
	return cond()
end

-- leva o egg que já está nas mãos até a base. Se derrubarem no caminho (guarda/tapa), aborta
local function deliver(plot)
	local base = plot.CenterPoint.Position
	walkTo(function() return base end, BASE_REACH, function() return not carrying end)
	waitFor(function() return not carrying end, 5)
end

while getgenv().AutoFieldEggs do
	local _, hrp = char()
	local plot = PlotState.ResolvePlot()
	if hrp and plot then
		if carrying then
			deliver(plot) -- já está com um egg (script iniciado carregando ou entrega que falhou)
		else
			local ok, snap = pcall(Snapshot.InvokeServer, Snapshot)
			if ok and snap then
				-- melhor egg do mapa
				local best
				for _, e in ipairs(snap.Records) do
					if wanted(e) and (not best or better(e, best)) then best = e end
				end

				if best then
					local eggPos = best.BottomCFrame.Position
					if walkTo(function() return eggPos end, PICKUP_REACH, function() return gone[best.Uid] end) then
						stop()
						local slotKey = best.Uid:find("FirstAreaEgg_", 1, true) == 1 and (best.AreaId .. ":" .. best.NestId) or nil
						local s, got = pcall(Carry.InvokeServer, Carry, { Uid = best.Uid, FirstAreaSlotKey = slotKey })
						if s and got == true and waitFor(function() return carrying end, 2) then
							deliver(plot)
						else
							skip[best.Uid] = os.clock() + 15 -- recusado: tenta outro egg e volta nesse depois
						end
					else
						skip[best.Uid] = os.clock() + 30 -- sem caminho/travou: não fica preso nesse egg
					end
				end
			end
		end
	end
	task.wait(0.5)
end
