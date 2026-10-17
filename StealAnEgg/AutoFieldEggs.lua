-- Steal An Egg - Auto pegar eggs do campo
-- Lista todos os eggs do campo no servidor, ordena do melhor pro pior e vai sempre no topo:
-- anda rente ao chão (hover) até o egg -> AskFieldEggCarry -> volta pra base -> servidor entrega.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local P = Players.LocalPlayer
local N = RS.Packages.Networking
local Snapshot, Carry = N["RF/EggWorld/AskFieldEggSnapshot"], N["RF/EggWorld/AskFieldEggCarry"]
local PlotState = require(RS.Client.PlotState)
local Assets = require(RS.Data.Assets).Directory

getgenv().AutoFieldEggs = true
local WANT = {} -- AssetCategory que quer pegar (vazio = qualquer um)
local HOVER = 3 -- altura acima do chão (studs)
local MAX_CLIMB = 14 -- quanto pode subir pra passar por cima de um obstáculo

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

---------------------------------------------------------------- movimento
local function char()
	local c = P.Character
	local hrp, hum = c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return c, hrp, hum end
end

-- só considera peças com colisão e ignora todos os jogadores (antes subia ao bater em eggs/players)
local function rayParams()
	local ignore = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

local function blocked(pos, dir, len, params)
	return workspace:Raycast(pos, dir * len, params) ~= nil
end

-- Anda flutuando rente ao chão na WalkSpeed do personagem: segue o relevo,
-- sobe no máximo MAX_CLIMB pra passar obstáculos e contorna pelos lados se não der.
local function moveTo(getTarget, shouldAbort)
	local c, hrp, hum = char()
	if not c then return false end

	local att = Instance.new("Attachment", hrp)
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0, lv.RelativeTo = att, Enum.ActuatorRelativeTo.World
	lv.MaxForce, lv.VectorVelocity = math.huge, Vector3.zero
	lv.Parent = hrp
	local ao = Instance.new("AlignOrientation")
	ao.Attachment0, ao.Mode = att, Enum.OrientationAlignmentMode.OneAttachment
	ao.MaxTorque, ao.Responsiveness, ao.RigidityEnabled = math.huge, 50, true
	ao.CFrame = hrp.CFrame
	ao.Parent = hrp
	hum.PlatformStand = true

	local params, refreshed = rayParams(), os.clock()
	local result, start = nil, os.clock()
	local timeout = (getTarget() - hrp.Position).Magnitude / math.max(hum.WalkSpeed, 8) * 2 + 10
	local side = 1

	while result == nil do
		RunService.Heartbeat:Wait()
		if not hrp.Parent or hum.Health <= 0 or not getgenv().AutoFieldEggs or shouldAbort() then
			result = false
			break
		end
		if os.clock() - start > timeout then
			result = false
			break
		end
		if os.clock() - refreshed > 2 then params, refreshed = rayParams(), os.clock() end

		local pos, target = hrp.Position, getTarget()
		local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		local dist = flat.Magnitude
		if dist < 3 and math.abs(target.Y - pos.Y) < 5 then
			result = true
			break
		end

		local speed = hum.WalkSpeed -- mesma velocidade de andar do personagem (inclui o slow carregando)
		local dir = flat.Unit
		local groundHit = workspace:Raycast(pos, Vector3.new(0, -60, 0), params)
		local groundY = groundHit and groundHit.Position.Y or (target.Y - HOVER)
		local height = pos.Y - groundY

		local look = math.min(dist, 6)
		local move, wantHeight = dir, HOVER
		if blocked(pos, dir, look, params) then
			if height < MAX_CLIMB then
				wantHeight = height + 6 -- tenta passar por cima
				move = dir * 0.2
			else
				-- alto demais e ainda bloqueado: contorna pelo lado livre
				local right = Vector3.new(-dir.Z, 0, dir.X)
				if blocked(pos, right * side, 6, params) then side = -side end
				move = (right * side + dir * 0.3).Unit
				wantHeight = height
			end
		elseif dist < 10 then
			wantHeight = math.max(target.Y - groundY, 0) + 1 -- chegando: desce até o egg/base
		end

		local vy = math.clamp((groundY + wantHeight - pos.Y) * 5, -speed, speed)
		local horiz = move * math.min(speed, dist * 4)
		lv.VectorVelocity = Vector3.new(horiz.X, vy, horiz.Z)
		ao.CFrame = CFrame.lookAt(pos, pos + dir)
	end

	lv:Destroy()
	ao:Destroy()
	att:Destroy()
	if hum.Parent then
		hum.PlatformStand = false
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
	return result
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

	if hrp and plot and best then
		local uid = best.Uid
		local eggPos = best.BottomCFrame.Position + Vector3.new(0, 2, 0)
		-- aborta se o egg sumir/for pego ou se aparecer um melhor no servidor
		local arrived = moveTo(function() return eggPos end, function()
			local cur = field[uid]
			if not cur or not available(cur) then return true end
			local top = ranked()[1]
			return top ~= nil and top.Uid ~= uid and better(top, cur)
		end)

		if arrived then
			local slotKey = uid:find("FirstAreaEgg_", 1, true) == 1 and (best.AreaId .. ":" .. best.NestId) or nil
			local s, got = pcall(Carry.InvokeServer, Carry, { Uid = uid, FirstAreaSlotKey = slotKey })
			if s and got == true and waitFor(function() return carrying end, 2) then
				local base = plot.CenterPoint.Position + Vector3.new(0, 3, 0)
				moveTo(function() return base end, function() return not carrying end) -- derrubaram: aborta
				waitFor(function() return not carrying end, 5)
			else
				skip[uid] = os.clock() + 15 -- recusado: vai no próximo da lista
			end
		elseif field[uid] and available(field[uid]) and ranked()[1] and ranked()[1].Uid == uid then
			skip[uid] = os.clock() + 15 -- não conseguiu chegar: não fica preso nele
		end
	end
	task.wait(0.3)
end
