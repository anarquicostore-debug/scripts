-- save_place.lua
-- Executa com Remodel: remodel run save_place.lua
-- Gera um .rbxl do jogo montado aqui.

local game = remodel.readPlaceFile("base.rbxlx") or Instance.new("DataModel")

-- Workspace
local workspace = game:GetService("Workspace")

-- Baseplate
local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Size = Vector3.new(512, 1, 512)
baseplate.Position = Vector3.new(0, -0.5, 0)
baseplate.Anchored = true
baseplate.Parent = workspace

-- SpawnLocation
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 1, 0)
spawn.Anchored = true
spawn.Parent = workspace

-- ServerScriptService
local sss = game:GetService("ServerScriptService")

local serverScript = Instance.new("Script")
serverScript.Name = "GameScript"
remodel.setRawProperty(serverScript, "Source", "String", [[
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    print("Bem-vindo, " .. player.Name .. "!")
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.WalkSpeed = 20
        humanoid.JumpHeight = 10
    end)
end)

print("Servidor iniciado!")
]])
serverScript.Parent = sss

-- StarterGui com LocalScript de boas-vindas
local starterGui = game:GetService("StarterGui")

local guiScript = Instance.new("LocalScript")
guiScript.Name = "WelcomeGui"
remodel.setRawProperty(guiScript, "Source", "String", [[
local player = game:GetService("Players").LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Parent = player.PlayerGui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0.3, 0, 0.05, 0)
label.Position = UDim2.new(0.35, 0, 0.02, 0)
label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
label.BackgroundTransparency = 0.5
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Text = "Bem-vindo ao Jogo!"
label.Parent = gui

task.delay(5, function()
    label:Destroy()
end)
]])
guiScript.Parent = starterGui

-- Lighting
local lighting = game:GetService("Lighting")
remodel.setRawProperty(lighting, "TimeOfDay", "String", "14:00:00")
remodel.setRawProperty(lighting, "Brightness", "Float32", 2)

-- Salva como .rbxl (binario)
local output = os.getenv("OUTPUT") or "MeuJogo.rbxl"
remodel.writePlaceFile(game, output)
print("Salvo: " .. output)
