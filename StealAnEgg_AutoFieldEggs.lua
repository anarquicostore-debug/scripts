-- Steal An Egg - Auto pegar eggs do campo
-- Lista todos os eggs do campo no servidor, ordena do melhor pro pior e vai sempre no topo:
-- anda (andando de verdade, com Pathfinding) até o egg -> AskFieldEggCarry -> volta pra base -> servidor entrega.
--
-- Por que dava "Delivery failed": o servidor valida a volta pela SeparationLine / WallStartCollision
-- (Shared/Util/SafeZoneBarriers.Separates). O script antigo voava (PlatformStand + LinearVelocity),
-- subia por cima das paredes e corria 3x mais rápido carregando o egg, então a travessia era recusada.
-- Agora o personagem anda no chão, desvia das paredes pelo caminho calculado e volta na velocidade normal.
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
local SPEED_IDA = 1.5 -- velocidade indo pro egg = WalkSpeed x isso (1 = andar normal)
local SPEED_VOLTA = 1 -- velocidade voltando com o egg (deixe 1: mais rápido que isso o servidor recusa a entrega)
local REACH = 4 -- distância (studs) pra considerar que chegou no egg

---------------------------------------------------------------- lista do servidor
local field, carrying, skip = {}, false, {} -- field[uid] = record (todos os eggs do campo no servidor)

local function adopt(list)
	for _, e in ipairs(list) do field[e.Uid] = e end
end
N["RE/EggWorld/FieldEggShifted"].OnClientEvent:Connect(function(e) field[e.Uid] = e end)
N["RE/EggWorld/FieldEggGone"].OnClientEvent:Connect(function(uid) field[uid] = nil end)
N["RE/EggWorld/FieldEggBatchShifted"].OnClientEvent:Connect(function(b)
	for _, uid in ipairs(b.RemovedUids) do field[uid] = nil end
	adopt(b.UpdatedRecords)
end)
N["RE/EggWorld/FieldEggCarry"].OnClientEvent:Connect(function(s) carrying = s.IsCarrying end)

local function resync()
	local ok, snap = pcall(Snapshot.InvokeServer, Snapshot)
	if ok and snap then
		field = {}
		adopt(snap.Records)
	end
end

local function available(e)
	if (skip[e.Uid] or 0) > os.clock() or (e.State ~= "Slot" and e.State ~= "Dropped") then return false end
	local owner = e.Uid:match("^FirstAreaEgg_(-?%d+)_") -- egg da área inicial é só do dono
	if owner and tonumber(owner) ~= P.UserId then return false end
	return #WANT == 0 or table.find(WANT, e.AssetCategory) ~= nil
end

-- valor: dinheiro/s -> raridade -> mutações -> tamanho
local function score(e)
	local cfg = Assets[e.AssetCategory]
	return cfg and cfg.EarningRate or 0, cfg and cfg.Rarity and cfg.Rarity.Rank or 0, #(e.Mutations or {}), e.AssetScale or 0
end

local function better(a, b)
	local a1, a2, a3, a4 = score(a)
	local b1, b2, b3, b4 = score(b)
	if a1 ~= b1 then return a1 > b1 end
	if a2 ~= b2 then return a2 > b2 end
	if a3 ~= b3 then return a3 > b3 end
	return a4 > b4
end

local function ranked()
	local list = {}
	for _, e in pairs(field) do
		if available(e) then table.insert(list, e) end
	end
	table.sort(list, better)
	return list
end

---------------------------------------------------------------- paredes
-- A parede da área inicial (a mesma que o servidor usa pra validar) vira "proibida" no Pathfinding,
-- mesmo que ela não tenha colisão no cliente.
local function wallPart()
	local world = workspace:FindFirstChild("World")
	local areas = world and world:FindFirstChild("Areas")
	local wall = areas and areas:FindFirstChild("WallStartCollision")
	return wall and wall:IsA("BasePart") and wall or nil
end

local function markWall()
	local wall = wallPart()
	if wall and not wall:FindFirstChild("AutoEggWall") then
		local mod = Instance.new("PathfindingModifier")
		mod.Name, mod.Label, mod.PassThrough = "AutoEggWall", "AutoEggWall", false
		mod.Parent = wall
	end
end

-- segmento a->b atravessa a parede? (mesmo teste de caixa do SafeZoneBarriers, com folga)
local function crossesWall(a, b)
	local wall = wallPart()
	if not wall then return false end
	local half = wall.Size * 0.5 + Vector3.new(3, 3, 3)
	local o = wall.CFrame:PointToObjectSpace(a)
	local d = wall.CFrame:PointToObjectSpace(b) - o
	local tMin, tMax = 0, 1
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local oa, da, ha = o[axis], d[axis], half[axis]
		if math.abs(da) < 1e-4 then
			if math.abs(oa) > ha then return false end
		else
			local t1, t2 = (-ha - oa) / da, (ha - oa) / da
			if t1 > t2 then t1, t2 = t2, t1 end
			tMin, tMax = math.max(tMin, t1), math.min(tMax, t2)
			if tMin > tMax then return false end
		end
	end
	return true
end

---------------------------------------------------------------- movimento
local function char()
	local c = P.Character
	local hrp, hum = c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return c, hrp, hum end
end

-- só considera peças com colisão e ignora todos os jogadores
local function rayParams()
	local ignore = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
	end
	local client = workspace:FindFirstChild("AreaEggSlotsClient") -- modelos dos eggs desenhados no cliente
	if client then table.insert(ignore, client) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- joga o ponto pro chão logo abaixo dele (o Pathfinding precisa de um destino no chão)
local function ground(pos, params)
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or pos
end

local AGENT = {
	AgentRadius = 2.5,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = false,
	WaypointSpacing = 4,
	Costs = { Water = 20, AutoEggWall = math.huge },
}

local function computePath(from, to)
	local path = PathfindingService:CreatePath(AGENT)
	local ok = pcall(path.ComputeAsync, path, from, to)
	if ok and path.Status == Enum.PathStatus.Success then
		return path, path:GetWaypoints()
	end
end

-- dá pra ir em linha reta de a até b? (sem parede no meio, sem degrau, sem buraco)
local function straightClear(a, b, params)
	if crossesWall(a, b) or math.abs(b.Y - a.Y) > 3 then return false end
	local dir = b - a
	if dir.Magnitude < 0.5 then return true end
	if workspace:Spherecast(a, 1.5, dir, params) then return false end
	-- confere se tem chão no caminho (não cortar caminho por cima de buraco)
	local steps = math.floor(dir.Magnitude / 4)
	for i = 1, steps do
		local p = a + dir * (i / (steps + 1))
		if not workspace:Raycast(p, Vector3.new(0, -8, 0), params) then return false end
	end
	return true
end

-- Anda até o alvo seguindo o Pathfinding: desvia das paredes, pula degraus, corta caminho em linha reta
-- quando está livre (fica "reto"), recalcula se travar/bloquear e acompanha o alvo se ele mexer.
-- retorna true = chegou, false = abortou/falhou
local function walkTo(getTarget, shouldAbort, speedMult, reach)
	local c, hrp, hum = char()
	if not c then return false end
	hum.PlatformStand, hum.Sit = false, false
	markWall()

	local params = rayParams()
	local target = getTarget()
	local timeout = (target - hrp.Position).Magnitude / math.max(hum.WalkSpeed, 8) * 3 + 20
	local start, replans = os.clock(), 0

	local function arrived()
		local t = getTarget()
		return flat(t - hrp.Position).Magnitude < reach and math.abs(t.Y - hrp.Position.Y) < 7
	end

	while true do
		if arrived() then return true end
		if replans > 10 then return false end
		replans += 1

		target = getTarget()
		local goal = ground(target, params)
		local path, wps = computePath(hrp.Position, goal)
		if not wps then
			-- sem caminho: tenta um ponto do lado do alvo, senão vai reto (se não atravessar parede)
			local side = goal + flat(hrp.Position - goal).Unit * 3
			path, wps = computePath(hrp.Position, ground(side, params))
			if not wps then
				if crossesWall(hrp.Position, goal) then return false end
				wps = { { Position = hrp.Position, Action = Enum.PathWaypointAction.Walk },
					{ Position = goal, Action = Enum.PathWaypointAction.Walk } }
			end
		end

		local blockedAt
		local conn = path and path.Blocked:Connect(function(i) blockedAt = i end)
		local status -- "done" | "replan" | "fail"
		local i = 2
		local lastCheck, lastPos, stuck = os.clock(), hrp.Position, 0
		local lastMoveTo, lastShortcut = 0, 0

		while i <= #wps and not status do
			RunService.Heartbeat:Wait()
			if not hrp.Parent or hum.Health <= 0 or not getgenv().AutoFieldEggs or shouldAbort()
				or os.clock() - start > timeout then
				status = "fail"
				break
			end
			if arrived() then status = "done" break end
			if blockedAt and blockedAt >= i then status = "replan" break end
			if (getTarget() - target).Magnitude > 6 then status = "replan" break end -- alvo mexeu

			local pos = hrp.Position
			-- corta caminho: pula pro waypoint mais longe que dá pra ver em linha reta (5x por segundo)
			if os.clock() - lastShortcut > 0.2 then
				lastShortcut = os.clock()
				for j = math.min(#wps, i + 8), i + 1, -1 do
					local jumpBetween = false
					for k = i, j do
						if wps[k].Action == Enum.PathWaypointAction.Jump then jumpBetween = true break end
					end
					if not jumpBetween and straightClear(pos, wps[j].Position + Vector3.new(0, 2.5, 0), params) then
						i = j
						break
					end
				end
			end

			local wp = wps[i]
			local to = flat(wp.Position - pos)
			if to.Magnitude < 2 then
				i += 1
				lastMoveTo = 0
				continue
			end
			if wp.Action == Enum.PathWaypointAction.Jump and hum.FloorMaterial ~= Enum.Material.Air then
				hum.Jump = true
			end
			if os.clock() - lastMoveTo > 0.5 then
				hum:MoveTo(wp.Position)
				lastMoveTo = os.clock()
			end
			-- velocidade extra (só se speedMult > 1): empurra na horizontal mantendo o Y da física
			if speedMult > 1 and hum.FloorMaterial ~= Enum.Material.Air then
				local v = to.Unit * hum.WalkSpeed * speedMult
				hrp.AssemblyLinearVelocity = Vector3.new(v.X, hrp.AssemblyLinearVelocity.Y, v.Z)
			end

			-- travou? pula; travou várias vezes seguidas? recalcula o caminho
			if os.clock() - lastCheck > 0.6 then
				if flat(hrp.Position - lastPos).Magnitude < 1 then
					stuck += 1
					hum.Jump = true
					if stuck >= 3 then status = "replan" end
				else
					stuck = 0
				end
				lastCheck, lastPos = os.clock(), hrp.Position
			end
		end
		if conn then conn:Disconnect() end

		if status == "fail" then
			hum:MoveTo(hrp.Position)
			return false
		elseif status == "done" or arrived() then
			hum:MoveTo(hrp.Position)
			return true
		end
		params = rayParams()
	end
end

local function waitFor(cond, t)
	local limit = os.clock() + t
	while not cond() and os.clock() < limit do task.wait(0.1) end
	return cond()
end

---------------------------------------------------------------- loop
resync()
local lastSync = os.clock()

while getgenv().AutoFieldEggs do
	if os.clock() - lastSync > 20 then resync() lastSync = os.clock() end
	local _, hrp = char()
	local plot = PlotState.ResolvePlot()
	local best = ranked()[1]

	if hrp and plot and best and not carrying then
		local uid = best.Uid
		local eggPos = best.BottomCFrame.Position
		-- aborta se o egg sumir/for pego ou se aparecer um melhor no servidor
		local arrived = walkTo(function()
			local cur = field[uid]
			return cur and cur.BottomCFrame.Position or eggPos
		end, function()
			local cur = field[uid]
			if not cur or not available(cur) then return true end
			local top = ranked()[1]
			return top ~= nil and top.Uid ~= uid and better(top, cur)
		end, SPEED_IDA, REACH)

		if arrived then
			local cur = field[uid] or best
			local slotKey = uid:find("FirstAreaEgg_", 1, true) == 1 and (cur.AreaId .. ":" .. cur.NestId) or nil
			local s, got = pcall(Carry.InvokeServer, Carry, { Uid = uid, FirstAreaSlotKey = slotKey })
			if s and got == true and waitFor(function() return carrying end, 2) then
				task.wait(0.2) -- deixa o servidor aplicar o slow de carregar antes de sair andando
				local base = plot.CenterPoint.Position
				walkTo(function() return base end, function() return not carrying end, SPEED_VOLTA, 5) -- entregou/derrubaram: para
				waitFor(function() return not carrying end, 5)
			else
				skip[uid] = os.clock() + 15 -- recusado: vai no próximo da lista
			end
		elseif field[uid] and available(field[uid]) and ranked()[1] and ranked()[1].Uid == uid then
			skip[uid] = os.clock() + 15 -- não conseguiu chegar: não fica preso nele
		end
	elseif carrying and plot then
		-- ainda com egg na mão (ex.: script reiniciado): leva pra base
		walkTo(function() return plot.CenterPoint.Position end, function() return not carrying end, SPEED_VOLTA, 5)
	end
	task.wait(0.3)
end
