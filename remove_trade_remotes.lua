-- Remove no CLIENTE todas as remotes de trade (TradeService/* e TradePlaza*).
-- Efeito apenas local: o servidor continua com o sistema de trade ativo.
local RS = game:GetService("ReplicatedStorage")

local PATTERNS = { "^TradeService/", "^TradePlaza" } -- adicione "^BrainrotTraderService/" para o NPC trader
local NAMES = {
	RemoteEvent = {
		"TradeService/CreateInvite", "TradeService/DeclineInvite", "TradeService/InviteResult",
		"TradeService/Accept", "TradeService/Ready", "TradeService/CancelTrade",
		"TradeService/TradeCompleted", "TradeService/SendChatMessage", "TradeService/HistoryUpdated",
		"TradePlazaPreview/Confirm", "TradePlazaPreview/Stop", "TradePlazaPortalService/Teleport",
	},
	RemoteFunction = {
		"TradeService/Invite", "TradeService/AcceptInvite", "TradeService/SearchUser",
		"TradeService/AddBrainrot", "TradeService/RemoveBrainrot", "TradeService/AddItem",
		"TradeService/RemoveItem", "TradeService/GetTradeHistory",
		"TradePlazaPreview/Start", "TradePlazaPreview/Template", "TradePlazaSignService/SetText",
		"TradePlazaServerBrowserService/Join", "TradePlazaServerBrowserService/Search",
	},
}

local removed = 0
local function isRemote(inst)
	return typeof(inst) == "Instance" and (inst:IsA("BaseRemoteEvent") or inst:IsA("RemoteFunction"))
end
local function kill(inst)
	if isRemote(inst) and pcall(inst.Destroy, inst) then removed += 1 end
end
local function check(inst)
	if not isRemote(inst) then return end
	for _, pattern in ipairs(PATTERNS) do
		if inst.Name:find(pattern) then return kill(inst) end
	end
end

-- 1) Pelo próprio Net do jogo: funciona mesmo se o nome da Instance for diferente do nome lógico.
local okNet, Net = pcall(function() return require(RS:WaitForChild("Packages", 10):WaitForChild("Net", 10)) end)
if okNet and Net then
	for method, list in pairs(NAMES) do
		for _, name in ipairs(list) do
			task.spawn(function() -- em thread separada: o Net pode esperar (yield) pela remote
				local ok, remote = pcall(function() return Net[method](Net, name) end)
				if ok then kill(remote) end
			end)
		end
	end
end

-- 2) Varredura por nome (inclui instâncias fora da árvore, se o executor expuser getnilinstances).
for _, inst in ipairs(RS:GetDescendants()) do check(inst) end
if typeof(getnilinstances) == "function" then
	for _, inst in ipairs(getnilinstances()) do check(inst) end
end

-- 3) Remove também as que forem criadas/replicadas depois.
RS.DescendantAdded:Connect(function(inst) task.defer(check, inst) end)

task.delay(2, function() print(("[TradeRemotes] %d remote(s) removida(s)"):format(removed)) end)
