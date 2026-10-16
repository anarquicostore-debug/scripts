--[[
	Steal An Egg - Auto abrir (hatch) eggs via remote

	Fluxo real do jogo (Shared/Eggs/PlacedEggRenderer.lua -> Client/EggState.lua):
	  1. RF/EggWorld/AskHatch:InvokeServer(uid)        -> ok, erro, resultado ("MechaUpgraded" ou nil)
	  2. RF/EggWorld/AskFinishHatch:InvokeServer(uid)  -> ok, erro, uidDoPetRecebido
	Lista de eggs do jogador: RF/EggWorld/AskLiveSnapshot:InvokeServer()
	  -> { { OwnerUserId = number, Records = { [uid] = record } }, ... }
	Atualizações em tempo real: RE/EggWorld/OwnerShifted (OwnerUserId, Records)

	Os remotes ficam como filhos de ReplicatedStorage.Packages.Networking
	com o nome "RF/<namespace>/<nome>" / "RE/<namespace>/<nome>".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
	LoopDelay = 1, -- intervalo entre varreduras (s)
	DelayBetweenEggs = 0.15, -- pausa entre um egg e outro (s)
	RetryCooldown = 3, -- tempo antes de tentar de novo um egg que falhou (s)
	ResnapshotEvery = 15, -- força um AskLiveSnapshot a cada N segundos
}

getgenv().AutoHatchEggs = true

local Networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")

local function remote(kind, name)
	local fullName = ("%s/EggWorld/%s"):format(kind, name)
	return Networking:WaitForChild(fullName, 15) or error("remote não encontrado: " .. fullName)
end

local AskLiveSnapshot = remote("RF", "AskLiveSnapshot")
local AskHatch = remote("RF", "AskHatch")
local AskFinishHatch = remote("RF", "AskFinishHatch")
local OwnerShifted = remote("RE", "OwnerShifted")

-- Mesmo cálculo de crescimento que o jogo usa (EggState.IsReadyToHatch).
-- Se o require falhar no executor, cai no fallback e deixa o servidor validar.
local EggRecords
do
	local ok, mod = pcall(require, ReplicatedStorage.Shared.Util.EggRecords)
	if ok then
		EggRecords = mod
	end
end

local myEggs = {} -- [uid] = record
local busy = {} -- [uid] = true enquanto hatch em andamento
local cooldown = {} -- [uid] = os.clock() liberado

local function isReady(record)
	local placement = record.Placement
	if placement == nil then
		return false -- egg não está plantado
	end
	if placement.ReadyAt ~= nil then
		return true
	end
	if EggRecords then
		local ok, grown = pcall(function()
			local now = Workspace:GetServerTimeNow()
			local mult = record.GrowthSpeedMultiplier or EggRecords.GrowthSpeedMultiplier(record)
			local night = EggRecords.CurrentNightCredit(record, now, mult)
			return EggRecords.IsGrown(record, now, mult, night, LocalPlayer)
		end)
		if ok then
			return grown
		end
	end
	return true -- sem como calcular: tenta e o servidor recusa se não estiver pronto
end

local function adoptRecords(records)
	if typeof(records) == "table" then
		myEggs = records
	end
end

local function refreshSnapshot()
	local ok, rows = pcall(AskLiveSnapshot.InvokeServer, AskLiveSnapshot)
	if not ok or typeof(rows) ~= "table" then
		return
	end
	for _, row in ipairs(rows) do
		if row.OwnerUserId == LocalPlayer.UserId then
			adoptRecords(row.Records)
			return
		end
	end
	myEggs = {}
end

OwnerShifted.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and payload.OwnerUserId == LocalPlayer.UserId then
		adoptRecords(payload.Records)
	end
end)

local function hatch(uid)
	busy[uid] = true

	local okCall, ok, err, result = pcall(AskHatch.InvokeServer, AskHatch, uid)
	if not okCall or ok ~= true then
		cooldown[uid] = os.clock() + CONFIG.RetryCooldown
		busy[uid] = nil
		warn(("[AutoHatch] AskHatch falhou %s: %s"):format(uid, tostring(okCall and err or ok)))
		return
	end

	-- O jogo sempre fecha o hatch com AskFinishHatch (inclusive no caso "MechaUpgraded")
	local okFinish, finished, finishErr, petUid = pcall(AskFinishHatch.InvokeServer, AskFinishHatch, uid)
	if okFinish and finished == true then
		print(("[AutoHatch] egg %s aberto -> %s%s"):format(
			uid,
			tostring(petUid),
			result == "MechaUpgraded" and " (MechaUpgraded)" or ""
		))
		myEggs[uid] = nil
	else
		cooldown[uid] = os.clock() + CONFIG.RetryCooldown
		warn(("[AutoHatch] AskFinishHatch falhou %s: %s"):format(uid, tostring(okFinish and finishErr or finished)))
	end

	busy[uid] = nil
end

task.spawn(function()
	refreshSnapshot()
	local lastSnapshot = os.clock()

	while getgenv().AutoHatchEggs do
		if os.clock() - lastSnapshot >= CONFIG.ResnapshotEvery then
			refreshSnapshot()
			lastSnapshot = os.clock()
		end

		local now = os.clock()
		for uid, record in pairs(myEggs) do
			if not getgenv().AutoHatchEggs then
				break
			end
			if not busy[uid] and now >= (cooldown[uid] or 0) and isReady(record) then
				hatch(uid)
				task.wait(CONFIG.DelayBetweenEggs)
			end
		end

		task.wait(CONFIG.LoopDelay)
	end
end)
