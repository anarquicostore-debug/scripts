-- Steal An Egg - Auto Hatch (usando os módulos do próprio jogo)
-- Abre pelo mesmo caminho do ProximityPrompt (animação + MechaUpgrade tratados pelo jogo).
-- Se o egg não estiver renderizado, cai pro EggState (AskHatch -> AskFinishHatch).
local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local EggState = require(RS.Client.EggState)
local Renderer = require(RS.Shared.Eggs.PlacedEggRenderer)

getgenv().AutoHatch = true
local busy, readySince = {}, {}

local function open(uid)
	busy[uid] = true
	local ok, err = Renderer.ActivateLocalEgg(uid)
	if not ok and err == "Egg is not rendered" then
		local started = EggState.BeginHatch(uid)
		if started then EggState.FinishHatch(uid) end
	end
	task.wait(3)
	busy[uid], readySince[uid] = nil, nil
end

while getgenv().AutoHatch do
	local now = os.clock()
	for uid in pairs(EggState.ReadOwnerEggs(P.UserId)) do
		if busy[uid] then continue end
		if EggState.IsReadyToHatch(uid) then
			-- espera 1s pronto pra nunca cair no prompt de "pular crescimento" (Robux)
			readySince[uid] = readySince[uid] or now
			if now - readySince[uid] >= 1 then task.spawn(open, uid) end
		else
			readySince[uid] = nil
		end
	end
	task.wait(0.5)
end
