-- Steal An Egg - Auto Claim Index
-- Mesmo remote do botão "Claim All" do Index (IndexController._claimAll).
local Redeem = game:GetService("ReplicatedStorage").Packages.Networking["RF/Codex/AskRedeemAll"]

getgenv().AutoClaimIndex = true

while getgenv().AutoClaimIndex do
	local s, ok, err = pcall(Redeem.InvokeServer, Redeem)
	if s and ok then print("[AutoClaimIndex] recompensas do index resgatadas") end
	task.wait(30)
end
