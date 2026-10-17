--[[
	Skeleton Viewer - Steal a Brainrot
	Procura em tempo real tudo que tem "Skeleton" no nome (ferramentas, brainrots,
	modelos, acessorios...) e mostra numa lista. Clique num item para ver em 3D.

	Controles do preview:
	  - Arrastar com o mouse/dedo: gira
	  - Roda do mouse / botoes + e -: zoom
	  - Botao "Auto": liga/desliga rotacao automatica
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local SEARCH_TERMS = { "skelet" } -- pega Skeleton, Skeletono, Skeletonini...

-- Nomes encontrados nos dados do jogo (Datas) - aparecem mesmo se o modelo
-- ainda nao tiver sido carregado, marcados como "nao carregado".
local KNOWN = {
	{ Name = "Vulturino Skeletono", Kind = "Brainrot (Secret)" },
	{ Name = "Dragon Skeletonini", Kind = "Brainrot (Secret)" },
}

---------------------------------------------------------------------------
-- Busca
---------------------------------------------------------------------------

local function matches(name)
	local lower = string.lower(name)
	for _, term in ipairs(SEARCH_TERMS) do
		if string.find(lower, term, 1, true) then
			return true
		end
	end
	return false
end

local function isPreviewable(inst)
	return inst:IsA("Model") or inst:IsA("Tool") or inst:IsA("Accessory") or inst:IsA("BasePart")
end

local function hasGeometry(inst)
	if inst:IsA("BasePart") then
		return true
	end
	return inst:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function kindOf(inst)
	local path = inst:GetFullName()
	if inst:IsA("Tool") or string.find(path, "Tools", 1, true) then
		return "Item / Tool"
	elseif string.find(path, "Animals", 1, true) then
		return "Brainrot"
	elseif inst:IsA("Accessory") then
		return "Acessorio"
	end
	return inst.ClassName
end

local function scan()
	local roots = {
		ReplicatedStorage,
		game:GetService("StarterPack"),
		game:GetService("Lighting"),
		workspace,
		player:FindFirstChild("Backpack"),
		player.Character,
	}

	local results, seen = {}, {}
	for _, root in ipairs(roots) do
		if root then
			local ok, descendants = pcall(root.GetDescendants, root)
			if ok then
				for _, inst in ipairs(descendants) do
					if not seen[inst] and isPreviewable(inst) and matches(inst.Name) and hasGeometry(inst) then
						-- ignora pecas internas de algo que ja entrou na lista
						local ancestorListed = false
						local p = inst.Parent
						while p and p ~= game do
							if seen[p] then
								ancestorListed = true
								break
							end
							p = p.Parent
						end
						-- ignora personagens de jogadores
						local isPlayerChar = false
						for _, plr in ipairs(Players:GetPlayers()) do
							if plr.Character and (inst == plr.Character) then
								isPlayerChar = true
							end
						end
						if not ancestorListed and not isPlayerChar then
							seen[inst] = true
							table.insert(results, {
								Name = inst.Name,
								Kind = kindOf(inst),
								Path = inst:GetFullName(),
								Instance = inst,
							})
						end
					end
				end
			end
		end
	end

	-- adiciona os conhecidos que nao apareceram
	for _, known in ipairs(KNOWN) do
		local found = false
		for _, r in ipairs(results) do
			if r.Name == known.Name then
				found = true
				break
			end
		end
		if not found then
			table.insert(results, { Name = known.Name, Kind = known.Kind, Path = "(nao carregado)" })
		end
	end

	table.sort(results, function(a, b)
		if a.Kind ~= b.Kind then
			return a.Kind < b.Kind
		end
		return a.Name < b.Name
	end)
	return results
end

---------------------------------------------------------------------------
-- Clonagem para o preview
---------------------------------------------------------------------------

local function makePreviewModel(source)
	local wasArchivable = source.Archivable
	pcall(function()
		source.Archivable = true
		for _, d in ipairs(source:GetDescendants()) do
			d.Archivable = true
		end
	end)
	local ok, clone = pcall(source.Clone, source)
	pcall(function()
		source.Archivable = wasArchivable
	end)
	if not ok or not clone then
		return nil
	end

	local model
	if clone:IsA("Model") then
		model = clone
	else
		model = Instance.new("Model")
		model.Name = clone.Name
		if clone:IsA("BasePart") then
			clone.Parent = model
		else
			for _, child in ipairs(clone:GetChildren()) do
				child.Parent = model
			end
			clone:Destroy()
		end
	end

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ProximityPrompt")
			or d:IsA("BillboardGui") or d:IsA("ClickDetector") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	return model
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local function pickGuiParent()
	if gethui then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end
	local ok, coreGui = pcall(function()
		local cg = game:GetService("CoreGui")
		local _ = cg:GetChildren() -- falha se nao tiver permissao
		return cg
	end)
	if ok and coreGui then
		return coreGui
	end
	return player:WaitForChild("PlayerGui")
end

local guiParent = pickGuiParent()

local old = guiParent:FindFirstChild("SkeletonViewer")
if old then
	old:Destroy()
end

local COLORS = {
	bg = Color3.fromRGB(22, 22, 28),
	panel = Color3.fromRGB(32, 32, 40),
	item = Color3.fromRGB(44, 44, 54),
	itemHover = Color3.fromRGB(60, 60, 74),
	accent = Color3.fromRGB(235, 235, 235),
	text = Color3.fromRGB(240, 240, 240),
	sub = Color3.fromRGB(150, 150, 165),
	missing = Color3.fromRGB(200, 120, 120),
}

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

local function label(parent, text, size, color, bold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size or 14
	l.TextColor3 = color or COLORS.text
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function button(parent, text)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = COLORS.item
	b.AutoButtonColor = true
	b.Text = text
	b.TextSize = 14
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = COLORS.text
	b.Parent = parent
	corner(b, 6)
	return b
end

local screen = Instance.new("ScreenGui")
screen.Name = "SkeletonViewer"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.IgnoreGuiInset = true
if not pcall(function() screen.Parent = guiParent end) then
	screen.Parent = player:WaitForChild("PlayerGui")
end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(640, 400)
main.Position = UDim2.new(0.5, -320, 0.5, -200)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = screen
corner(main, 10)

-- barra de titulo (arrastavel)
local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 36)
top.BackgroundColor3 = COLORS.panel
top.BorderSizePixel = 0
top.Parent = main
corner(top, 10)

local title = label(top, "💀 Skeleton Viewer", 16, COLORS.text, true)
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(1, -200, 1, 0)

local closeBtn = button(top, "X")
closeBtn.Size = UDim2.fromOffset(28, 24)
closeBtn.Position = UDim2.new(1, -34, 0, 6)

local minBtn = button(top, "–")
minBtn.Size = UDim2.fromOffset(28, 24)
minBtn.Position = UDim2.new(1, -66, 0, 6)

local rescanBtn = button(top, "Atualizar")
rescanBtn.Size = UDim2.fromOffset(80, 24)
rescanBtn.Position = UDim2.new(1, -152, 0, 6)

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(0, 40)
body.Size = UDim2.new(1, 0, 1, -40)
body.Parent = main

-- lista (esquerda)
local left = Instance.new("Frame")
left.BackgroundColor3 = COLORS.panel
left.Position = UDim2.fromOffset(8, 0)
left.Size = UDim2.new(0, 250, 1, -8)
left.Parent = body
corner(left, 8)

local searchBox = Instance.new("TextBox")
searchBox.PlaceholderText = "Filtrar..."
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.TextSize = 14
searchBox.Font = Enum.Font.Gotham
searchBox.TextColor3 = COLORS.text
searchBox.PlaceholderColor3 = COLORS.sub
searchBox.BackgroundColor3 = COLORS.item
searchBox.Position = UDim2.fromOffset(6, 6)
searchBox.Size = UDim2.new(1, -12, 0, 28)
searchBox.Parent = left
corner(searchBox, 6)

local countLabel = label(left, "", 12, COLORS.sub)
countLabel.Position = UDim2.fromOffset(10, 36)
countLabel.Size = UDim2.new(1, -20, 0, 16)

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(6, 54)
list.Size = UDim2.new(1, -12, 1, -60)
list.ScrollBarThickness = 4
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = left

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

-- preview (direita)
local right = Instance.new("Frame")
right.BackgroundColor3 = COLORS.panel
right.Position = UDim2.fromOffset(266, 0)
right.Size = UDim2.new(1, -274, 1, -8)
right.Parent = body
corner(right, 8)

local viewport = Instance.new("ViewportFrame")
viewport.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
viewport.Position = UDim2.fromOffset(6, 6)
viewport.Size = UDim2.new(1, -12, 1, -64)
viewport.Ambient = Color3.fromRGB(170, 170, 170)
viewport.LightColor = Color3.fromRGB(255, 255, 255)
viewport.LightDirection = Vector3.new(-1, -1, -1)
viewport.Parent = right
corner(viewport, 6)

local worldModel = Instance.new("WorldModel")
worldModel.Parent = viewport

local cam = Instance.new("Camera")
cam.FieldOfView = 40
cam.Parent = viewport
viewport.CurrentCamera = cam

local hint = label(viewport, "Clique num item da lista", 14, COLORS.sub)
hint.TextXAlignment = Enum.TextXAlignment.Center
hint.Size = UDim2.fromScale(1, 1)

local nameLabel = label(right, "", 15, COLORS.text, true)
nameLabel.Position = UDim2.new(0, 10, 1, -56)
nameLabel.Size = UDim2.new(1, -150, 0, 20)

local pathLabel = label(right, "", 11, COLORS.sub)
pathLabel.Position = UDim2.new(0, 10, 1, -34)
pathLabel.Size = UDim2.new(1, -150, 0, 26)
pathLabel.TextWrapped = true
pathLabel.TextYAlignment = Enum.TextYAlignment.Top

local autoBtn = button(right, "Auto: ON")
autoBtn.Size = UDim2.fromOffset(70, 26)
autoBtn.Position = UDim2.new(1, -136, 1, -44)

local zoomIn = button(right, "+")
zoomIn.Size = UDim2.fromOffset(26, 26)
zoomIn.Position = UDim2.new(1, -62, 1, -44)

local zoomOut = button(right, "-")
zoomOut.Size = UDim2.fromOffset(26, 26)
zoomOut.Position = UDim2.new(1, -32, 1, -44)

---------------------------------------------------------------------------
-- Logica do preview
---------------------------------------------------------------------------

local current = nil
local center = Vector3.zero
local radius = 5
local yaw, pitch = 0, -15
local distance = 10
local autoRotate = true

local function updateCamera()
	local rot = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)
	cam.CFrame = CFrame.new(center) * rot * CFrame.new(0, 0, distance)
end

local function showEntry(entry)
	if current then
		current:Destroy()
		current = nil
	end
	nameLabel.Text = entry.Name .. "  ·  " .. entry.Kind
	pathLabel.Text = entry.Path

	local inst = entry.Instance
	if not inst or not inst.Parent then
		hint.Text = "Modelo nao carregado no seu cliente.\nChegue perto / abra o Index e clique em Atualizar."
		hint.TextColor3 = COLORS.missing
		hint.Visible = true
		return
	end

	local model = makePreviewModel(inst)
	if not model then
		hint.Text = "Nao foi possivel clonar este modelo."
		hint.TextColor3 = COLORS.missing
		hint.Visible = true
		return
	end
	model.Parent = worldModel
	current = model

	local cf, size = model:GetBoundingBox()
	center = cf.Position
	radius = math.max(size.Magnitude / 2, 0.5)
	distance = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 1.15
	yaw, pitch = 0, -15
	hint.Visible = false
	updateCamera()
end

local entries = {}

local function rebuildList()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local filter = string.lower(searchBox.Text)
	local shown = 0
	for i, entry in ipairs(entries) do
		if filter == "" or string.find(string.lower(entry.Name), filter, 1, true) then
			shown += 1
			local loaded = entry.Instance ~= nil
			local b = Instance.new("TextButton")
			b.Text = ""
			b.AutoButtonColor = false
			b.BackgroundColor3 = COLORS.item
			b.Size = UDim2.new(1, -4, 0, 40)
			b.LayoutOrder = i
			b.Parent = list
			corner(b, 6)

			local n = label(b, entry.Name, 14, loaded and COLORS.text or COLORS.missing, true)
			n.Position = UDim2.fromOffset(8, 3)
			n.Size = UDim2.new(1, -16, 0, 18)
			local k = label(b, entry.Kind .. (loaded and "" or "  (nao carregado)"), 11, COLORS.sub)
			k.Position = UDim2.fromOffset(8, 21)
			k.Size = UDim2.new(1, -16, 0, 14)

			b.MouseEnter:Connect(function() b.BackgroundColor3 = COLORS.itemHover end)
			b.MouseLeave:Connect(function() b.BackgroundColor3 = COLORS.item end)
			b.MouseButton1Click:Connect(function() showEntry(entry) end)
		end
	end
	countLabel.Text = shown .. " de " .. #entries .. " itens"
end

local function refresh()
	entries = scan()
	rebuildList()
	-- imprime a lista no console (F9) tambem
	print("==== Skeleton Viewer: " .. #entries .. " itens ====")
	for _, e in ipairs(entries) do
		print(string.format("[%s] %s  ->  %s", e.Kind, e.Name, e.Path))
	end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(rebuildList)
rescanBtn.MouseButton1Click:Connect(refresh)

autoBtn.MouseButton1Click:Connect(function()
	autoRotate = not autoRotate
	autoBtn.Text = autoRotate and "Auto: ON" or "Auto: OFF"
end)

zoomIn.MouseButton1Click:Connect(function()
	distance = math.max(distance * 0.8, radius * 0.5)
	updateCamera()
end)
zoomOut.MouseButton1Click:Connect(function()
	distance = math.min(distance * 1.25, radius * 20)
	updateCamera()
end)

-- girar arrastando
local dragging = false
local lastPos
viewport.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		lastPos = input.Position
	end
end)
viewport.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local factor = input.Position.Z > 0 and 0.9 or 1.1
		distance = math.clamp(distance * factor, radius * 0.5, radius * 20)
		updateCamera()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - lastPos
		lastPos = input.Position
		yaw -= delta.X * 0.5
		pitch = math.clamp(pitch - delta.Y * 0.5, -80, 80)
		updateCamera()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local renderConn = RunService.RenderStepped:Connect(function(dt)
	if current and autoRotate and not dragging then
		yaw += dt * 30
		updateCamera()
	end
end)

-- arrastar janela
do
	local moving, startPos, startInput
	top.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			moving = true
			startPos = main.Position
			startInput = input.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if moving and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startInput
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			moving = false
		end
	end)
end

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	main.Size = minimized and UDim2.fromOffset(640, 36) or UDim2.fromOffset(640, 400)
end)

closeBtn.MouseButton1Click:Connect(function()
	renderConn:Disconnect()
	screen:Destroy()
end)

refresh()
