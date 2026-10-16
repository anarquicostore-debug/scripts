--[[
	Steal a Brainrot - Sammy Top Messages + Code Redeemer (via remote)

	Baseado no dump:
	  • Controllers/CodesController.lua:37
	      Net:RemoteFunction("d193b9bf-8b44-42af-b4b2-9c77847ce1e9"):InvokeServer(code)
	      -> retorna (sucesso, mensagem). Código filtrado para [%w], máx. 50 chars.
	  • Controllers/NotificationController.lua:18
	      Net:RemoteEvent("NotificationService/Notify") -> mensagens "Top" (admins)
	  • TextChatController.lua:29 / HudController.lua:497: UserId 2678001507 = Sammy

	Por que a versão antiga falhava:
	  O nome passado para Net:RemoteFunction(...) NÃO é o nome da instância.
	  O módulo ReplicatedStorage.Packages.Net resolve esse nome para a remote real,
	  então procurar uma RemoteFunction chamada "d193b9bf-..." nunca achava nada.
	  Aqui usamos o próprio módulo Net do jogo (require devolve a tabela já
	  carregada pelo ClientLoader), exatamente como o CodesController faz.

	Aquecimento: ao carregar, resgata "67" uma vez para inicializar a remote
	(o resultado normalmente é "código inválido", isso é esperado).

	Uso por outro script: getgenv().SammyRedeem("CODIGO")
]]

-- ─── SERVICES ─────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LP = Players.LocalPlayer
local genv = getgenv and getgenv() or _G

local SAMMY_ID    = 2678001507
local REDEEM_GUID = "d193b9bf-8b44-42af-b4b2-9c77847ce1e9"
local WARMUP_CODE = "67"
local MAX_LOG     = 60
local REDEEM_GAP  = 1.2 -- segundos entre resgates (o jogo usa 0.5s de cooldown)

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
frame.Size             = UDim2.new(0, 360, 0, 450)
frame.Position         = UDim2.new(0.5, -180, 0.5, -225)
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
logTitle.Position               = UDim2.new(0, 12, 0, 214)
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
filterBtn.Position         = UDim2.new(1, -102, 0, 214)
filterBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
filterBtn.Text             = "Todos admins"
filterBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
filterBtn.Font             = Enum.Font.Gotham
filterBtn.TextSize         = 10
filterBtn.BorderSizePixel  = 0
filterBtn.Parent           = frame
corner(filterBtn, 4)

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size                 = UDim2.new(1, -24, 1, -246)
logFrame.Position             = UDim2.new(0, 12, 0, 236)
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

-- Chamado pelo hook. Usa task.defer para sair da pilha do jogo antes de mexer na GUI.
genv.__SammyTopCallback = function(text, position, userId)
    if type(text) ~= "string" or text == "" or position ~= "Top" then return end
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

-- ─── RESGATE VIA REMOTE ───────────────────────────────────────────────────────
-- Pega a RemoteFunction do mesmo jeito que o CodesController:
--   require(ReplicatedStorage.Packages.Net):RemoteFunction(GUID)
-- O require não executa nada de novo: o ClientLoader já carregou o Net, então
-- só volta a tabela em cache.
local redeemRemote = nil
local remoteError  = nil

local function getRedeemRemote()
    if redeemRemote and redeemRemote.Parent then return redeemRemote end
    local ok, res = pcall(function()
        local Net = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"))
        return Net:RemoteFunction(REDEEM_GUID)
    end)
    if ok and typeof(res) == "Instance" and res:IsA("RemoteFunction") then
        redeemRemote, remoteError = res, nil
    else
        redeemRemote, remoteError = nil, tostring(res)
    end
    return redeemRemote
end

local function cleanCode(code)
    return (tostring(code or ""):gsub("[^%w]", ""):sub(1, 50))
end

-- Fila: um resgate por vez, com intervalo, igual ao fluxo do jogo.
local queue, queued, busy = {}, {}, false
local tried = {} -- códigos já resgatados nesta sessão (evita repetir)

local function invokeRedeem(code)
    local rf = getRedeemRemote()
    if not rf then
        return false, "Remote não encontrada: " .. tostring(remoteError)
    end
    local ok, success, msg = pcall(rf.InvokeServer, rf, code)
    if not ok then
        return false, "Erro: " .. tostring(success)
    end
    if success then
        return true, typeof(msg) == "string" and msg or "Code redeemed!"
    end
    return false, typeof(msg) == "string" and msg or "Request failed"
end

local function processQueue()
    if busy then return end
    busy = true
    task.spawn(function()
        while #queue > 0 do
            local item = table.remove(queue, 1)
            queued[item.code] = nil
            if not item.silent then
                setStatus("⏳ Resgatando " .. item.code .. "...", 230, 200, 80)
            end
            local ok, msg = invokeRedeem(item.code)
            tried[item.code] = true
            msg = stripRich(msg)
            print(("[SammyCodes] %s -> %s (%s)"):format(item.code, ok and "OK" or "FALHOU", msg))
            if item.silent then
                -- aquecimento: só confirma que a remote respondeu
                if msg:find("^Remote não encontrada") or msg:find("^Erro:") then
                    setStatus("✕ Aquecimento falhou: " .. msg, 220, 60, 60, 8)
                else
                    setStatus("✔ Remote pronta (aquecimento \"" .. item.code .. "\" ok)", 60, 200, 100, 5)
                end
            elseif ok then
                setStatus("✔ " .. item.code .. ": " .. msg, 60, 200, 100, 8)
                addEntry("✔ Código " .. item.code .. " resgatado: " .. msg, nil)
            else
                setStatus("✕ " .. item.code .. ": " .. msg, 220, 60, 60, 8)
            end
            task.wait(REDEEM_GAP)
        end
        busy = false
    end)
end

local function enqueue(code, opts)
    opts = opts or {}
    code = cleanCode(code)
    if #code < 1 then
        if not opts.silent then setStatus("⚠ Código inválido!", 220, 80, 80, 3) end
        return
    end
    if queued[code] then return end
    if tried[code] and opts.auto then return end
    queued[code] = true
    table.insert(queue, { code = code, silent = opts.silent })
    processQueue()
end

-- ─── AUTO-RESGATE DAS MENSAGENS DO SAMMY ─────────────────────────────────────
-- Quando o Sammy (ou admin, conforme o filtro) manda algo com "code" no topo,
-- tenta os tokens que parecem código: depois de "code"/"código"/":" e palavras
-- em MAIÚSCULAS/números.
local autoRedeem = true
local IGNORE = { CODE = true, CODES = true, CODIGO = true, NEW = true, THE = true,
    AND = true, FOR = true, USE = true, NOW = true, FREE = true, REDEEM = true }

local function extractCodes(text)
    local lower = text:lower()
    if not (lower:find("code") or lower:find("código") or lower:find("codigo")) then
        return {}
    end
    local found, seen = {}, {}
    local function push(c)
        c = cleanCode(c)
        if #c >= 2 and not IGNORE[c:upper()] and not seen[c] then
            seen[c] = true
            table.insert(found, c)
        end
    end
    -- "code: ABC", "code ABC", "código: ABC"
    for c in text:gmatch("[Cc][Oo][Dd][EeIi][Gg]?[Oo]?[Ss]?%s*[:=%-]?%s*\"?([%w]+)") do push(c) end
    -- entre aspas
    for c in text:gmatch("\"([%w]+)\"") do push(c) end
    -- palavras todas em maiúsculas/dígitos
    for w in text:gmatch("[%w]+") do
        if #w >= 3 and w == w:upper() and w:find("%w") then push(w) end
    end
    return found
end

local prevCallback = genv.__SammyTopCallback
genv.__SammyTopCallback = function(text, position, userId)
    prevCallback(text, position, userId)
    if not autoRedeem or position ~= "Top" or type(text) ~= "string" then return end
    if onlySammy and userId ~= SAMMY_ID then return end
    if userId == nil then return end -- só mensagens com autor (admin)
    task.defer(function()
        for _, c in ipairs(extractCodes(stripRich(text))) do
            enqueue(c, { auto = true })
        end
    end)
end

-- Botão de liga/desliga do auto-resgate
local autoBtn = Instance.new("TextButton")
autoBtn.Size             = UDim2.new(1, -24, 0, 22)
autoBtn.Position         = UDim2.new(0, 12, 0, 182)
autoBtn.BorderSizePixel  = 0
autoBtn.Font             = Enum.Font.GothamBold
autoBtn.TextSize         = 11
autoBtn.Parent           = frame
corner(autoBtn, 4)

local function refreshAutoBtn()
    autoBtn.Text = autoRedeem and "AUTO-RESGATE (mensagens do topo): ON" or "AUTO-RESGATE (mensagens do topo): OFF"
    autoBtn.BackgroundColor3 = autoRedeem and Color3.fromRGB(25, 70, 35) or Color3.fromRGB(40, 40, 40)
    autoBtn.TextColor3 = autoRedeem and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(170, 170, 170)
end
refreshAutoBtn()
autoBtn.MouseButton1Click:Connect(function()
    autoRedeem = not autoRedeem
    refreshAutoBtn()
end)

-- ─── BOTÃO / ENTER ───────────────────────────────────────────────────────────
local function redeemFromBox()
    local code = cleanCode(tb.Text)
    tried[code] = nil -- resgate manual sempre tenta de novo
    enqueue(code)
end

redeemBtn.Text = "RESGATAR"
redeemBtn.MouseButton1Click:Connect(redeemFromBox)
tb.FocusLost:Connect(function(enter)
    if enter then redeemFromBox() end
end)

-- API para usar de outro script: getgenv().SammyRedeem("CODIGO")
genv.SammyRedeem = function(code) enqueue(code) end

closeBtn.MouseButton1Click:Connect(function()
    -- o hook continua instalado, mas sem GUI ele não faz nada
    genv.__SammyTopCallback = nil
    genv.SammyRedeem = nil
    autoRedeem = false
    sg:Destroy()
end)

-- ─── STATUS INICIAL + AQUECIMENTO ────────────────────────────────────────────
local captureText = captureMode == "hook" and "hook ativo"
    or captureMode == "remote" and "escutando remote"
    or "captura indisponível"

task.spawn(function()
    -- espera o jogo terminar de carregar (CodesController precisa do PlayerGui.Codes)
    if not game:IsLoaded() then game.Loaded:Wait() end
    local pg = LP:WaitForChild("PlayerGui")
    pg:WaitForChild("Codes", 30)

    local rf = getRedeemRemote()
    setStatus(("Topo: %s · Remote: %s"):format(captureText, rf and "ok" or "não achada"),
        rf and 60 or 220, rf and 200 or 120, rf and 100 or 60, 4)
    if not rf then
        warn("[SammyCodes] Net:RemoteFunction falhou: " .. tostring(remoteError))
        return
    end

    task.wait(2)
    enqueue(WARMUP_CODE, { silent = true })
end)
