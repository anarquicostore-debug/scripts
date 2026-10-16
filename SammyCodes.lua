--[[
	Steal a Brainrot - Sammy Top Messages + Code Redeemer

	Baseado no dump:
	  • Controllers/NotificationController.lua
	      Notify(self, text, duration, sound, position, userId, id, remove)
	      position == "Top"  -> mensagem no topo da tela (TopNotification),
	      userId             -> foto de quem mandou (admin)
	      Disparado pelo servidor via Net:RemoteEvent("NotificationService/Notify")
	  • Controllers/TextChatController.lua:29 / HudController.lua:497
	      UserId 2678001507 = Lead "[SPYDER]" (Sammy)
	  • Controllers/CodesController.lua:37
	      Net:RemoteFunction("d193b9bf-8b44-42af-b4b2-9c77847ce1e9"):InvokeServer(code)
	      -> retorna (sucesso, mensagem)
	      Código é filtrado para [%w] e no máximo 50 caracteres.

	Anti-cheat visto no dump (PlotController.lua:94-117): funções do jogo varrem
	getfenv(1..10) procurando cloneref/getrenv/getupvalues/getnamecallmethod.
	Por isso este script NÃO chama funções do jogo nem dispara remotes.
	O resgate só preenche o menu Codes do jogo; o clique em Confirm é seu.
]]

-- ─── SERVICES ─────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LP = Players.LocalPlayer
local genv = getgenv and getgenv() or _G

local SAMMY_ID    = 2678001507
local REDEEM_GUID = "d193b9bf-8b44-42af-b4b2-9c77847ce1e9"
local MAX_LOG     = 60

local getupvalues = debug.getupvalues or getupvalues

-- ─── GUI ROOT ─────────────────────────────────────────────────────────────────
local root = gethui and gethui() or game:GetService("CoreGui")

local old = root:FindFirstChild("SammyCodesGUI")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name           = "SammyCodesGUI"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = root

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = parent
    return c
end

-- ─── FRAME PRINCIPAL ──────────────────────────────────────────────────────────
local frame = Instance.new("Frame")
frame.Size             = UDim2.new(0, 360, 0, 420)
frame.Position         = UDim2.new(0.5, -180, 0.5, -210)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.Parent           = sg
corner(frame, 10)

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(180, 20, 20)
stroke.Thickness = 1.5
stroke.Parent    = frame

-- ─── BARRA TOPO ───────────────────────────────────────────────────────────────
local topBar = Instance.new("Frame")
topBar.Size             = UDim2.new(1, 0, 0, 42)
topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
topBar.BorderSizePixel  = 0
topBar.Parent           = frame
corner(topBar, 10)

local fix = Instance.new("Frame")
fix.Size             = UDim2.new(1, 0, 0, 10)
fix.Position         = UDim2.new(0, 0, 1, -10)
fix.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
fix.BorderSizePixel  = 0
fix.Parent           = topBar

local title = Instance.new("TextLabel")
title.Size                   = UDim2.new(1, -50, 1, 0)
title.Position               = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text                   = "🕷  Sammy Watcher + Codes"
title.TextColor3             = Color3.fromRGB(220, 220, 220)
title.Font                   = Enum.Font.GothamBold
title.TextSize               = 13
title.TextXAlignment         = Enum.TextXAlignment.Left
title.Parent                 = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 26, 0, 26)
closeBtn.Position         = UDim2.new(1, -34, 0.5, -13)
closeBtn.BackgroundColor3 = Color3.fromRGB(160, 20, 20)
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 12
closeBtn.BorderSizePixel  = 0
closeBtn.Parent           = topBar
corner(closeBtn, 6)

-- ─── SEÇÃO CÓDIGO ─────────────────────────────────────────────────────────────
local lbl = Instance.new("TextLabel")
lbl.Size                   = UDim2.new(1, -24, 0, 18)
lbl.Position               = UDim2.new(0, 12, 0, 52)
lbl.BackgroundTransparency = 1
lbl.Text                   = "Código"
lbl.TextColor3             = Color3.fromRGB(130, 130, 130)
lbl.Font                   = Enum.Font.Gotham
lbl.TextSize               = 11
lbl.TextXAlignment         = Enum.TextXAlignment.Left
lbl.Parent                 = frame

local inputFrame = Instance.new("Frame")
inputFrame.Size             = UDim2.new(1, -24, 0, 36)
inputFrame.Position         = UDim2.new(0, 12, 0, 72)
inputFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
inputFrame.BorderSizePixel  = 0
inputFrame.Parent           = frame
corner(inputFrame, 6)

local inputStroke = Instance.new("UIStroke")
inputStroke.Color     = Color3.fromRGB(50, 50, 50)
inputStroke.Thickness = 1
inputStroke.Parent    = inputFrame

local tb = Instance.new("TextBox")
tb.Size                   = UDim2.new(1, -16, 1, 0)
tb.Position               = UDim2.new(0, 10, 0, 0)
tb.BackgroundTransparency = 1
tb.PlaceholderText        = "Digite o código..."
tb.PlaceholderColor3      = Color3.fromRGB(70, 70, 70)
tb.Text                   = ""
tb.TextColor3             = Color3.fromRGB(230, 230, 230)
tb.Font                   = Enum.Font.Gotham
tb.TextSize               = 13
tb.TextXAlignment         = Enum.TextXAlignment.Left
tb.ClearTextOnFocus       = false
tb.Parent                 = inputFrame

tb.Focused:Connect(function()
    TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(180, 20, 20)}):Play()
end)
tb.FocusLost:Connect(function()
    TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(50, 50, 50)}):Play()
end)

local redeemBtn = Instance.new("TextButton")
redeemBtn.Size             = UDim2.new(1, -24, 0, 36)
redeemBtn.Position         = UDim2.new(0, 12, 0, 118)
redeemBtn.BackgroundColor3 = Color3.fromRGB(170, 20, 20)
redeemBtn.Text             = "RESGATAR"
redeemBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
redeemBtn.Font             = Enum.Font.GothamBold
redeemBtn.TextSize         = 13
redeemBtn.BorderSizePixel  = 0
redeemBtn.AutoButtonColor  = false
redeemBtn.Parent           = frame
corner(redeemBtn, 6)

redeemBtn.MouseEnter:Connect(function()
    TweenService:Create(redeemBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(210, 30, 30)}):Play()
end)
redeemBtn.MouseLeave:Connect(function()
    TweenService:Create(redeemBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(170, 20, 20)}):Play()
end)

local status = Instance.new("TextLabel")
status.Size                   = UDim2.new(1, -24, 0, 16)
status.Position               = UDim2.new(0, 12, 0, 160)
status.BackgroundTransparency = 1
status.Text                   = ""
status.TextColor3             = Color3.fromRGB(130, 130, 130)
status.Font                   = Enum.Font.Gotham
status.TextSize               = 11
status.TextTruncate           = Enum.TextTruncate.AtEnd
status.Parent                 = frame

local function setStatus(msg, r, g, b, duration)
    status.Text       = msg
    status.TextColor3 = Color3.fromRGB(r, g, b)
    if duration then
        task.delay(duration, function()
            if status.Text == msg then status.Text = "" end
        end)
    end
end

-- ─── SEÇÃO MENSAGENS DO TOPO ──────────────────────────────────────────────────
local logTitle = Instance.new("TextLabel")
logTitle.Size                   = UDim2.new(1, -110, 0, 18)
logTitle.Position               = UDim2.new(0, 12, 0, 184)
logTitle.BackgroundTransparency = 1
logTitle.Text                   = "Mensagens do topo (clique p/ copiar)"
logTitle.TextColor3             = Color3.fromRGB(130, 130, 130)
logTitle.Font                   = Enum.Font.Gotham
logTitle.TextSize               = 11
logTitle.TextXAlignment         = Enum.TextXAlignment.Left
logTitle.Parent                 = frame

local onlySammy = false
local filterBtn = Instance.new("TextButton")
filterBtn.Size             = UDim2.new(0, 90, 0, 18)
filterBtn.Position         = UDim2.new(1, -102, 0, 184)
filterBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
filterBtn.Text             = "Todos admins"
filterBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
filterBtn.Font             = Enum.Font.Gotham
filterBtn.TextSize         = 10
filterBtn.BorderSizePixel  = 0
filterBtn.Parent           = frame
corner(filterBtn, 4)

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size                 = UDim2.new(1, -24, 1, -216)
logFrame.Position             = UDim2.new(0, 12, 0, 206)
logFrame.BackgroundColor3     = Color3.fromRGB(18, 18, 18)
logFrame.BorderSizePixel      = 0
logFrame.ScrollBarThickness   = 4
logFrame.ScrollBarImageColor3 = Color3.fromRGB(180, 20, 20)
logFrame.CanvasSize           = UDim2.new()
logFrame.AutomaticCanvasSize  = Enum.AutomaticSize.Y
logFrame.Parent               = frame
corner(logFrame, 6)

local pad = Instance.new("UIPadding")
pad.PaddingTop    = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft   = UDim.new(0, 6)
pad.PaddingRight  = UDim.new(0, 8)
pad.Parent        = logFrame

local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding   = UDim.new(0, 4)
list.Parent    = logFrame

local entries  = {}
local order    = 0
local names    = { [SAMMY_ID] = "Sammy" }

local function displayName(userId)
    if not userId then return "Sistema" end
    if names[userId] then return names[userId] end
    local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
    names[userId] = ok and n or tostring(userId)
    return names[userId]
end

local function addEntry(text, userId)
    local isSammy = userId == SAMMY_ID
    if onlySammy and not isSammy then return end

    order -= 1 -- mais novo em cima
    local who = displayName(userId)

    local item = Instance.new("TextButton")
    item.Size                 = UDim2.new(1, 0, 0, 0)
    item.AutomaticSize        = Enum.AutomaticSize.Y
    item.BackgroundColor3     = isSammy and Color3.fromRGB(45, 12, 12) or Color3.fromRGB(26, 26, 26)
    item.BorderSizePixel      = 0
    item.AutoButtonColor      = true
    item.RichText             = true
    item.TextWrapped          = true
    item.TextXAlignment       = Enum.TextXAlignment.Left
    item.TextYAlignment       = Enum.TextYAlignment.Top
    item.Font                 = Enum.Font.Gotham
    item.TextSize             = 12
    item.TextColor3           = Color3.fromRGB(225, 225, 225)
    item.LayoutOrder          = order
    item.Text = ('<font color="#777777">%s</font>  <b><font color="%s">%s</font></b>\n%s'):format(
        os.date("%H:%M:%S"),
        isSammy and "#ff4040" or "#9fc1ff",
        who,
        text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    )
    item.Parent = logFrame
    corner(item, 4)

    local ip = Instance.new("UIPadding")
    ip.PaddingTop, ip.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
    ip.PaddingLeft, ip.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
    ip.Parent = item

    item.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(text)
            setStatus("Mensagem copiada.", 130, 130, 130, 2)
        end
    end)

    table.insert(entries, item)
    if #entries > MAX_LOG then
        table.remove(entries, 1):Destroy()
    end
    logFrame.CanvasPosition = Vector2.new(0, 0)
end

filterBtn.MouseButton1Click:Connect(function()
    onlySammy = not onlySammy
    filterBtn.Text = onlySammy and "Só Sammy" or "Todos admins"
    filterBtn.TextColor3 = onlySammy and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(200, 200, 200)
end)

-- ─── CAPTURA DAS MENSAGENS DO TOPO ────────────────────────────────────────────
local function stripRich(s)
    return (s:gsub("<[^>]->", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end

-- Quando estamos esperando o resultado de um resgate, a próxima notificação
-- normal (não "Top") do jogo é o Success/Error do CodesController.
local pendingRedeem = nil

-- Chamado pelo hook. Usa task.defer para sair da pilha do jogo antes de mexer na GUI.
genv.__SammyTopCallback = function(text, position, userId)
    if type(text) ~= "string" or text == "" then return end
    if position ~= "Top" then
        if pendingRedeem then
            local cb = pendingRedeem
            pendingRedeem = nil
            task.defer(cb, text)
        end
        return
    end
    task.defer(function()
        local clean = stripRich(text)
        print(("[Sammy Watcher] %s: %s"):format(displayName(userId), clean))
        addEntry(clean, userId)
    end)
end

local captureMode = "nenhum"

local NotificationController
pcall(function()
    -- require de módulo já carregado só devolve a tabela em cache (não roda código do jogo)
    NotificationController = require(ReplicatedStorage.Controllers.NotificationController)
end)

-- 1) Hook em NotificationController.Notify (pega tudo que vai pro topo)
if genv.__SammyNotifyHooked then
    captureMode = "hook"
elseif NotificationController and hookfunction and type(NotificationController.Notify) == "function" then
    local ok = pcall(function()
        local original
        original = hookfunction(NotificationController.Notify, function(self, text, duration, sound, position, userId, ...)
            local cb = genv.__SammyTopCallback
            if cb then pcall(cb, text, position, userId) end
            return original(self, text, duration, sound, position, userId, ...)
        end)
    end)
    if ok then
        genv.__SammyNotifyHooked = true
        captureMode = "hook"
    end
end

-- 2) Fallback: escuta passiva da remote NotificationService/Notify
--    (instância tirada do upvalue de NotificationController.Start, nada é enviado ao servidor)
if captureMode == "nenhum" and NotificationController and getupvalues then
    pcall(function()
        for _, v in pairs(getupvalues(NotificationController.Start)) do
            if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                if genv.__SammyNotifyConn then genv.__SammyNotifyConn:Disconnect() end
                genv.__SammyNotifyConn = v.OnClientEvent:Connect(function(text, duration, sound, position, userId)
                    local cb = genv.__SammyTopCallback
                    if cb then cb(text, position, userId) end
                end)
                captureMode = "remote"
                break
            end
        end
    end)
end

-- ─── RESGATE (modo seguro) ───────────────────────────────────────────────────
-- Tentativas anteriores:
--   • InvokeServer direto na RemoteFunction com nome do GUID -> falhou
--   • task.spawn no handler FocusLost do jogo (getconnections) -> KICK
-- Sem o código de Packages/Net não dá pra saber o que ele checa, então este
-- script NÃO dispara o resgate. Ele só coloca o código na TextBox do jogo
-- (PlayerGui.Codes.Codes.CodeRedeem.TextBox, CodesController.lua:87) e você
-- clica no botão Confirm do próprio jogo. Assim o fluxo é 100% o do jogo,
-- iniciado por um clique de verdade.
local function getGameCodeBox()
    local pg = LP:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild("Codes")
    local codes = gui and gui:FindFirstChild("Codes")
    local redeemFrame = codes and codes:FindFirstChild("CodeRedeem")
    return redeemFrame and redeemFrame:FindFirstChild("TextBox"), codes
end

-- Mostra o resultado quando o jogo notificar (Success = #92FF67, Error = #FA0103)
local function watchResult()
    if captureMode ~= "hook" then return end
    local got = false
    pendingRedeem = function(text)
        got = true
        local ok = text:upper():find("92FF67", 1, true) ~= nil
        if ok then
            setStatus("✔ " .. stripRich(text), 60, 200, 100, 6)
        else
            setStatus("✕ " .. stripRich(text), 220, 60, 60, 6)
        end
    end
    task.delay(60, function()
        if not got then pendingRedeem = nil end
    end)
end

local function redeem()
    -- mesmo filtro do jogo: só letras/números, até 50 caracteres
    local code = tb.Text:gsub("[^%w]", ""):sub(1, 50)
    if #code < 1 then
        setStatus("⚠ Código inválido!", 220, 80, 80, 3)
        return
    end

    local box, codesFrame = getGameCodeBox()
    if not box then
        setStatus("✕ Menu Codes do jogo não encontrado.", 220, 60, 60, 5)
        return
    end
    if not box.Active then
        setStatus("⚠ O jogo ainda está processando outro código.", 220, 160, 60, 4)
        return
    end

    box.Text = code
    if setclipboard then pcall(setclipboard, code) end
    watchResult()

    local open = codesFrame and codesFrame.Visible
    setStatus(open and "Código colocado. Clique em Confirm no menu Codes."
        or "Código colocado. Abra o menu Codes e clique em Confirm.", 230, 200, 80, 10)
end

redeemBtn.Text = "COLOCAR NO MENU CODES"
redeemBtn.MouseButton1Click:Connect(redeem)
tb.FocusLost:Connect(function(enter)
    if enter then redeem() end
end)

closeBtn.MouseButton1Click:Connect(function()
    -- o hook continua instalado, mas sem GUI ele não faz nada
    genv.__SammyTopCallback = nil
    sg:Destroy()
end)

-- ─── STATUS INICIAL ───────────────────────────────────────────────────────────
local captureText = captureMode == "hook" and "hook ativo"
    or captureMode == "remote" and "escutando remote"
    or "captura indisponível"
local boxOk = getGameCodeBox() ~= nil
setStatus(("Topo: %s · Menu Codes: %s"):format(captureText, boxOk and "ok" or "não achado"),
    (captureMode ~= "nenhum" and boxOk) and 60 or 220,
    (captureMode ~= "nenhum" and boxOk) and 200 or 120,
    (captureMode ~= "nenhum" and boxOk) and 100 or 60,
    6)
