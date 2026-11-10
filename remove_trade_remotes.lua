-- Remove no cliente as remotes de trade, achando-as nos upvalues dos controllers Trade* (sem nomes fixos)
local RS = game:GetService("ReplicatedStorage")
local getups = (debug and debug.getupvalues) or getupvalues
local okNet, Net = pcall(require, RS.Packages.Net)
-- o TradeController também guarda esta remote de configurações; ela não é de trade e fica preservada
local keep = okNet and select(2, pcall(Net.RemoteFunction, Net, "SettingsService/ToggleSetting"))
for _, module in ipairs(RS.Controllers:GetChildren()) do
	if module.Name:find("^Trade") then
		task.spawn(function()
			local seen = {}
			local function walk(fn)
				if type(fn) ~= "function" or seen[fn] then return end
				seen[fn] = true
				local ok, ups = pcall(getups, fn)
				for _, v in pairs(ok and ups or {}) do
					if typeof(v) == "Instance" and v ~= keep and (v:IsA("BaseRemoteEvent") or v:IsA("RemoteFunction")) then
						pcall(v.Destroy, v)
					elseif type(v) == "function" and debug.info(v, "s") == debug.info(fn, "s") then
						walk(v) -- só desce em funções do mesmo script, para não alcançar outros controllers
					end
				end
			end
			local ok, controller = pcall(require, module)
			for _, fn in pairs(ok and type(controller) == "table" and controller or {}) do walk(fn) end
		end)
	end
end
