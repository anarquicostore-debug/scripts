-- Remove no cliente todas as remotes de trade (TradeService/* e TradePlaza*)
local RS, T = game:GetService("ReplicatedStorage"), "TradeService/"
local function kill(r)
	if typeof(r) == "Instance" and (r:IsA("BaseRemoteEvent") or r:IsA("RemoteFunction")) then pcall(r.Destroy, r) end
end
local function check(r) if r.Name:find("^Trade") then kill(r) end end
local ok, Net = pcall(function() return require(RS.Packages.Net) end)
for method, names in pairs({
	RemoteEvent = "CreateInvite DeclineInvite InviteResult Accept Ready CancelTrade TradeCompleted SendChatMessage HistoryUpdated",
	RemoteFunction = "Invite AcceptInvite SearchUser AddBrainrot RemoveBrainrot AddItem RemoveItem GetTradeHistory",
}) do
	for name in names:gmatch("%S+") do
		task.spawn(function() kill(ok and select(2, pcall(Net[method], Net, T .. name))) end)
	end
end
for _, r in ipairs(RS:GetDescendants()) do check(r) end
for _, r in ipairs(getnilinstances and getnilinstances() or {}) do check(r) end
RS.DescendantAdded:Connect(check)
