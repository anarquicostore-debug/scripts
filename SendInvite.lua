-- ─── SERVICES ─────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LP = Players.LocalPlayer

-- ─── GUI ROOT ─────────────────────────────────────────────────────────────────
local root = gethui and gethui() or game:GetService("CoreGui")

local old = root:FindFirstChild("TradeInviteGUI")
if old then old:Destroy() end

-- ScreenGui
local sg = Instance.new("ScreenGui")
sg.Name           = "TradeInviteGUI"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = root

-- ─── FRAME PRINCIPAL ──────────────────────────────────────────────────────────
local frame = Instance.new("Frame")
frame.Name              = "Frame"
frame.Size              = UDim2.new(0, 320, 0, 200)
frame.Position          = UDim2.new(0.5, -160, 0.5, -100)
frame.BackgroundColor3  = Color3.fromRGB(12, 12, 12)
frame.BorderSizePixel   = 0
frame.Active            = true
frame.Draggable         = true
frame.Parent            = sg

local c1 = Instance.new("UICorner")
c1.CornerRadius = UDim.new(0, 10)
c1.Parent = frame

-- Borda externa vermelha
local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(180, 20, 20)
stroke.Thickness = 1.5
stroke.Parent    = frame

-- ─── BARRA TOPO ───────────────────────────────────────────────────────────────
local topBar = Instance.new("Frame")
topBar.Name             = "TopBar"
topBar.Size             = UDim2.new(1, 0, 0, 42)
topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
topBar.BorderSizePixel  = 0
topBar.Parent           = frame

local c2 = Instance.new("UICorner")
c2.CornerRadius = UDim.new(0, 10)
c2.Parent = topBar

-- Correção: quadrar a parte de baixo do topBar
local fix = Instance.new("Frame")
fix.Size             = UDim2.new(1, 0, 0, 10)
fix.Position         = UDim2.new(0, 0, 1, -10)
fix.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
fix.BorderSizePixel  = 0
fix.Parent           = topBar

-- Título
local title = Instance.new("TextLabel")
title.Size                  = UDim2.new(1, -50, 1, 0)
title.Position              = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text                  = "⚔  Trade Sender"
title.TextColor3            = Color3.fromRGB(220, 220, 220)
title.Font                  = Enum.Font.GothamBold
title.TextSize              = 13
title.TextXAlignment        = Enum.TextXAlignment.Left
title.Parent                = topBar

-- Botão fechar
local closeBtn = Instance.new("TextButton")
closeBtn.Name              = "CloseBtn"
closeBtn.Size              = UDim2.new(0, 26, 0, 26)
closeBtn.Position          = UDim2.new(1, -34, 0.5, -13)
closeBtn.BackgroundColor3  = Color3.fromRGB(160, 20, 20)
closeBtn.Text              = "✕"
closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.TextSize          = 12
closeBtn.BorderSizePixel   = 0
closeBtn.Parent            = topBar

local c3 = Instance.new("UICorner")
c3.CornerRadius = UDim.new(0, 6)
c3.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    sg:Destroy()
end)

-- ─── LABEL ────────────────────────────────────────────────────────────────────
local lbl = Instance.new("TextLabel")
lbl.Size                  = UDim2.new(1, -24, 0, 18)
lbl.Position              = UDim2.new(0, 12, 0, 52)
lbl.BackgroundTransparency = 1
lbl.Text                  = "Username do Roblox"
lbl.TextColor3            = Color3.fromRGB(130, 130, 130)
lbl.Font                  = Enum.Font.Gotham
lbl.TextSize              = 11
lbl.TextXAlignment        = Enum.TextXAlignment.Left
lbl.Parent                = frame

-- ─── INPUT FRAME ──────────────────────────────────────────────────────────────
local inputFrame = Instance.new("Frame")
inputFrame.Name             = "InputFrame"
inputFrame.Size             = UDim2.new(1, -24, 0, 36)
inputFrame.Position         = UDim2.new(0, 12, 0, 72)
inputFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
inputFrame.BorderSizePixel  = 0
inputFrame.Parent           = frame

local c4 = Instance.new("UICorner")
c4.CornerRadius = UDim.new(0, 6)
c4.Parent = inputFrame

local inputStroke = Instance.new("UIStroke")
inputStroke.Color     = Color3.fromRGB(50, 50, 50)
inputStroke.Thickness = 1
inputStroke.Parent    = inputFrame

-- TextBox
local tb = Instance.new("TextBox")
tb.Name                 = "TextBox"
tb.Size                 = UDim2.new(1, -16, 1, 0)
tb.Position             = UDim2.new(0, 10, 0, 0)
tb.BackgroundTransparency = 1
tb.PlaceholderText      = "ex: Builderman"
tb.PlaceholderColor3    = Color3.fromRGB(70, 70, 70)
tb.Text                 = ""
tb.TextColor3           = Color3.fromRGB(230, 230, 230)
tb.Font                 = Enum.Font.Gotham
tb.TextSize             = 13
tb.TextXAlignment       = Enum.TextXAlignment.Left
tb.ClearTextOnFocus     = false
tb.Parent               = inputFrame

tb.Focused:Connect(function()
    TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(180, 20, 20)}):Play()
end)
tb.FocusLost:Connect(function()
    TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(50, 50, 50)}):Play()
end)

-- ─── BOTÃO SEND ───────────────────────────────────────────────────────────────
local sendBtn = Instance.new("TextButton")
sendBtn.Name              = "SendBtn"
sendBtn.Size              = UDim2.new(1, -24, 0, 36)
sendBtn.Position          = UDim2.new(0, 12, 0, 118)
sendBtn.BackgroundColor3  = Color3.fromRGB(170, 20, 20)
sendBtn.Text              = "ENVIAR TRADE"
sendBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
sendBtn.Font              = Enum.Font.GothamBold
sendBtn.TextSize          = 13
sendBtn.BorderSizePixel   = 0
sendBtn.AutoButtonColor   = false
sendBtn.Parent            = frame

local c5 = Instance.new("UICorner")
c5.CornerRadius = UDim.new(0, 6)
c5.Parent = sendBtn

sendBtn.MouseEnter:Connect(function()
    TweenService:Create(sendBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(210, 30, 30)}):Play()
end)
sendBtn.MouseLeave:Connect(function()
    TweenService:Create(sendBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(170, 20, 20)}):Play()
end)

-- ─── STATUS ───────────────────────────────────────────────────────────────────
local status = Instance.new("TextLabel")
status.Name                 = "Status"
status.Size                 = UDim2.new(1, -24, 0, 16)
status.Position             = UDim2.new(0, 12, 0, 162)
status.BackgroundTransparency = 1
status.Text                 = ""
status.TextColor3           = Color3.fromRGB(130, 130, 130)
status.Font                 = Enum.Font.Gotham
status.TextSize             = 11
status.TextXAlignment       = Enum.TextXAlignment.Center
status.Parent               = frame

local function setStatus(msg, r, g, b, duration)
    status.Text       = msg
    status.TextColor3 = Color3.fromRGB(r, g, b)
    if duration then
        task.delay(duration, function()
            if status.Text == msg then status.Text = "" end
        end)
    end
end

-- ─── INVITE REMOTE ────────────────────────────────────────────────────────────
-- Tirado do TradeController (Steal a Brainrot):
--   v13:RemoteFunction("TradeService/Invite")
--   InvokeServer("8fbe1594-7cef-4c29-94d1-a0e93adfa5a4", userId) -> (ok, erro, inviteId)
local INVITE_GUID = "8fbe1594-7cef-4c29-94d1-a0e93adfa5a4"
local REMOTE_NAME = "TradeService/Invite"

local function findInviteRemote()
    -- 1) Mesmo caminho que o jogo usa: require(Packages.Net):RemoteFunction(...)
    local ok, remote = pcall(function()
        local Net = require(ReplicatedStorage:WaitForChild("Packages", 10):WaitForChild("Net", 10))
        return Net:RemoteFunction(REMOTE_NAME)
    end)
    if ok and typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
        return remote
    end

    -- 2) Fallback: procura a RemoteFunction pelo nome
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if inst:IsA("RemoteFunction")
            and (inst.Name == REMOTE_NAME or inst.Name == "RF/" .. REMOTE_NAME) then
            return inst
        end
    end
    return nil
end

local inviteRemote = findInviteRemote()

-- ─── LÓGICA DO BOTÃO ──────────────────────────────────────────────────────────
sendBtn.MouseButton1Click:Connect(function()
    local name = tb.Text:match("^%s*(.-)%s*$")

    if name == "" then
        setStatus("⚠ Digite um username!", 220, 80, 80, 3)
        return
    end

    if not inviteRemote then
        setStatus("✕ Remote não encontrada.", 220, 60, 60, 4)
        return
    end

    sendBtn.Text   = "Buscando..."
    sendBtn.Active = false
    setStatus("Buscando " .. name .. "...", 130, 130, 130)

    local ok, uid = pcall(function()
        return Players:GetUserIdFromNameAsync(name)
    end)

    if not ok or not uid then
        setStatus("✕ Jogador não encontrado.", 220, 60, 60, 3)
        sendBtn.Text   = "ENVIAR TRADE"
        sendBtn.Active = true
        return
    end

    setStatus("Enviando invite...", 130, 130, 130)

    local callOk, sent, err = pcall(function()
        return inviteRemote:InvokeServer(INVITE_GUID, uid)
    end)
    if not callOk then
        err  = sent
        sent = false
    end

    task.wait(0.3)

    if sent then
        setStatus("✔ Invite enviado para " .. name, 60, 200, 100, 5)
    else
        setStatus("✕ Falhou: " .. tostring(err or "erro desconhecido"), 220, 60, 60, 4)
    end

    sendBtn.Text   = "ENVIAR TRADE"
    sendBtn.Active = true
end)