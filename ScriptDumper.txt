--[[
	Script Dumper (Delta / executores com decompile + writefile)

	Percorre os serviços do cliente, decompila todo LocalScript / ModuleScript
	(e Scripts com RunContext = Client) e salva cada um como .lua na pasta
	"workspace" do executor, mantendo a hierarquia de instâncias:

	    <Pasta>/Controllers/ActionController.lua      <- o script
	    <Pasta>/Controllers/ActionController/...      <- os filhos dele

	Scripts sem bytecode disponível viram "-- failed to get script bytecode".
]]

local CONFIG = {
	-- Nome da pasta de saída (vazio = "<NomeDoJogo> Dump")
	FolderName = "",

	-- true  -> Pasta/ReplicatedStorage/Shared/X.lua
	-- false -> Pasta/Shared/X.lua (igual ao dump de exemplo)
	IncludeServiceFolder = false,

	-- Onde procurar scripts
	Services = {
		"ReplicatedStorage",
		"ReplicatedFirst",
		"StarterPlayer",
		"StarterGui",
		"StarterPack",
		"Workspace",
		"Lighting",
		"SoundService",
		"Chat",
		"Teams",
	},
	IncludePlayerScripts = true, -- LocalPlayer.PlayerScripts / PlayerGui / Backpack / Character
	IncludeNilInstances = true, -- scripts parentados a nil (getnilinstances)
	IncludeLoadedModules = true, -- módulos carregados fora da árvore (getloadedmodules)

	-- Ignora scripts internos do Roblox (PlayerModule, ChatScript, RbxCharacterSounds...)
	SkipCoreScripts = true,

	DecompileTimeout = 10, -- segundos por script
	YieldEvery = 10, -- pausa a cada N scripts para não travar o jogo
}

---------------------------------------------------------------------------
-- Funções do executor
---------------------------------------------------------------------------
local env = getgenv and getgenv() or _G
local decompile = env.decompile or decompile
local getscriptbytecode = env.getscriptbytecode or getscriptbytecode
local writefile = env.writefile or writefile
local makefolder = env.makefolder or makefolder
local isfolder = env.isfolder or isfolder
local getnilinstances = env.getnilinstances or getnilinstances
local getloadedmodules = env.getloadedmodules or getloadedmodules

assert(decompile, "Executor sem suporte a decompile()")
assert(writefile and makefolder, "Executor sem suporte a writefile()/makefolder()")

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local function notify(text)
	print("[Dumper] " .. text)
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
		Title = "Script Dumper",
		Text = text,
		Duration = 5,
	})
end

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local function sanitize(name)
	name = tostring(name):gsub('[<>:"/\\|%?%*%c]', "_"):gsub("^%s+", ""):gsub("%s+$", "")
	name = name:gsub("%.+$", "")
	if name == "" then
		name = "_"
	end
	return name
end

local createdFolders = {}
local function ensureFolder(path)
	if createdFolders[path] then
		return
	end
	local current = ""
	for part in path:gmatch("[^/]+") do
		current = current == "" and part or (current .. "/" .. part)
		if not createdFolders[current] then
			if not (isfolder and isfolder(current)) then
				pcall(makefolder, current)
			end
			createdFolders[current] = true
		end
	end
end

local function isDumpable(inst)
	if inst:IsA("ModuleScript") or inst:IsA("LocalScript") then
		return true
	end
	if inst:IsA("Script") then
		local ok, ctx = pcall(function()
			return inst.RunContext
		end)
		return ok and ctx == Enum.RunContext.Client
	end
	return false
end

local CORE_NAMES = {
	PlayerModule = true,
	ChatScript = true,
	BubbleChat = true,
	RbxCharacterSounds = true,
	PlayerScriptsLoader = true,
	Animate = false, -- Animate costuma ser customizado pelo jogo, mantém
	Health = true,
}

local function isCore(inst)
	if not CONFIG.SkipCoreScripts then
		return false
	end
	local node = inst
	while node and node ~= game do
		if CORE_NAMES[node.Name] then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Decompila com timeout (alguns decompiladores travam em scripts grandes)
local function decompileWithTimeout(scr)
	if getscriptbytecode then
		local ok, bc = pcall(getscriptbytecode, scr)
		if not ok or not bc or bc == "" then
			return "-- failed to get script bytecode"
		end
	end

	local result, done = nil, false
	task.spawn(function()
		local ok, src = pcall(decompile, scr)
		if ok and type(src) == "string" then
			result = src
		else
			result = "-- failed to decompile: " .. tostring(src)
		end
		done = true
	end)

	local start = os.clock()
	while not done do
		if os.clock() - start > CONFIG.DecompileTimeout then
			return "-- decompile timed out"
		end
		task.wait()
	end
	return result
end

---------------------------------------------------------------------------
-- Coleta
---------------------------------------------------------------------------
local gameName = "Game_" .. game.PlaceId
pcall(function()
	gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
end)

local ROOT = CONFIG.FolderName ~= "" and CONFIG.FolderName or (sanitize(gameName) .. " Dump")

local queue = {} -- { inst = Instance, path = "Pasta/.../Nome" }
local seen = {}
local usedPaths = {}

local function uniquePath(path)
	if not usedPaths[path] then
		usedPaths[path] = true
		return path
	end
	local i = 2
	while usedPaths[path .. " (" .. i .. ")"] do
		i += 1
	end
	path = path .. " (" .. i .. ")"
	usedPaths[path] = true
	return path
end

-- Caminho relativo a "root" (o serviço/container de origem)
local function relativePath(inst, root, prefix)
	local parts = {}
	local node = inst
	while node and node ~= root and node ~= game do
		table.insert(parts, 1, sanitize(node.Name))
		node = node.Parent
	end
	if prefix and prefix ~= "" then
		table.insert(parts, 1, prefix)
	end
	return table.concat(parts, "/")
end

local function add(inst, path)
	if seen[inst] or isCore(inst) then
		return
	end
	seen[inst] = true
	table.insert(queue, { inst = inst, path = uniquePath(ROOT .. "/" .. path) })
end

local function scan(root, prefix)
	local ok, descendants = pcall(root.GetDescendants, root)
	if not ok then
		return
	end
	for _, inst in ipairs(descendants) do
		if isDumpable(inst) then
			add(inst, relativePath(inst, root, prefix))
		end
	end
end

notify("Procurando scripts...")

for _, serviceName in ipairs(CONFIG.Services) do
	local ok, service = pcall(game.GetService, game, serviceName)
	if ok and service then
		scan(service, CONFIG.IncludeServiceFolder and serviceName or "")
	end
end

if CONFIG.IncludePlayerScripts and LocalPlayer then
	for _, name in ipairs({ "PlayerScripts", "PlayerGui", "Backpack" }) do
		local container = LocalPlayer:FindFirstChild(name)
		if container then
			scan(container, CONFIG.IncludeServiceFolder and name or "")
		end
	end
	if LocalPlayer.Character then
		scan(LocalPlayer.Character, "Character")
	end
end

if CONFIG.IncludeNilInstances and getnilinstances then
	local ok, list = pcall(getnilinstances)
	if ok then
		for _, inst in ipairs(list) do
			if isDumpable(inst) then
				add(inst, "Nil/" .. sanitize(inst.Name))
			end
			if typeof(inst) == "Instance" then
				scan(inst, "Nil/" .. sanitize(inst.Name))
			end
		end
	end
end

if CONFIG.IncludeLoadedModules and getloadedmodules then
	local ok, list = pcall(getloadedmodules)
	if ok then
		for _, mod in ipairs(list) do
			if not seen[mod] then
				add(mod, "LoadedModules/" .. relativePath(mod, game, ""))
			end
		end
	end
end

local total = #queue
if total == 0 then
	notify("Nenhum script encontrado.")
	return
end
notify(("Encontrados %d scripts. Decompilando..."):format(total))

---------------------------------------------------------------------------
-- Dump
---------------------------------------------------------------------------
ensureFolder(ROOT)

local okCount, failCount = 0, 0
local startTime = os.clock()

for i, item in ipairs(queue) do
	local source = decompileWithTimeout(item.inst)
	if source:sub(1, 3) == "-- " and (source:find("^%-%- failed") or source:find("^%-%- decompile timed out")) then
		failCount += 1
	else
		okCount += 1
	end

	local folder = item.path:match("^(.*)/[^/]+$")
	if folder then
		ensureFolder(folder)
	end

	local wrote = pcall(writefile, item.path .. ".lua", source)
	if not wrote then
		warn("[Dumper] Falha ao salvar: " .. item.path)
	end

	if i % CONFIG.YieldEvery == 0 then
		print(("[Dumper] %d/%d"):format(i, total))
		task.wait()
	end
end

notify(("Pronto! %d ok, %d falharam (%.1fs). Pasta: %s"):format(okCount, failCount, os.clock() - startTime, ROOT))
