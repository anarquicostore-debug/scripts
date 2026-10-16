-- Steal An Egg - Auto Hatch
local P = game:GetService("Players").LocalPlayer
local N = game:GetService("ReplicatedStorage").Packages.Networking
local Snapshot = N["RF/EggWorld/AskLiveSnapshot"]
local Hatch = N["RF/EggWorld/AskHatch"]
local Finish = N["RF/EggWorld/AskFinishHatch"]

getgenv().AutoHatch = true

while getgenv().AutoHatch do
	local ok, rows = pcall(Snapshot.InvokeServer, Snapshot)
	if ok and type(rows) == "table" then
		for _, row in ipairs(rows) do
			if row.OwnerUserId == P.UserId then
				for uid, egg in pairs(row.Records) do
					if egg.Placement then
						local s, started = pcall(Hatch.InvokeServer, Hatch, uid)
						if s and started == true then
							pcall(Finish.InvokeServer, Finish, uid)
						end
					end
				end
			end
		end
	end
	task.wait(1)
end
