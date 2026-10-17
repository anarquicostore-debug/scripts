-- Steal An Egg - Auto pegar eggs do campo
-- Lista todos os eggs do campo no servidor, ordena do melhor pro pior e vai sempre no topo:
-- anda até o egg (desviando das paredes) -> AskFieldEggCarry -> foge do guarda em linha reta
-- pra fora da área -> volta pra base -> servidor entrega.
--
-- Como o jogo funciona (tirado do dump):
--  * Cada área (workspace.World.Areas.GuardAreas.<Área>) tem um guarda. Quando você pega um egg da área
--    ele acorda e te persegue até você sair dos Bounds da área; quanto mais longe ele está, mais rápido corre.
--    Se ele encosta (HitDistance) você é arremessado / morre e perde o egg.
--  * O próprio jogo calcula a fuga indo RETO na direção da base (-SeparationLine.LookVector). O script usa
--    esse cálculo (GuardEscapePrediction) pra saber a velocidade que precisa pra fugir de cada egg e, depois
--    de pegar, foge reto nessa direção com a WalkSpeed aumentada o suficiente (mesmo acima da sua).
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
-- velocidades em studs/s (não depende da sua velocidade no jogo; 16 = andar normal do Roblox)
local SPEED_IDA = 120 -- indo pro egg (o guarda está dormindo, pode ir rápido)
local SPEED_FUGA = 90 -- MÍNIMO fugindo do guarda com o egg (sobe sozinho o quanto precisar)
local SPEED_VOLTA = 90 -- depois de sair da área do guarda até a base
local MAX_SPEED = 350 -- limite: egg que precisaria de mais que isso pra fugir é ignorado
local SAFE_MARGIN = 1.5 -- foge 50% mais rápido que o mínimo calculado
local REACH = 4 -- distância (studs) pra considerar que chegou no egg
local GUARD_AVOID = 28 -- desvia de guarda acordado que estiver mais perto que isso

---------------------------------------------------------------- lista do servidor
local field, carrying, skip = {}, false, {} -- field[uid] = record

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

---------------------------------------------------------------- personagem / velocidade
local function char()
	local c = P.Character
	local hrp, hum = c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return c, hrp, hum end
end

-- O jogo controla a WalkSpeed (WalkSpeedGovernor). A gente sobrescreve enquanto anda e devolve no final.
local gameSpeed, ourSpeed = 16, nil
local function setSpeed(hum, speed)
	if not ourSpeed or math.abs(hum.WalkSpeed - ourSpeed) > 0.01 then gameSpeed = hum.WalkSpeed end
	ourSpeed = speed
	hum.WalkSpeed = ourSpeed
end
local function restoreSpeed(hum)
	if ourSpeed and math.abs(hum.WalkSpeed - ourSpeed) <= 0.01 then hum.WalkSpeed = gameSpeed end
	ourSpeed = nil
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

-- velocidade (studs/s, já carregando o egg) que precisa pra fugir do guarda da área desse egg
-- (mesmo cálculo da placa de velocidade do jogo). 0 = área sem guarda.
local needCache = {}
local function escapeNeed(e)
	local c = needCache[e.Uid]
	if c and c.t > os.clock() then return c.need end
	local need = 0
	local pos = e.BottomCFrame.Position
	local area = Prediction and ChasePolicy and areaAt(pos)
	if area then
		local _, root, cfg = guardOf(area)
		local bounds, dir = area:FindFirstChild("Bounds"), exitDir()
		if root and cfg and bounds and dir then
			local s, r = pcall(function()
				return Prediction.ResolvePlayerWalkSpeedRequirement({
					BaseGuardWalkSpeed = cfg.WalkSpeed,
					ExitDirection = dir,
					ExitDistance = Prediction.ResolveExitDistance(bounds.CFrame, bounds.Size, pos, dir),
					FlatRadius = cfg.FlatRadius,
					GuardStartPosition = root.Position,
					HitDistance = ChasePolicy.ResolveHitDistance(cfg.HitDistance),
					PlayerStartPosition = pos,
				}, 1)
			end)
			if s and type(r) == "number" then need = r end
		end
	end
	needCache[e.Uid] = { need = need, t = os.clock() + 2 }
	return need
end

-- velocidade de fuga pra esse egg: o necessário (com folga), nunca menos que SPEED_FUGA
local function fleeSpeed(need)
	return math.max(SPEED_FUGA, need * SAFE_MARGIN)
end

-- dá pra fugir desse egg sem passar do MAX_SPEED?
local function canEscape(e)
	return fleeSpeed(escapeNeed(e)) <= MAX_SPEED
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
		if canEscape(e) then return e end
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
	if dir.Magnitude > 1000 then return false end -- Spherecast do Roblox vai no máximo até 1024 studs
	if workspace:Spherecast(a, 1.5, dir, params) then return false end
	local steps = math.floor(dir.Magnitude / 6)
	for i = 1, steps do
		if not workspace:Raycast(a + dir * (i / (steps + 1)), Vector3.new(0, -10, 0), params) then return false end
	end
	return true
end

local function rotate(v, deg) return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v) end

-- desvio local: segue a direção desejada; se tiver obstáculo baixo pula, se for parede gira o mínimo possível.
-- side = lado que desviou da última vez (1/-1): continua contornando pelo mesmo lado, sem ficar trocando.
local ANGLES = { 20, 40, 65, 90 }
local function steer(pos, dir, params, look, side)
	local ahead = workspace:Spherecast(pos, 1.5, dir * look, params)
	if not ahead then return dir, false, side end
	if not workspace:Spherecast(pos + Vector3.new(0, 3.5, 0), 1.5, dir * look, params) then
		return dir, true, side -- obstáculo baixo: pula por cima
	end
	for _, s in ipairs({ side, -side }) do
		for _, a in ipairs(ANGLES) do
			local d = rotate(dir, a * s)
			if not workspace:Spherecast(pos, 1.5, d * look, params) and not crossesWall(pos, pos + d * look) then
				return d, false, s
			end
		end
	end
	return dir, true, side
end

-- desvia de guardas acordados que estiverem perto: só puxa pro lado, nunca faz voltar pra trás
local function avoidGuards(pos, dir)
	local push = Vector3.zero
	for _, toGuard in ipairs(awakeGuards(pos)) do
		local d = toGuard.Magnitude
		if d > 0.1 and dir:Dot(toGuard.Unit) > 0 then -- guarda na frente
			local right = Vector3.new(-dir.Z, 0, dir.X)
			local away = right:Dot(toGuard) > 0 and -right or right
			push += away * ((GUARD_AVOID - d) / GUARD_AVOID)
		end
	end
	if push.Magnitude < 0.01 then return dir end
	return (dir + push.Unit * math.min(push.Magnitude, 1)).Unit
end

-- Anda até o alvo: Pathfinding pra desviar de paredes, atalho em linha reta sempre que dá (fica reto),
-- desvio local de obstáculos, pulo em degraus, foge de guarda e recalcula se travar.
-- opts.straight = true: ignora o Pathfinding e vai reto na direção de getTarget (fuga do guarda).
-- retorna true = chegou, false = abortou/falhou
local function walkTo(getTarget, shouldAbort, speed, reach, opts)
	opts = opts or {}
	local c, hrp, hum = char()
	if not c then return false end
	hum.PlatformStand, hum.Sit = false, false
	markWall()
	controls(false)

	local params = rayParams()
	local target = getTarget()
	local timeout = (target - hrp.Position).Magnitude / math.max(speed, 8) * 3 + 15
	local start = os.clock()
	local wps, i = nil, 1
	local side, prevDir = 1, nil

	-- começa no waypoint seguinte ao mais perto de onde o personagem está AGORA
	-- (o 1º waypoint é onde ele estava quando o cálculo começou: ir nele = voltar pra trás)
	local function startIndex(list)
		local best, bestD = 1, math.huge
		for k, w in ipairs(list) do
			local d = flat(w.Position - hrp.Position).Magnitude
			if d < bestD then best, bestD = k, d end
		end
		return math.min(best + 1, #list)
	end
	local lastShortcut, lastCheck, lastPos, stuck, replans = 0, os.clock(), hrp.Position, 0, 0
	local lastAbortCheck = 0
	local result

	local planning = false
	local function plan()
		if planning then return end
		planning = true
		local ok, err = pcall(function()
			target = getTarget()
			local goal = ground(target, params)
			local new
			if opts.straight or straightClear(hrp.Position, goal + Vector3.new(0, 2.5, 0), params) then
				new = { { Position = goal } }
			else
				new = computePath(hrp.Position, goal)
					or computePath(hrp.Position, ground(goal + flat(hrp.Position - goal).Unit * 3, params))
				local far = flat(goal - hrp.Position)
				if not new and far.Magnitude > 300 then
					-- muito longe pro Pathfinding: calcula até um ponto no meio do caminho e continua de lá
					local mid = ground(hrp.Position + far.Unit * 250, params)
					new = computePath(hrp.Position, mid)
					if new then new.partial = true end
				end
				new = new or { { Position = goal } }
			end
			wps, i = new, startIndex(new)
		end)
		if not ok then
			warn("[AutoFieldEggs] erro calculando caminho:", err)
			wps, i = { { Position = getTarget() } }, 1
		end
		planning = false
	end

	local function arrived()
		local t = getTarget()
		return flat(t - hrp.Position).Magnitude < reach and math.abs(t.Y - hrp.Position.Y) < 7
	end

	plan()
	local function step()
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
		-- passa pro próximo waypoint quando chega perto OU quando já passou dele
		-- (correndo rápido ele passa do ponto; antes disso fazia o personagem voltar)
		local passR = math.max(2.5, speed * 0.08)
		while i < #wps do
			local nextSeg = flat(wps[i + 1].Position - wp.Position)
			if to.Magnitude < passR or nextSeg:Dot(flat(pos - wp.Position)) > 0 then
				i += 1
				wp = wps[i]
				to = flat(wp.Position - pos)
			else
				break
			end
		end
		if wps.partial and i == #wps and to.Magnitude < passR + 2 then
			task.spawn(plan) -- chegou no fim do trecho: calcula o próximo
		end
		if to.Magnitude < 0.1 then return end

		local look = math.clamp(speed * 0.25, 5, 35) -- quanto mais rápido, mais longe olha pra desviar
		local dir, jump = to.Unit, false
		if i < #wps or to.Magnitude > 8 then -- encostando no alvo não desvia (o próprio egg/ninho conta como obstáculo)
			dir, jump, side = steer(pos, dir, params, math.min(look, to.Magnitude + 1), side)
		end
		dir = avoidGuards(pos, dir)
		if prevDir and prevDir:Dot(dir) > 0 then
			dir = (prevDir * 0.4 + dir).Unit -- suaviza a virada (sem tremedeira)
		end
		prevDir = dir
		if (wp.Jump or jump) and hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true end

		-- chegando no destino final freia, pra não passar do ponto e ter que voltar
		local now = speed
		if i == #wps and not opts.straight and to.Magnitude < speed * 0.3 then
			now = math.max(16, speed * to.Magnitude / (speed * 0.3))
		end
		setSpeed(hum, now)
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
	end

	-- erro dentro do passo não pode travar o script nem deixar o controle desligado
	local conn = RunService.Stepped:Connect(function()
		if result ~= nil then return end
		local ok, err = pcall(step)
		if not ok then
			warn("[AutoFieldEggs] erro no movimento:", err)
			result = false
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

-- volta com o egg: 1) foge RETO pra fora da área do guarda na velocidade necessária,
-- 2) vai pra base desviando das paredes
local function goHome(plot, area, need)
	local _, hrp, hum = char()
	local dir = exitDir()
	if hrp and dir and area and area:FindFirstChild("Bounds") then
		local speed = math.min(fleeSpeed(need or 0), MAX_SPEED)
		-- já sai correndo neste frame (o guarda acorda em ~0.6s, não dá pra perder tempo preparando)
		setSpeed(hum, speed)
		hum:Move(dir, false)
		local bounds = area.Bounds
		walkTo(function()
			local _, r = char()
			return (r and r.Position or hrp.Position) + dir * 60
		end, function()
			local _, r = char()
			return not carrying or not r or not inFootprint(bounds, r.Position, 6) -- saiu da área: fase 2
		end, speed, 0, { straight = true })
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
	-- qualquer erro numa rodada só é avisado: o script continua e o controle do jogador volta
	local ok, err = pcall(function()
		if os.clock() - lastSync > 20 then resync() lastSync = os.clock() end
		local _, hrp, hum = char()
		local plot = PlotState.ResolvePlot()

		if hrp and plot and carrying then
			-- ainda com egg na mão (ex.: script reiniciado): leva pra base
			goHome(plot, areaAt(hrp.Position), math.huge) -- não sabe o egg: foge no MAX_SPEED
		elseif hrp and plot then
			local best = ranked(hum)
			if best then
				local uid = best.Uid
				local since = os.clock()
				-- aborta se o egg sumir/for pego. Troca por um melhor só se já andou 3s nesse e ainda está longe
				-- (senão fica indo e voltando entre dois eggs)
				local arrived = walkTo(function()
					local cur = field[uid]
					return (cur or best).BottomCFrame.Position
				end, function()
					local cur = field[uid]
					if not cur or not available(cur) then return true end
					local _, r, h = char()
					if not h or os.clock() - since < 3 then return false end
					if flat(cur.BottomCFrame.Position - r.Position).Magnitude < 80 then return false end
					local top = ranked(h)
					return top ~= nil and top.Uid ~= uid and better(top, cur)
				end, SPEED_IDA, REACH)

				if arrived then
					local cur = field[uid] or best
					local slotKey = uid:find("FirstAreaEgg_", 1, true) == 1 and (cur.AreaId .. ":" .. cur.NestId) or nil
					local area = areaAt(cur.BottomCFrame.Position)
					needCache[uid] = nil
					local need = escapeNeed(cur) -- com o guarda onde ele está agora
					local s, got = pcall(Carry.InvokeServer, Carry, { Uid = uid, FirstAreaSlotKey = slotKey })
					if s and got == true then
						carrying = true -- não espera o evento FieldEggCarry chegar: foge na hora
						goHome(plot, area, need)
					else
						skip[uid] = os.clock() + 15 -- recusado: vai no próximo da lista
					end
				elseif field[uid] and available(field[uid]) then
					skip[uid] = os.clock() + 15 -- não conseguiu chegar: não fica preso nele
				end
			end
		end
	end)
	if not ok then
		warn("[AutoFieldEggs] erro:", err)
		controls(true)
		local _, _, hum = char()
		if hum then restoreSpeed(hum) end
	end
	task.wait(0.2)
end
