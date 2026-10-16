-- Steal An Egg - Auto Hatch
local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local N = RS.Packages.Networking
local Snapshot, Hatch, Finish = N["RF/EggWorld/AskLiveSnapshot"], N["RF/EggWorld/AskHatch"], N["RF/EggWorld/AskFinishHatch"]
local ER = require(RS.Shared.Util.EggRecords) -- mesmo cálculo de crescimento do jogo

getgenv().AutoHatch = true
local eggs, busy = {}, {}

local function ready(e)
	local p = e.Placement
	if not p then return false end
	if p.ReadyAt then return true end
	local ok, grown = pcall(function()
		local now = workspace:GetServerTimeNow()
		local m = e.GrowthSpeedMultiplier or ER.GrowthSpeedMultiplier(e)
		return ER.IsGrown(e, now, m, ER.CurrentNightCredit(e, now, m), P)
	end)
	return ok and grown
end

-- lista inicial + atualização em tempo real (sem spam de snapshot)
for _, row in ipairs(Snapshot:InvokeServer()) do
	if row.OwnerUserId == P.UserId then eggs = row.Records end
end
N["RE/EggWorld/OwnerShifted"].OnClientEvent:Connect(function(d)
	if d.OwnerUserId == P.UserId then eggs = d.Records end
end)

while getgenv().AutoHatch do
	for uid, e in pairs(eggs) do
		if not busy[uid] and ready(e) then
			busy[uid] = true
			task.spawn(function()
				local s, ok = pcall(Hatch.InvokeServer, Hatch, uid)
				if s and ok == true then pcall(Finish.InvokeServer, Finish, uid) end
				task.wait(2)
				busy[uid] = nil
			end)
		end
	end
	task.wait(0.5)
end
