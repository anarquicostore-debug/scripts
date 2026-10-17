-- Steal An Egg - Auto pegar eggs do campo
-- Lista todos os eggs do campo no servidor, ordena do melhor pro pior e vai sempre no topo:
-- anda até o egg (desviando das paredes) -> AskFieldEggCarry -> foge do guarda em linha reta
-- pra fora da área -> volta pra base -> servidor entrega.
--
-- Como o jogo funciona (tirado do dump):
--  * Cada área (workspace.World.Areas.GuardAreas.<Área>) tem um guarda. Quando você pega um egg da área
--    ele acorda e te persegue até você sair dos Bounds da área; quanto mais longe ele está, mais rápido corre.
--    Se ele encosta (HitDistance) você é arremessado / morre e perde o egg.
--  * O próprio jogo calcula a fuga indo RETO na direção da base (-SeparationLine.LookVector), então o
--    script foge reto nessa direção e só pega eggs que dá pra fugir com a sua velocidade (GuardEscapePrediction).
--  * A parede WallStartCollision não pode ser atravessada (o servidor recusa a entrega: "Delivery failed").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local RS = game:GetService("ReplicatedStorage")
local P = Players.LocalPlayer
local N = RS.Packages.Networking
local Snapshot, Carry = N["RF/EggWorld/AskFieldEggSnapshot"], N["RF/EggWorld/AskFieldEggCarry"]
local PlotState = require(RS.Client.PlotState)
local Assets = require(RS.Data.Assets).Directory

local function try(f, ...)
	local ok, r = pcall(f, ...)
	return ok and r or nil
end
local Prediction = try(require, RS.Shared.Modules.GuardAreas.GuardEscapePrediction)
local ChasePolicy = try(require, RS.Shared.Modules.GuardAreas.GuardChasePolicy)
local AreasData = try(function() return require(RS.Data.Areas).Directory end)
local GuardsData = try(function() return require(RS.Data.Guards).Directory end)

getgenv().AutoFieldEggs = true
local WANT = {} -- AssetCategory que quer pegar (vazio = qualquer um)
local SPEED_IDA = 2.5 -- velocidade indo pro egg = sua WalkSpeed x isso
local SPEED_VOLTA = 1.5 -- velocidade voltando com o egg (se voltar o "Delivery failed", abaixe pra 1)
local SAFE_MARGIN = 1.2 -- só pega egg se der pra fugir do guarda com 20% de folga
local REACH = 4 -- distância (studs) pra considerar que chegou no egg
local GUARD_AVOID = 28 -- desvia de guarda acordado que estiver mais perto que isso

---------------------------------------------------------------- lista do servidor
local field, carrying, carryMult, skip = {}, false, 0.67, {} -- field[uid] = record

local function adopt(list)
	for _, e in ipairs(list) do field[e.Uid] = e end
end
N["RE/EggWorld/FieldEggShifted"].OnClientEvent:Connect(function(e) field[e.Uid] = e end)
N["RE/EggWorld/FieldEggGone"].OnClientEvent:Connect(function(uid) field[uid] = nil end)
N["RE/EggWorld/FieldEggBatchShifted"].OnClientEvent:Connect(function(b)
	for _, uid in ipairs(b.RemovedUids) do field[uid] = nil end
	adopt(b.UpdatedRecords)
end)
N["RE/EggWorld/FieldEggCarry"].OnClientEvent:Connect(function(s)
	carrying = s.IsCarrying
	if s.IsCarrying and type(s.SpeedMultiplier) == "number" and s.SpeedMultiplier > 0 then
		carryMult = math.min(s.SpeedMultiplier, 1) -- slow de carregar egg
	end
end)

local function resync()
	local ok, snap = pcall(Snapshot.InvokeServer, Snapshot)
	if ok and snap then
		field = {}
		adopt(snap.Records)
	end
end

---------------------------------------------------------------- personagem / velocidade
local function char()
	local c = P.Character
	local hrp, hum = c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return c, hrp, hum end
end

-- O jogo controla a WalkSpeed (WalkSpeedGovernor). A gente multiplica por cima e devolve no final.
local gameSpeed, ourSpeed = 16, nil
local function setSpeed(hum, mult)
	if not ourSpeed or math.abs(hum.WalkSpeed - ourSpeed) > 0.01 then gameSpeed = hum.WalkSpeed end
	ourSpeed = gameSpeed * mult
	hum.WalkSpeed = ourSpeed
end
local function restoreSpeed(hum)
	if ourSpeed and math.abs(hum.WalkSpeed - ourSpeed) <= 0.01 then hum.WalkSpeed = gameSpeed end
	ourSpeed = nil
end
local function baseSpeed(hum) -- WalkSpeed real do jogo (sem o nosso multiplicador)
	if ourSpeed and math.abs(hum.WalkSpeed - ourSpeed) <= 0.01 then return gameSpeed end
	return hum.WalkSpeed
end

-- desliga o controle do teclado/analógico enquanto o script anda (senão ele briga com o hum:Move)
local Controls = try(function() return require(P.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls() end)
local function controls(on)
	if Controls then pcall(on and Controls.Enable or Controls.Disable, Controls) end
end

---------------------------------------------------------------- mapa: linha, parede, áreas, guardas
local function areasFolder()
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Areas")
end

local function sepLine()
	local a = areasFolder()
	local s = a and a:FindFirstChild("SeparationLine")
	return s and s:IsA("BasePart") and s or nil
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- direção "reta pra casa" (a mesma que o jogo usa pra calcular a fuga do guarda)
local function exitDir()
	local s = sepLine()
	return s and flat(-s.CFrame.LookVector).Unit or nil
end

local function wallPart()
	local a = areasFolder()
	local w = a and a:FindFirstChild("WallStartCollision")
	return w and w:IsA("BasePart") and w or nil
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

local function inFootprint(part, pos, margin)
	local p = part.CFrame:PointToObjectSpace(pos)
	return math.abs(p.X) <= part.Size.X * 0.5 + (margin or 0) and math.abs(p.Z) <= part.Size.Z * 0.5 + (margin or 0)
end

local function guardAreas()
	local a = areasFolder()
	local g = a and a:FindFirstChild("GuardAreas")
	return g and g:GetChildren() or {}
end

-- área de guarda que contém a posição (nil = área sem guarda)
local function areaAt(pos)
	for _, area in ipairs(guardAreas()) do
		local b = area:FindFirstChild("Bounds")
		if b and b:IsA("BasePart") and inFootprint(b, pos) then return area end
	end
end

local function guardOf(area)
	local g = area:FindFirstChild("Guard")
	local root = g and g:FindFirstChild("HumanoidRootPart")
	local data = AreasData and AreasData[area.Name]
	local cfg = data and GuardsData and GuardsData[data.GuardId]
	return g, root, cfg
end

-- guardas acordados (perseguindo / voltando) perto da posição
local function awakeGuards(pos)
	local list = {}
	for _, area in ipairs(guardAreas()) do
		local g, root = guardOf(area)
		if g and root and g:GetAttribute("Sleeping") ~= true then
			local st = g:GetAttribute("GuardState")
			if st == nil or st == "Chasing" or st == "Waking" or st == "EggRetrieval" then
				local d = flat(root.Position - pos)
				if d.Magnitude < GUARD_AVOID then table.insert(list, d) end
			end
		end
	end
	return list
end

-- dá pra pegar esse egg e fugir do guarda da área com a sua velocidade carregando? (cálculo do próprio jogo)
local escapeCache = {}
local function canEscape(e, hum)
	local c = escapeCache[e.Uid]
	if c and c.t > os.clock() then return c.ok end
	local ok = true
	local pos = e.BottomCFrame.Position
	local area = Prediction and ChasePolicy and areaAt(pos)
	if area then
		local _, root, cfg = guardOf(area)
		local bounds, dir = area:FindFirstChild("Bounds"), exitDir()
		if root and cfg and bounds and dir then
			local speed = baseSpeed(hum) * SPEED_VOLTA * carryMult / SAFE_MARGIN
			local s, r = pcall(function()
				return Prediction.Resolve({
					BaseGuardWalkSpeed = cfg.WalkSpeed,
					ExitDirection = dir,
					ExitDistance = Prediction.ResolveExitDistance(bounds.CFrame, bounds.Size, pos, dir),
					FlatRadius = cfg.FlatRadius,
					GuardStartPosition = root.Position,
					HitDistance = ChasePolicy.ResolveHitDistance(cfg.HitDistance),
					PlayerWalkSpeed = speed,
					PlayerStartPosition = pos,
				})
			end)
			if s and r then ok = r.Outcome ~= "Caught" end
		end
	end
	escapeCache[e.Uid] = { ok = ok, t = os.clock() + 2 }
	return ok
end

---------------------------------------------------------------- escolha do egg
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

local function ranked(hum)
	local list = {}
	for _, e in pairs(field) do
		if available(e) then table.insert(list, e) end
	end
	table.sort(list, better)
	-- o melhor que dá pra fugir do guarda
	for _, e in ipairs(list) do
		if canEscape(e, hum) then return e end
	end
end

---------------------------------------------------------------- movimento
local function rayParams()
	local ignore = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
	end
	local client = workspace:FindFirstChild("AreaEggSlotsClient") -- eggs desenhados no cliente
	if client then table.insert(ignore, client) end
	for _, area in ipairs(guardAreas()) do -- guardas (desvio deles é separado)
		local g = area:FindFirstChild("Guard")
		if g then table.insert(ignore, g) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

local function ground(pos, params)
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or pos
end

local AGENT = {
	AgentRadius = 2.5,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = false,
	WaypointSpacing = 6,
	Costs = { Water = 20, AutoEggWall = math.huge },
}

local function computePath(from, to)
	local path = PathfindingService:CreatePath(AGENT)
	local ok = pcall(path.ComputeAsync, path, from, to)
	if ok and path.Status == Enum.PathStatus.Success then
		local wps = {}
		for _, w in ipairs(path:GetWaypoints()) do
			table.insert(wps, { Position = w.Position, Jump = w.Action == Enum.PathWaypointAction.Jump })
		end
		return wps
	end
end

-- linha reta de a até b livre? (sem parede, sem degrau grande, com chão no caminho)
local function straightClear(a, b, params)
	if crossesWall(a, b) or math.abs(b.Y - a.Y) > 4 then return false end
	local dir = b - a
	if dir.Magnitude < 0.5 then return true end
	if workspace:Spherecast(a, 1.5, dir, params) then return false end
	local steps = math.floor(dir.Magnitude / 6)
	for i = 1, steps do
		if not workspace:Raycast(a + dir * (i / (steps + 1)), Vector3.new(0, -10, 0), params) then return false end
	end
	return true
end

local function rotate(v, deg) return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v) end

-- desvio local: segue a direção desejada; se tiver obstáculo baixo pula, se for parede gira o mínimo possível
local ANGLES = { 0, 20, -20, 40, -40, 65, -65, 90, -90 }
local function steer(pos, dir, params, look)
	local ahead = workspace:Spherecast(pos, 1.5, dir * look, params)
	if not ahead then return dir, false end
	if not workspace:Spherecast(pos + Vector3.new(0, 3.5, 0), 1.5, dir * look, params) then
		return dir, true -- obstáculo baixo: pula por cima
	end
	for i = 2, #ANGLES do
		local d = rotate(dir, ANGLES[i])
		if not workspace:Spherecast(pos, 1.5, d * look, params) and not crossesWall(pos, pos + d * look) then
			return d, false
		end
	end
	return dir, true
end

-- foge dos guardas acordados que estiverem perto
local function avoidGuards(pos, dir)
	for _, toGuard in ipairs(awakeGuards(pos)) do
		local d = toGuard.Magnitude
		if d > 0.1 and dir:Dot(toGuard.Unit) > -0.2 then
			dir = dir - toGuard.Unit * ((GUARD_AVOID - d) / GUARD_AVOID) * 1.5
		end
	end
	return dir.Magnitude > 0.05 and flat(dir).Unit or dir
end

-- Anda até o alvo: Pathfinding pra desviar de paredes, atalho em linha reta sempre que dá (fica reto),
-- desvio local de obstáculos, pulo em degraus, foge de guarda e recalcula se travar.
-- opts.straight = true: ignora o Pathfinding e vai reto na direção de getTarget (fuga do guarda).
-- retorna true = chegou, false = abortou/falhou
local function walkTo(getTarget, shouldAbort, speedMult, reach, opts)
	opts = opts or {}
	local c, hrp, hum = char()
	if not c then return false end
	hum.PlatformStand, hum.Sit = false, false
	markWall()
	controls(false)

	local params = rayParams()
	local target = getTarget()
	local timeout = (target - hrp.Position).Magnitude / math.max(baseSpeed(hum) * speedMult, 8) * 3 + 15
	local start = os.clock()
	local wps, i = nil, 1
	local lastShortcut, lastCheck, lastPos, stuck, replans = 0, os.clock(), hrp.Position, 0, 0
	local lastAbortCheck, aborted = 0, false
	local result

	local function plan()
		target = getTarget()
		local goal = ground(target, params)
		if opts.straight or straightClear(hrp.Position, goal + Vector3.new(0, 2.5, 0), params) then
			wps = { { Position = goal } }
		else
			wps = computePath(hrp.Position, goal)
				or computePath(hrp.Position, ground(goal + flat(hrp.Position - goal).Unit * 3, params))
				or { { Position = goal } }
		end
		i = 1
	end

	local function arrived()
		local t = getTarget()
		return flat(t - hrp.Position).Magnitude < reach and math.abs(t.Y - hrp.Position.Y) < 7
	end

	plan()
	local conn
	conn = RunService.Stepped:Connect(function()
		if result ~= nil then return end
		if not hrp.Parent or hum.Health <= 0 or not getgenv().AutoFieldEggs or os.clock() - start > timeout then
			result = false
			return
		end
		if os.clock() - lastAbortCheck > 0.25 then
			lastAbortCheck = os.clock()
			if shouldAbort() then result = false return end
		end
		if arrived() then result = true return end

		local pos = hrp.Position
		if opts.straight then
			wps[1].Position = getTarget()
		elseif (getTarget() - target).Magnitude > 6 then
			task.spawn(plan) -- alvo mexeu
		end

		-- atalho: vai pro waypoint mais longe visível em linha reta
		if not opts.straight and os.clock() - lastShortcut > 0.2 then
			lastShortcut = os.clock()
			for j = math.min(#wps, i + 10), i + 1, -1 do
				local jump = false
				for k = i, j do if wps[k].Jump then jump = true break end end
				if not jump and straightClear(pos, wps[j].Position + Vector3.new(0, 2.5, 0), params) then
					i = j
					break
				end
			end
		end

		local wp = wps[i]
		local to = flat(wp.Position - pos)
		if to.Magnitude < 2.5 and i < #wps then
			i += 1
			wp = wps[i]
			to = flat(wp.Position - pos)
		end
		if to.Magnitude < 0.1 then return end

		local speed = baseSpeed(hum) * speedMult
		local look = math.clamp(speed * 0.35, 5, 14)
		local dir, jump = to.Unit, false
		if i < #wps or to.Magnitude > 8 then -- encostando no alvo não desvia (o próprio egg/ninho conta como obstáculo)
			dir, jump = steer(pos, dir, params, math.min(look, to.Magnitude + 1))
		end
		dir = avoidGuards(pos, dir)
		if (wp.Jump or jump) and hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true end

		setSpeed(hum, speedMult)
		hum:Move(dir, false)

		-- travou? pula; travou várias vezes? recalcula o caminho
		if os.clock() - lastCheck > 0.5 then
			if flat(hrp.Position - lastPos).Magnitude < 1.5 then
				stuck += 1
				hum.Jump = true
				if stuck >= 3 then
					stuck, replans = 0, replans + 1
					if replans > 6 then result = false return end
					params = rayParams()
					task.spawn(plan)
				end
			else
				stuck = 0
			end
			lastCheck, lastPos = os.clock(), hrp.Position
		end
	end)

	while result == nil do RunService.Heartbeat:Wait() end
	conn:Disconnect()
	if hum.Parent then
		hum:Move(Vector3.zero, false)
		restoreSpeed(hum)
	end
	controls(true)
	return result
end

local function waitFor(cond, t)
	local limit = os.clock() + t
	while not cond() and os.clock() < limit do task.wait(0.1) end
	return cond()
end

-- volta com o egg: 1) foge RETO pra fora da área do guarda, 2) vai pra base desviando das paredes
local function goHome(plot, area)
	local _, hrp = char()
	local dir = exitDir()
	if hrp and dir and area and area:FindFirstChild("Bounds") then
		local bounds = area.Bounds
		walkTo(function()
			local _, r = char()
			return (r and r.Position or hrp.Position) + dir * 60
		end, function()
			local _, r = char()
			return not carrying or not r or not inFootprint(bounds, r.Position, 6) -- saiu da área: fase 2
		end, SPEED_VOLTA, 0, { straight = true })
	end
	if carrying then
		walkTo(function() return plot.CenterPoint.Position end, function() return not carrying end, SPEED_VOLTA, 5)
	end
	waitFor(function() return not carrying end, 5)
end

---------------------------------------------------------------- loop
resync()
local lastSync = os.clock()

while getgenv().AutoFieldEggs do
	if os.clock() - lastSync > 20 then resync() lastSync = os.clock() end
	local _, hrp, hum = char()
	local plot = PlotState.ResolvePlot()

	if hrp and plot and carrying then
		-- ainda com egg na mão (ex.: script reiniciado): leva pra base
		goHome(plot, areaAt(hrp.Position))
	elseif hrp and plot then
		local best = ranked(hum)
		if best then
			local uid = best.Uid
			-- aborta se o egg sumir/for pego ou se aparecer um melhor no servidor
			local arrived = walkTo(function()
				local cur = field[uid]
				return (cur or best).BottomCFrame.Position
			end, function()
				local cur = field[uid]
				if not cur or not available(cur) then return true end
				local _, _, h = char()
				local top = h and ranked(h)
				return top ~= nil and top.Uid ~= uid and better(top, cur)
			end, SPEED_IDA, REACH)

			if arrived then
				local cur = field[uid] or best
				local slotKey = uid:find("FirstAreaEgg_", 1, true) == 1 and (cur.AreaId .. ":" .. cur.NestId) or nil
				local area = areaAt(cur.BottomCFrame.Position)
				local s, got = pcall(Carry.InvokeServer, Carry, { Uid = uid, FirstAreaSlotKey = slotKey })
				if s and got == true and waitFor(function() return carrying end, 2) then
					goHome(plot, area)
				else
					skip[uid] = os.clock() + 15 -- recusado: vai no próximo da lista
				end
			elseif field[uid] and available(field[uid]) then
				skip[uid] = os.clock() + 15 -- não conseguiu chegar: não fica preso nele
			end
		end
	end
	task.wait(0.2)
end
