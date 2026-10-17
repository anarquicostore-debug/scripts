-- Steal An Egg - Auto pegar eggs do campo (fly)
-- Voa até o egg mais perto -> AskFieldEggCarry -> voa até a base -> servidor entrega o egg.
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

local carrying, gone, skip = false, {}, {}
N["RE/EggWorld/FieldEggCarry"].OnClientEvent:Connect(function(s) carrying = s.IsCarrying end)
N["RE/EggWorld/FieldEggGone"].OnClientEvent:Connect(function(uid) gone[uid] = true end)

local function char()
	local c = P.Character
	local hrp, hum = c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return c, hrp, hum end
end

-- Fly com constraints (LinearVelocity + AlignOrientation): física estável, sem tremer e sem cair
local function flyTo(getTarget, shouldAbort)
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

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { c }

	local result, start = nil, os.clock()
	local timeout = (getTarget() - hrp.Position).Magnitude / 10 + 15
	while result == nil do
		local dt = RunService.Heartbeat:Wait()
		if not hrp.Parent or hum.Health <= 0 or not getgenv().AutoFieldEggs or shouldAbort() then
			result = false
			break
		end
		local pos, target = hrp.Position, getTarget()
		local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		local dist = flat.Magnitude
		if dist < 3 and math.abs(target.Y - pos.Y) < 4 then
			result = true
			break
		end
		if os.clock() - start > timeout then
			result = false
			break
		end

		-- velocidade = a do próprio personagem (já inclui o slow de carregar egg)
		local speed = math.max(hum.WalkSpeed, 16)
		local dir = dist > 0 and flat.Unit or Vector3.zero

		-- desvio inteligente: obstáculo à frente -> sobe; caminho livre -> desce rente ao alvo
		local ahead = workspace:Raycast(pos, dir * math.min(dist, speed * 0.6 + 4), params)
		local ground = workspace:Raycast(pos, Vector3.new(0, -12, 0), params)
		local vy
		if ahead then
			vy = speed -- parede na frente: sobe
		elseif dist > 12 then
			-- em cruzeiro: mantém ~5 studs acima do chão
			local h = ground and (pos.Y - ground.Position.Y) or 5
			vy = math.clamp((5 - h) * 4, -speed, speed)
		else
			vy = math.clamp((target.Y - pos.Y) * 4, -speed, speed) -- chegando: desce até o alvo
		end

		local horiz = ahead and dir * speed * 0.3 or dir * math.min(speed, dist / dt)
		lv.VectorVelocity = Vector3.new(horiz.X, vy, horiz.Z)
		if dist > 1 then ao.CFrame = CFrame.lookAt(pos, pos + dir) end
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

while getgenv().AutoFieldEggs do
	local _, hrp = char()
	local plot = PlotState.ResolvePlot()
	local ok, snap = pcall(Snapshot.InvokeServer, Snapshot)
	if hrp and plot and ok and snap then
		-- melhor egg do mapa
		local best
		for _, e in ipairs(snap.Records) do
			if wanted(e) and (not best or better(e, best)) then best = e end
		end

		if best then
			local eggPos = best.BottomCFrame.Position + Vector3.new(0, 2, 0)
			if flyTo(function() return eggPos end, function() return gone[best.Uid] end) then
				local slotKey = best.Uid:find("FirstAreaEgg_", 1, true) == 1 and (best.AreaId .. ":" .. best.NestId) or nil
				local s, got = pcall(Carry.InvokeServer, Carry, { Uid = best.Uid, FirstAreaSlotKey = slotKey })
				if s and got == true and waitFor(function() return carrying end, 2) then
					local base = plot.CenterPoint.Position + Vector3.new(0, 3, 0)
					-- se derrubarem o egg no caminho (guarda/tapa), aborta e procura de novo
					flyTo(function() return base end, function() return not carrying end)
					waitFor(function() return not carrying end, 5)
				else
					skip[best.Uid] = os.clock() + 15 -- recusado: tenta outro egg e volta nesse depois
				end
			end
		end
	end
	task.wait(0.5)
end
