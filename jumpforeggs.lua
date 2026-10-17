-- ─── LURAPH (proteção) ────────────────────────────────────────────────────────
-- Macros do Luraph. Enquanto o script NÃO passou pelo obfuscator (LPH_OBFUSCATED
-- é falso), estas versões são no-op: LPH_ENCFUNC devolve a própria função,
-- LPH_ENCSTR/LPH_ENCNUM devolvem o valor e LPH_ATTRIBUTES não faz nada. Assim dá
-- pra rodar e testar o script normalmente. Depois de passar pelo Luraph, elas
-- viram a ofuscação/encriptação de verdade.
if not LPH_OBFUSCATED then
    LPH_ENCFUNC = function(fn, obfKey, runtimeKey)
        return fn
    end
    LPH_ENCSTR = function(str, key, runtimeKey)
        return str
    end
    LPH_ENCNUM = function(num, keys)
        return num
    end
    LPH_ATTRIBUTES = function(...) end
    LPH_PRECHECK = function(fn, expected) end
    -- VM/PRESET aparecem dentro de LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE)); fora
    -- do Luraph precisam existir pra chamada não dar "attempt to call a nil value".
    VM = function(...) end
    PRESET = function(...) end
end

-- Chave usada no LPH_ENCFUNC das partes sensíveis (remotes, fly/3D, etc.).
local LPH_KEY = "a3f9c1e7b2d84f6091cde35a7b8012f4e9d6c3a1f8057b2e4d9a6c3f1082e5b"

-- get_key(): anti-tamper. Se o chunk do script foi alterado (nome diferente de
-- "script"), devolve uma chave falsa e as funções protegidas não descriptografam.
-- Fora do Luraph o retorno é ignorado (LPH_ENCFUNC só devolve a função).
local function get_key()
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))

    if debug.info(1, "s") ~= "[string \"script\"]" then
        local chars = "0123456789abcdef"
        local fake = ""
        for i = 1, 64 do
            fake = fake .. chars:sub(math.random(1, #chars), math.random(1, #chars))
        end
        return fake
    end

    return LPH_ENCSTR("a3f9c1e7b2d84f6091cde35a7b8012f4e9d6c3a1f8057b2e4d9a6c3f1082e5b", 123)
end

-- Jump for Eggs (Steal a Brainrot) — só remotes
-- Fonte: ReplicatedStorage.Controllers.JumpLTMController (dump)
--   :32  RequestEggPlace         v_u_32:FireServer()            (linha 1021)
--   :33  RequestBrainrotPlace    v_u_33:FireServer()            (linha 1070)
--   :34  RequestTrampolineUpgrade v_u_34:FireServer(plotOrder)  (linha 1188)

-- ─── SERVICES ─────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local LP = Players.LocalPlayer

-- ─── REGISTRO DE KICK ─────────────────────────────────────────────────────────
-- Só observa: guarda as últimas linhas de log e, se o jogo/servidor desconectar
-- você, salva o motivo + o que o script fez antes em v3nt_kick_log.txt.
local recentLog = {}
local function remember(line)
    table.insert(recentLog, os.date("%H:%M:%S") .. " " .. line)
    if #recentLog > 60 then table.remove(recentLog, 1) end
end
pcall(function()
    game:GetService("GuiService").ErrorMessageChanged:Connect(function(msg)
        if type(msg) ~= "string" or msg == "" then return end
        local report = "MOTIVO: " .. msg .. "\n\nÚLTIMAS AÇÕES:\n" .. table.concat(recentLog, "\n")
        warn("[KICK] " .. msg)
        pcall(function() writefile("v3nt_kick_log.txt", report) end)
        pcall(function() setclipboard(report) end)
    end)
end)

local function log(...)
    print("[JumpForEggs]", ...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    remember(table.concat(parts, " "))
end

-- Envolve callbacks: um erro nunca derruba o script nem trava o player.
local function safe(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then log("erro em " .. label .. ":", err) end
    end
end

-- ─── RESOLVER DE REMOTES ──────────────────────────────────────────────────────
local getupvals = (debug and debug.getupvalues) or getupvalues
local getinfo   = debug and debug.getinfo

local function fnName(fn)
    if not getinfo then return nil end
    local ok, info = pcall(getinfo, fn)
    return ok and type(info) == "table" and info.name or nil
end

local function upvalues(fn)
    if not getupvals or type(fn) ~= "function" then return nil end
    local ok, ups = pcall(getupvals, fn)
    return ok and type(ups) == "table" and ups or nil
end

-- Única instância da classe entre os upvalues de fn.
local onlyRemote = LPH_ENCFUNC(function(fn, class)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local ups = upvalues(fn)
    if not ups then return nil end
    local found
    for _, v in pairs(ups) do
        if typeof(v) == "Instance" and v:IsA(class) then
            if found and found ~= v then return nil end
            found = v
        end
    end
    return found
end, LPH_KEY, get_key())

-- Nome exato dentro das pastas do Net (só GetChildren).
local remoteByName = LPH_ENCFUNC(function(path, class)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local folders = {}
    local pk = ReplicatedStorage:FindFirstChild("Packages")
    if pk then
        if pk:FindFirstChild("Net") then table.insert(folders, pk.Net) end
        local idx = pk:FindFirstChild("_Index")
        if idx then
            for _, c in ipairs(idx:GetChildren()) do
                if c.Name:lower():sub(1, 13) == "sleitnick_net" and c:FindFirstChild("net") then
                    table.insert(folders, c.net)
                end
            end
        end
    end
    for _, folder in ipairs(folders) do
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA(class) and (c.Name == path or c.Name:sub(-(#path + 1)) == "/" .. path) then
                return c
            end
        end
    end
    return nil
end, LPH_KEY, get_key())

-- Funções locais do controller, achadas pelo nome de debug a partir dos
-- upvalues de JumpLTMController.Start (linha 1219). Índice do dump como reserva.
local START_INDEX = {
    setupEggPlaceInput     = 9,
    setupPlaceButton       = 10,
    setupTrampolineSignGui = 11,
}
local inner = {}
local JLC -- tabela do JumpLTMController (também guarda RenderedEggs)
do
    local ok, mod = pcall(function()
        local f = ReplicatedStorage:FindFirstChild("Controllers")
        local m = f and f:FindFirstChild("JumpLTMController")
        return m and require(m)
    end)
    if ok and type(mod) == "table" then JLC = mod end
    local ups = JLC and upvalues(JLC.Start)
    log("JumpLTMController:", ups and "ok" or ("falhou " .. tostring(mod)))
    if ups then
        for _, v in pairs(ups) do
            local n = type(v) == "function" and fnName(v)
            if n and START_INDEX[n] then inner[n] = v end
        end
        for n, i in pairs(START_INDEX) do
            if not inner[n] and type(ups[i]) == "function" then inner[n] = ups[i] end
        end
    end
end

local resolve = LPH_ENCFUNC(function(label, fromFn, path, pick)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local r, how
    if fromFn then
        r = pick and pick(fromFn) or onlyRemote(fromFn, "RemoteEvent")
        how = r and "upvalue"
    end
    if not r then r = remoteByName(path, "RemoteEvent"); how = r and "nome exato" end
    log(label, r and ("ok via " .. how .. " -> " .. r:GetFullName()) or "NÃO encontrada")
    return r
end, LPH_KEY, get_key())

local eggRemote     = resolve("RequestEggPlace", inner.setupEggPlaceInput, "JumpLTMService/RequestEggPlace")
local brainRemote   = resolve("RequestBrainrotPlace", inner.setupPlaceButton, "JumpLTMService/RequestBrainrotPlace")
-- RequestTrampolineUpgrade:FireServer(plotOrder)  (JumpLTMController:1188)
local upgradeRemote = resolve("RequestTrampolineUpgrade", inner.setupTrampolineSignGui, "JumpLTMService/RequestTrampolineUpgrade")

-- Grab de ovo do mapa: WorldBrainrotController.lua:18
--   v_u_14 = Net:RemoteEvent("WorldBrainrotService/Grab")
--   v_u_14:FireServer(PoolId, id)   (prompt "Grab", linha 199; PoolId "JumpLTM/Eggs")
local grabRemote
do
    local ok, WBC = pcall(function()
        local f = ReplicatedStorage:FindFirstChild("Controllers")
        local m = f and f:FindFirstChild("WorldBrainrotController")
        return m and require(m)
    end)
    grabRemote = resolve("Grab", ok and type(WBC) == "table" and WBC.RenderPool or nil, "WorldBrainrotService/Grab")
end

-- ─── HELPERS DO JOGO (cópias das checagens do controller) ─────────────────────
local function getChar()
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hrp and hum and hum.Health > 0 then return c, hrp, hum end
end

local function getOwnPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, p in ipairs(plots:GetChildren()) do
        if p:IsA("Model") and p:GetAttribute("OwnerUserId") == LP.UserId then return p end
    end
end

-- isStandingOnOwnPlot (linha 1030)
local function onOwnPlot()
    local _, hrp = getChar()
    local plot = getOwnPlot()
    local floor = plot and plot:FindFirstChild("Floor")
    if not (hrp and floor and floor:IsA("BasePart")) then return false end
    local p = floor.CFrame:PointToObjectSpace(hrp.Position)
    return math.abs(p.X) <= floor.Size.X / 2 and math.abs(p.Z) <= floor.Size.Z / 2
end

-- ─── GUI ROOT (protegida) ────────────────────────────────────────────────────
-- A GUI vai pro container escondido do executor (gethui), com protect_gui quando
-- existir e nome aleatório. Os scripts do jogo não enxergam esse container.
local function guiRoot()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and typeof(h) == "Instance" then return h end
    local cg = game:GetService("CoreGui")
    local ok2, ref = pcall(function() return cloneref and cloneref(cg) end)
    return (ok2 and typeof(ref) == "Instance") and ref or cg
end

local function newProtectedGui(tag)
    -- fecha a GUI de uma execução anterior deste script
    pcall(function()
        local env = getgenv and getgenv() or _G
        if env[tag] and typeof(env[tag]) == "Instance" then env[tag]:Destroy() end
    end)
    local g = Instance.new("ScreenGui")
    g.Name = game:GetService("HttpService"):GenerateGUID(false):gsub("-", "")
    g.ResetOnSpawn = false
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    g.IgnoreGuiInset = false
    -- Sem tradução automática do Roblox: senão ele traduz nossos textos pro idioma
    -- da conta (ex.: "On" virava "Ligado", "Done" virava "Feito") e o seletor de
    -- idioma do script não funcionava direito.
    pcall(function() g.AutoLocalize = false end)
    g.DescendantAdded:Connect(function(d)
        if d:IsA("GuiBase2d") then pcall(function() d.AutoLocalize = false end) end
    end)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(g)
        elseif protect_gui then protect_gui(g)
        elseif protectgui then protectgui(g) end
    end)
    g.Parent = guiRoot()
    pcall(function()
        local env = getgenv and getgenv() or _G
        env[tag] = g
    end)
    return g
end

local sg = newProtectedGui("V3ntJumpForEggGui")
local alive = true
local conns = {}
local toggles = { esp = false, hub = false, egg = false, brainrot = false, upgrade = false }

-- ─── CONFIG (salva na pasta workspace do executor) ───────────────────────────
-- Arquivo: workspace/V3nt/JumpForEgg.json
--   { "flySpeed": 60, "filter": { "enabled": false, "eggs": [...], "rarities": [...], "mutations": [...] } }
local HttpService = game:GetService("HttpService")
local CONFIG_DIR, CONFIG_FILE = "V3nt", "V3nt/JumpForEgg.json"
local config = { flySpeed = 60, lang = "pt" }
-- filtro de ovos (conjuntos: nome → true). Categoria vazia = não filtra por ela.
local filter = { enabled = false, eggs = {}, rarities = {}, mutations = {} }

local function toSet(list)
    local s = {}
    if type(list) == "table" then
        for _, v in ipairs(list) do if type(v) == "string" then s[v] = true end end
    end
    return s
end
local function toList(set)
    local l = {}
    for k, v in pairs(set) do if v then table.insert(l, k) end end
    table.sort(l)
    return l
end

local function loadConfig()
    local ok, data = pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)
    if ok and type(data) == "table" then
        if type(data.flySpeed) == "number" then config.flySpeed = math.clamp(data.flySpeed, 10, 999) end
        if data.lang == "pt" or data.lang == "en" or data.lang == "es" then config.lang = data.lang end
        if type(data.filter) == "table" then
            filter.enabled = data.filter.enabled == true
            filter.eggs = toSet(data.filter.eggs)
            filter.rarities = toSet(data.filter.rarities)
            filter.mutations = toSet(data.filter.mutations)
        end
        log("config carregada:", CONFIG_FILE, "flySpeed =", config.flySpeed)
    end
end

local function saveConfig()
    local ok, err = pcall(function()
        if makefolder and isfolder and not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
        writefile(CONFIG_FILE, HttpService:JSONEncode({
            flySpeed = config.flySpeed,
            lang = config.lang,
            filter = {
                enabled = filter.enabled,
                eggs = toList(filter.eggs),
                rarities = toList(filter.rarities),
                mutations = toList(filter.mutations),
            },
        }))
    end)
    if not ok then log("não salvou a config:", err) end
    return ok
end

loadConfig()

-- ─── IDIOMA ──────────────────────────────────────────────────────────────────
-- T("texto em português", ...) devolve o texto no idioma escolhido (tabela I18N)
-- e aplica string.format quando tem argumentos. Sem tradução = fica em português.
local I18N = {} -- preenchida mais abaixo (seção TRADUÇÕES)
local function T(s, ...)
    local e = I18N[s]
    local out = (config.lang ~= "pt" and e and e[config.lang]) or s
    if select("#", ...) > 0 then
        local ok, r = pcall(string.format, out, ...)
        if ok then return r end
        local ok2, r2 = pcall(string.format, s, ...)
        return ok2 and r2 or out
    end
    return out
end

-- ─── STATUS ──────────────────────────────────────────────────────────────────
local statusHook -- a janela principal liga isso no texto de status
local function setStatus(msg)
    if statusHook then pcall(statusHook, msg) end
end

-- ─── NOTIFICAÇÕES (topo da tela, somem sozinhas) ─────────────────────────────
local notifHolder = Instance.new("Frame")
notifHolder.Name = "Notifs"
notifHolder.AnchorPoint = Vector2.new(0.5, 0)
notifHolder.Position = UDim2.new(0.5, 0, 0, 14)
notifHolder.Size = UDim2.new(0, 380, 0, 0)
notifHolder.AutomaticSize = Enum.AutomaticSize.Y
notifHolder.BackgroundTransparency = 1
notifHolder.ZIndex = 50
notifHolder.Parent = sg
do
    local l = Instance.new("UIListLayout", notifHolder)
    l.Padding = UDim.new(0, 8)
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
end

local NOTIF_COLORS = {
    info = Color3.fromRGB(255, 59, 92),
    ok   = Color3.fromRGB(60, 210, 120),
    warn = Color3.fromRGB(240, 170, 60),
    err  = Color3.fromRGB(240, 70, 80),
}

local notify
-- Problema com explicação e solução:
--   notifyProblem("Seu plot está cheio", "Choque ou venda um ovo e tente de novo.")
local function notifyProblem(title, solution, kind, seconds)
    local msg = "<b>" .. title .. "</b>"
    if solution then msg = msg .. '\n<font color="#A8A8BC">' .. T("Solução: ") .. solution .. "</font>" end
    notify(msg, kind or "err", seconds or 10)
end

function notify(msg, kind, seconds)
    log("[notif]", msg)
    pcall(function()
        local color = typeof(kind) == "Color3" and kind or NOTIF_COLORS[kind or "info"] or NOTIF_COLORS.info
        local box = Instance.new("Frame")
        box.Size = UDim2.new(1, 0, 0, 0)
        box.AutomaticSize = Enum.AutomaticSize.Y
        box.BackgroundColor3 = Color3.fromRGB(20, 20, 27)
        box.BorderSizePixel = 0
        box.ZIndex = 50
        box.Parent = notifHolder
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
        local st = Instance.new("UIStroke", box)
        st.Color, st.Thickness, st.Transparency = color, 1.5, 0.2
        local pad = Instance.new("UIPadding", box)
        pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
        pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 12)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 4, 1, 0)
        bar.Position = UDim2.new(0, -10, 0, 0)
        bar.BackgroundColor3 = color
        bar.BorderSizePixel = 0
        bar.ZIndex = 51
        bar.Parent = box
        Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 0, 0)
        t.AutomaticSize = Enum.AutomaticSize.Y
        t.BackgroundTransparency = 1
        t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
        t.TextSize = 13
        t.TextWrapped = true
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextColor3 = Color3.fromRGB(235, 235, 245)
        t.RichText = true
        t.Text = msg
        t.ZIndex = 51
        t.Parent = box
        task.delay(seconds or 10, function()
            pcall(function()
                local ti = TweenInfo.new(0.35)
                TweenService:Create(box, ti, { BackgroundTransparency = 1 }):Play()
                TweenService:Create(t, ti, { TextTransparency = 1 }):Play()
                TweenService:Create(st, ti, { Transparency = 1 }):Play()
                TweenService:Create(bar, ti, { BackgroundTransparency = 1 }):Play()
                task.wait(0.4)
                box:Destroy()
            end)
        end)
    end)
end

-- ─── TRADUÇÕES (en / es) ─────────────────────────────────────────────────────
-- Chave = texto em português usado no script. Faltou alguma? Fica em português.
local function tr(pt, en, es) I18N[pt] = { en = en, es = es } end
-- geral
tr("Solução: ", "Fix: ", "Solución: ")
tr("Executar", "Run", "Ejecutar")
tr("PRONTO!", "READY!", "¡LISTO!")
tr("Ovo", "Egg", "Huevo")
tr("Ovos", "Eggs", "Huevos")
tr("Visual", "Visuals", "Visual")
tr("Fly", "Fly", "Vuelo")
tr("Base", "Base", "Base")
tr("Manual", "Manual", "Manual")
tr("Status", "Status", "Estado")
tr("Geral", "General", "General")
tr("Pronto.", "Ready.", "Listo.")
tr("Pronto", "Done", "Listo")
tr("Fechar", "Close", "Cerrar")
tr("Abrir", "Open", "Abrir")
tr("Parar", "Stop", "Detener")
tr("Ativo", "On", "Activo")
tr("Ligado", "On", "Activado")
tr("Desligado", "Off", "Desactivado")
tr("carregando...", "loading...", "cargando...")
tr("A janela principal deu erro (veja F9).", "The main window failed (check F9).", "La ventana principal falló (mira F9).")
-- idioma
tr("Idioma", "Language", "Idioma")
tr("Idioma atual", "Current language", "Idioma actual")
tr("Toque pra usar este idioma", "Tap to use this language", "Toca para usar este idioma")
tr("Em uso", "In use", "En uso")
tr("Usar", "Use", "Usar")
tr("Idioma alterado: %s", "Language changed: %s", "Idioma cambiado: %s")
-- detalhes do ovo
tr("Raridade:", "Rarity:", "Rareza:")
tr("Mutação:", "Mutation:", "Mutación:")
tr("nenhuma", "none", "ninguna")
tr("nenhum", "none", "ninguno")
tr("Traits (%d): %s", "Traits (%d): %s", "Rasgos (%d): %s")
tr("Contém:", "Contains:", "Contiene:")
tr("Contém: ", "Contains: ", "Contiene: ")
tr("Tempo de chocar:", "Hatch time:", "Tiempo de eclosión:")
tr("Choca em:", "Hatches in:", "Eclosiona en:")
tr("Some em:", "Despawns in:", "Desaparece en:")
tr("Some em ", "Despawns in ", "Desaparece en ")
tr("Plot de:", "Plot of:", "Parcela de:")
tr("Plot de ", "Plot of ", "Parcela de ")
tr("No mapa", "On the map", "En el mapa")
tr("No mapa · livre", "On the map · free", "En el mapa · libre")
tr("Pego por alguém", "Taken by someone", "Tomado por alguien")
tr("PEGO", "TAKEN", "TOMADO")
tr("livre", "free", "libre")
tr("Distância: %.0f studs", "Distance: %.0f studs", "Distancia: %.0f studs")
tr("Posição:", "Position:", "Posición:")
tr("Index:", "Index:", "Índice:")
tr("Sem traits", "No traits", "Sin rasgos")
-- hub
tr("Ovos no servidor", "Eggs in the server", "Huevos en el servidor")
tr("Nenhum ovo no servidor agora.", "No eggs in the server right now.", "No hay huevos en el servidor ahora.")
tr("Nenhum ovo passa no filtro agora.", "No egg matches the filter right now.", "Ningún huevo pasa el filtro ahora.")
tr("%d ovos  ·  %d no mapa  ·  %d em plots", "%d eggs  ·  %d on the map  ·  %d on plots", "%d huevos  ·  %d en el mapa  ·  %d en parcelas")
tr("  ·  filtro: %d de %d", "  ·  filter: %d of %d", "  ·  filtro: %d de %d")
tr("Voar", "Fly", "Volar")
tr("Coletar", "Collect", "Recoger")
tr("Só no mapa", "Map only", "Solo en el mapa")
tr("Detalhes", "Details", "Detalles")
tr("Soltar", "Release", "Soltar")
-- voo / coleta
tr("Voando (%d pontos)", "Flying (%d points)", "Volando (%d puntos)")
tr("Voando até ", "Flying to ", "Volando hacia ")
tr("Não achei chão perto.", "No ground found nearby.", "No encontré suelo cerca.")
tr("Pousando na ilha mais próxima...", "Landing on the nearest island...", "Aterrizando en la isla más cercana...")
tr("Chegou em ", "Arrived at ", "Llegaste a ")
tr("Não chegou em ", "Couldn't reach ", "No llegaste a ")
tr("Não chegou no seu plot", "Couldn't reach your plot", "No llegaste a tu parcela")
tr("Parado no ar ao lado do ovo. \"Soltar\" leva você pro chão.", "Hovering next to the egg. \"Release\" takes you to the ground.", "Quieto en el aire junto al huevo. \"Soltar\" te lleva al suelo.")
tr("Pegando ", "Grabbing ", "Agarrando ")
tr("Levando ", "Taking ", "Llevando ")
tr(" pro seu plot...", " to your plot...", " a tu parcela...")
tr("Colocando ", "Placing ", "Colocando ")
tr(" colocado no seu plot!", " placed on your plot!", " colocado en tu parcela!")
tr(" foi colocado no seu plot!", " was placed on your plot!", " fue colocado en tu parcela!")
tr("Ovo colocado.", "Egg placed.", "Huevo colocado.")
tr("Ovo colocado no seu plot!", "Egg placed on your plot!", "¡Huevo colocado en tu parcela!")
tr("Brainrot colocado.", "Brainrot placed.", "Brainrot colocado.")
tr("Não deu pra colocar o ovo.", "Couldn't place the egg.", "No se pudo colocar el huevo.")
tr(" não está mais disponível", " is no longer available", " ya no está disponible")
tr(" sumiu enquanto você ia até ele", " vanished while you were flying to it", " desapareció mientras ibas hacia él")
tr(" sumiu antes de você pegar", " vanished before you could grab it", " desapareció antes de que lo agarraras")
tr("O servidor não deixou pegar ", "The server didn't let you grab ", "El servidor no te dejó agarrar ")
-- problemas + soluções
tr("Você não está carregando nenhum ovo", "You are not carrying any egg", "No estás cargando ningún huevo")
tr("Pegue um ovo (botão Coletar no hub) e tente de novo.", "Grab an egg (Collect button in the hub) and try again.", "Agarra un huevo (botón Recoger en el hub) y vuelve a intentarlo.")
tr("Não dá pra colocar ovos agora", "Can't place eggs right now", "No se pueden colocar huevos ahora")
tr("O jogo pode ter atualizado (remote não encontrada). Reinicie o script.", "The game may have updated (remote not found). Restart the script.", "El juego pudo haberse actualizado (remote no encontrado). Reinicia el script.")
tr("Não achei o chão do seu plot embaixo de você", "Couldn't find your plot floor under you", "No encontré el suelo de tu parcela debajo de ti")
tr("O ovo continua na sua mão. Fique em cima do chão do seu plot e use \"Colocar ovo agora\" (aba Base).", "The egg is still in your hand. Stand on your plot floor and use \"Place egg now\" (Base tab).", "El huevo sigue en tu mano. Párate sobre el suelo de tu parcela y usa \"Colocar huevo ahora\" (pestaña Base).")
tr("Seu plot está cheio (%d/%d), não deu pra colocar o ovo", "Your plot is full (%d/%d), the egg couldn't be placed", "Tu parcela está llena (%d/%d), no se pudo colocar el huevo")
tr("O ovo continua na sua mão. Choque, venda ou pegue um ovo/pet do plot e use \"Colocar ovo agora\" (aba Base).", "The egg is still in your hand. Hatch, sell or pick up an egg/pet from the plot and use \"Place egg now\" (Base tab).", "El huevo sigue en tu mano. Eclosiona, vende o recoge un huevo/mascota de la parcela y usa \"Colocar huevo ahora\" (pestaña Base).")
tr("O servidor recusou todos os lugares tentados", "The server rejected every spot tried", "El servidor rechazó todos los lugares probados")
tr("O ovo continua na sua mão. Ande pra uma parte livre do chão do seu plot e use \"Colocar ovo agora\" (aba Base).", "The egg is still in your hand. Walk to a free part of your plot floor and use \"Place egg now\" (Base tab).", "El huevo sigue en tu mano. Camina a una parte libre del suelo de tu parcela y usa \"Colocar huevo ahora\" (pestaña Base).")
tr("Alguém pegou ou ele expirou. Escolha outro ovo no hub.", "Someone took it or it expired. Pick another egg in the hub.", "Alguien lo tomó o expiró. Elige otro huevo en el hub.")
tr("Você ainda não tem plot neste servidor", "You don't have a plot in this server yet", "Todavía no tienes parcela en este servidor")
tr("Pegue um plot primeiro e tente de novo.", "Claim a plot first and try again.", "Consigue una parcela primero y vuelve a intentarlo.")
tr("Seu plot está cheio (%d/%d)", "Your plot is full (%d/%d)", "Tu parcela está llena (%d/%d)")
tr("Choque, venda ou pegue um ovo/pet do plot pra liberar espaço e tente de novo.", "Hatch, sell or pick up an egg/pet from the plot to free space and try again.", "Eclosiona, vende o recoge un huevo/mascota de la parcela para liberar espacio y vuelve a intentarlo.")
tr("Levando você pra ilha mais próxima. Escolha outro ovo no hub.", "Taking you to the nearest island. Pick another egg in the hub.", "Llevándote a la isla más cercana. Elige otro huevo en el hub.")
tr("O jogo pode ter atualizado (remote Grab não encontrada). Reinicie o script.", "The game may have updated (Grab remote not found). Restart the script.", "El juego pudo haberse actualizado (remote Grab no encontrado). Reinicia el script.")
tr("Não dá pra pegar ovos agora", "Can't grab eggs right now", "No se pueden agarrar huevos ahora")
tr("Alguém pegou primeiro. Escolha outro ovo no hub.", "Someone took it first. Pick another egg in the hub.", "Alguien lo tomó primero. Elige otro huevo en el hub.")
tr("Você ficou longe demais do ovo (mais de 10 studs)", "You ended up too far from the egg (more than 10 studs)", "Quedaste demasiado lejos del huevo (más de 10 studs)")
tr("Tente de novo. Se repetir, baixe a velocidade do fly.", "Try again. If it keeps happening, lower the fly speed.", "Inténtalo de nuevo. Si se repite, baja la velocidad de vuelo.")
tr("Alguém pegou antes, ou você já carrega outro ovo. Escolha outro ovo.", "Someone took it first, or you are already carrying another egg. Pick another egg.", "Alguien lo tomó antes, o ya cargas otro huevo. Elige otro huevo.")
tr("Seu plot não foi encontrado", "Your plot was not found", "No se encontró tu parcela")
tr("O ovo continua na sua mão. Pegue um plot e coloque nele.", "The egg is still in your hand. Claim a plot and place it there.", "El huevo sigue en tu mano. Consigue una parcela y colócalo ahí.")
tr("Você não ficou em cima do seu plot", "You didn't end up on your plot", "No quedaste sobre tu parcela")
tr("O ovo continua na sua mão. Ande até o chão do plot e use \"Colocar ovo agora\" (aba Base).", "The egg is still in your hand. Walk to the plot floor and use \"Place egg now\" (Base tab).", "El huevo sigue en tu mano. Camina al suelo de la parcela y usa \"Colocar huevo ahora\" (pestaña Base).")
tr("Erro no voo/coleta", "Fly/collect error", "Error al volar/recoger")
tr("Tente de novo. Se repetir, mande o F9 (linhas [JumpForEggs]).", "Try again. If it keeps happening, send the F9 log ([JumpForEggs] lines).", "Inténtalo de nuevo. Si se repite, envía el F9 (líneas [JumpForEggs]).")
tr("O ovo sumiu no caminho", "The egg vanished on the way", "El huevo desapareció en el camino")
tr("O voo travou num obstáculo", "The flight got stuck on an obstacle", "El vuelo se trabó en un obstáculo")
tr("Tente de novo de outro lugar ou baixe a velocidade do fly.", "Try again from another spot or lower the fly speed.", "Inténtalo desde otro lugar o baja la velocidad de vuelo.")
tr("O voo demorou demais", "The flight took too long", "El vuelo tardó demasiado")
tr("Aumente a velocidade do fly ou chegue mais perto antes.", "Raise the fly speed or get closer first.", "Sube la velocidad de vuelo o acércate primero.")
tr("Erro no voo", "Flight error", "Error de vuelo")
tr("Seu personagem morreu ou resetou", "Your character died or reset", "Tu personaje murió o se reinició")
tr("Espere renascer e tente de novo.", "Wait to respawn and try again.", "Espera a reaparecer y vuelve a intentarlo.")
tr("Você não está em cima do seu plot", "You are not on your plot", "No estás sobre tu parcela")
tr("Ande até o chão do seu plot e clique de novo.", "Walk onto your plot floor and click again.", "Camina al suelo de tu parcela y haz clic de nuevo.")
-- filtro
tr("Filtro", "Filter", "Filtro")
tr("Filtro de ovos", "Egg filter", "Filtro de huevos")
tr("Filtro ativo", "Filter on", "Filtro activo")
tr("Só mostra no hub e no ESP os ovos que passam no filtro.", "Only shows eggs that match the filter in the hub and ESP.", "Solo muestra en el hub y el ESP los huevos que pasan el filtro.")
tr("Escolher ovos, raridades e mutações", "Choose eggs, rarities and mutations", "Elegir huevos, rarezas y mutaciones")
tr("Abre o painel com todos os ovos do jogo.", "Opens the panel with every egg in the game.", "Abre el panel con todos los huevos del juego.")
tr("Sem mutação", "No mutation", "Sin mutación")
tr("Limpar tudo", "Clear all", "Limpiar todo")
tr("Categoria sem nada marcado = mostra todos dela.", "A category with nothing selected = shows all of it.", "Categoría sin nada marcado = muestra todo de ella.")
tr("RARIDADES", "RARITIES", "RAREZAS")
tr("MUTAÇÕES", "MUTATIONS", "MUTACIONES")
tr("OVOS (%d)", "EGGS (%d)", "HUEVOS (%d)")
tr("%s  ·  %d ovos  ·  %d raridades  ·  %d mutações marcadas", "%s  ·  %d eggs  ·  %d rarities  ·  %d mutations selected", "%s  ·  %d huevos  ·  %d rarezas  ·  %d mutaciones marcadas")
-- janela principal
tr("ESP de ovos", "Egg ESP", "ESP de huevos")
tr("Contorno, nome, mutação, traits e timer em cada ovo.", "Outline, name, mutation, traits and timer on every egg.", "Contorno, nombre, mutación, rasgos y temporizador en cada huevo.")
tr("Hub de ovos", "Egg hub", "Hub de huevos")
tr("Lista com preview 3D, voar e coletar.", "List with 3D preview, fly and collect.", "Lista con vista 3D, volar y recoger.")
tr("Velocidade do fly", "Fly speed", "Velocidad de vuelo")
tr("De 10 a 999. Fica salva em workspace/", "From 10 to 999. Saved in workspace/", "De 10 a 999. Se guarda en workspace/")
tr("Velocidade inválida.", "Invalid speed.", "Velocidad inválida.")
tr("Velocidade %d salva.", "Speed %d saved.", "Velocidad %d guardada.")
tr("Velocidade %d (o executor não deixou salvar o arquivo).", "Speed %d (the executor couldn't save the file).", "Velocidad %d (el executor no pudo guardar el archivo).")
tr("Parar voo", "Stop flight", "Detener vuelo")
tr("Cancela e leva pro chão se estiver no ar.", "Cancels and takes you to the ground if you are in the air.", "Cancela y te lleva al suelo si estás en el aire.")
tr("Pousar", "Land", "Aterrizar")
tr("Vai pra ilha mais próxima (ou pro seu plot).", "Goes to the nearest island (or your plot).", "Va a la isla más cercana (o a tu parcela).")
tr("Automático", "Automatic", "Automático")
tr(" (remote não encontrada)", " (remote not found)", " (remote no encontrado)")
tr(": remote não encontrada no jogo.", ": remote not found in the game.", ": remote no encontrado en el juego.")
tr("Auto colocar ovo", "Auto place egg", "Auto colocar huevo")
tr("Coloca o ovo que você carrega quando estiver no seu plot.", "Places the egg you carry when you are on your plot.", "Coloca el huevo que cargas cuando estás en tu parcela.")
tr("Auto colocar brainrot", "Auto place brainrot", "Auto colocar brainrot")
tr("Coloca o brainrot que você carrega no seu plot.", "Places the brainrot you carry on your plot.", "Coloca el brainrot que cargas en tu parcela.")
tr("Auto upgrade trampolim", "Auto trampoline upgrade", "Auto mejorar trampolín")
tr("Compra o próximo tier quando a placa do jogo liberar.", "Buys the next tier when the game's sign allows it.", "Compra el siguiente nivel cuando el cartel del juego lo permita.")
tr("Colocar ovo agora", "Place egg now", "Colocar huevo ahora")
tr("Coloca o ovo que você está carregando no seu plot.", "Places the egg you are carrying on your plot.", "Coloca el huevo que estás cargando en tu parcela.")
tr("Colocar", "Place", "Colocar")
tr("Fechar script", "Close script", "Cerrar script")
tr("Para tudo e fecha as janelas.", "Stops everything and closes the windows.", "Detiene todo y cierra las ventanas.")
tr("Remotes: Ovo %s · Brainrot %s · Grab %s · Upgrade %s", "Remotes: Egg %s · Brainrot %s · Grab %s · Upgrade %s", "Remotes: Huevo %s · Brainrot %s · Grab %s · Upgrade %s")
-- trampolim
tr("Trampolim", "Trampoline", "Trampolín")
tr("Lendo o trampolim...", "Reading the trampoline...", "Leyendo el trampolín...")
tr("Trampolim: a placa só aparece no servidor do Jump for Eggs (e depois de você ter um plot).", "Trampoline: the sign only shows on the Jump for Eggs server (after you have a plot).", "Trampolín: el cartel solo aparece en el servidor de Jump for Eggs (después de tener parcela).")
tr("Trampolim: tier %s (MÁXIMO)", "Trampoline: tier %s (MAX)", "Trampolín: nivel %s (MÁXIMO)")
tr("Trampolim: tier %s de %s", "Trampoline: tier %s of %s", "Trampolín: nivel %s de %s")
tr("Próximo upgrade: ", "Next upgrade: ", "Siguiente mejora: ")
tr(" · precisa level %d%s", " · needs level %d%s", " · necesita nivel %d%s")
tr(" (bloqueado)", " (locked)", " (bloqueado)")
tr("Seu level: %d (MÁXIMO)", "Your level: %d (MAX)", "Tu nivel: %d (MÁXIMO)")
tr("Seu level: %d · %s/%s XP", "Your level: %d · %s/%s XP", "Tu nivel: %d · %s/%s XP")
tr("Força do pulo: %s", "Jump force: %s", "Fuerza del salto: %s")
tr("Auto upgrade: %s · %d upgrade(s) nesta sessão", "Auto upgrade: %s · %d upgrade(s) this session", "Auto mejora: %s · %d mejora(s) en esta sesión")
tr("ligado", "on", "activado")
tr("desligado", "off", "desactivado")
tr("Trampolim subiu pro tier %d!", "Trampoline reached tier %d!", "¡El trampolín subió al nivel %d!")
-- ═══ V3NT UI ═════════════════════════════════════════════════════════════════
-- Interface própria do script (não reutiliza nenhuma GUI/biblioteca):
-- janela escura com barra lateral de abas, linhas com título + descrição,
-- switch animado, botões, campos de texto e textos que atualizam.
-- Tudo em pixels com UIScale pra telas pequenas, dentro da GUI protegida.
local V3ntUI = {}
do
    local UIS = game:GetService("UserInputService")
    local THEME = {
        bg        = Color3.fromRGB(14, 14, 19),
        panel     = Color3.fromRGB(20, 20, 27),
        card      = Color3.fromRGB(27, 27, 36),
        cardHover = Color3.fromRGB(33, 33, 44),
        stroke    = Color3.fromRGB(45, 45, 58),
        text      = Color3.fromRGB(235, 235, 245),
        sub       = Color3.fromRGB(150, 150, 168),
        accent    = Color3.fromRGB(255, 59, 92),
        accent2   = Color3.fromRGB(176, 22, 64),
        off       = Color3.fromRGB(58, 58, 72),
    }
    V3ntUI.Theme = THEME
    local FONT      = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
    local FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
    local FONT_HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

    local function new(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do pcall(function() o[k] = v end) end
        if parent then o.Parent = parent end
        return o
    end
    local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
    local function outline(o, color, t, tr)
        return new("UIStroke", { Color = color or THEME.stroke, Thickness = t or 1, Transparency = tr or 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
    end
    local function accentGradient(o, rot)
        return new("UIGradient", { Rotation = rot or 0,
            Color = ColorSequence.new(THEME.accent, THEME.accent2) }, o)
    end
    -- Botão com fundo em degradê: o UIGradient fica num Frame de fundo e o texto
    -- num TextLabel por cima. (UIGradient direto no botão pinta o texto junto,
    -- por isso os botões vermelhos apareciam sem texto.)
    local GREEN = ColorSequence.new(Color3.fromRGB(70, 220, 120), Color3.fromRGB(24, 150, 72))
    local function fillButton(parent, label, props, colors, radius)
        local b = Instance.new("TextButton")
        b.BackgroundTransparency = 1
        b.AutoButtonColor = false
        b.Text = ""
        b.BorderSizePixel = 0
        for k, v in pairs(props or {}) do b[k] = v end
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.fromScale(1, 1)
        fill.BackgroundColor3 = Color3.new(1, 1, 1)
        fill.BorderSizePixel = 0
        fill.Parent = b
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius or 8)
        c.Parent = fill
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = colors or ColorSequence.new(THEME.accent, THEME.accent2)
        g.Parent = fill
        local l = Instance.new("TextLabel")
        l.Name = "Label"
        l.Size = UDim2.fromScale(1, 1)
        l.BackgroundTransparency = 1
        l.FontFace = FONT_BOLD
        l.TextSize = 12
        l.TextColor3 = Color3.new(1, 1, 1)
        l.Text = label
        l.TextWrapped = true
        l.Parent = b
        local sc = Instance.new("UIScale")
        sc.Parent = b
        b.MouseButton1Down:Connect(function() TweenService:Create(sc, TweenInfo.new(0.08), { Scale = 0.95 }):Play() end)
        b.MouseButton1Up:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
        b.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
        b.Parent = parent
        return b, l, g
    end
    local function tween(o, t, props)
        TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
    end
    local function text(parent, props)
        local l = new("TextLabel", { BackgroundTransparency = 1, FontFace = FONT, TextColor3 = THEME.text,
            TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = true, RichText = true }, parent)
        for k, v in pairs(props) do l[k] = v end
        return l
    end
    local function safeCall(fn, ...)
        if not fn then return end
        local args = table.pack(...)
        task.spawn(function()
            local ok, err = pcall(fn, table.unpack(args, 1, args.n))
            if not ok then warn("[V3ntUI] " .. tostring(err)) end
        end)
    end
    local function draggable(handle, target)
        local dragging, startPos, startInput
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, startPos, startInput = true, target.Position, input.Position
                target:SetAttribute("V3ntDragged", false)
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - startInput
                if d.Magnitude > 6 then target:SetAttribute("V3ntDragged", true) end
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
    end

    V3ntUI.util = {
        new = new, corner = corner, outline = outline, accentGradient = accentGradient,
        tween = tween, text = text, draggable = draggable, fillButton = fillButton, GREEN = GREEN,
        FONT = FONT, FONT_BOLD = FONT_BOLD, FONT_HEAVY = FONT_HEAVY,
    }

    function V3ntUI.new(gui)
        local lib = {}

        function lib:CreateWindow(cfg)
            cfg = cfg or {}
            local W, H = 560, 380

            -- escala automática em telas pequenas
            local scale = new("UIScale", { Scale = 1 }, gui)
            local function rescale()
                local cam = workspace.CurrentCamera
                local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
                scale.Scale = math.clamp(math.min(vp.X / (W + 80), vp.Y / (H + 80)), 0.55, 1)
            end
            rescale()
            pcall(function() workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end)

            local main = new("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
                BackgroundColor3 = THEME.bg, BorderSizePixel = 0, Active = true, ClipsDescendants = true }, gui)
            corner(main, 12)
            outline(main, THEME.stroke, 1)

            -- barra superior
            local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = THEME.panel,
                BorderSizePixel = 0, Active = true }, main)
            corner(top, 12)
            -- tapa os cantos de baixo da barra (só os de cima ficam redondos)
            new("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
                BackgroundColor3 = THEME.panel, BorderSizePixel = 0 }, top)
            local accentLine = new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
                BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2 }, top)
            accentGradient(accentLine)
            local logo = new("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(12, 9),
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, top)
            corner(logo, 7)
            accentGradient(logo, 45)
            text(logo, { Size = UDim2.fromScale(1, 1), Text = "V", FontFace = FONT_HEAVY, TextSize = 18,
                TextXAlignment = Enum.TextXAlignment.Center })
            local titleText = tostring(cfg.Name or "V3nt")
            local a, b = titleText:match("^(.-)%s*%-%s*(.+)$")
            text(top, { Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -140, 0, 20),
                Text = a or titleText, FontFace = FONT_HEAVY, TextSize = 15 })
            text(top, { Position = UDim2.fromOffset(48, 24), Size = UDim2.new(1, -140, 0, 16),
                Text = b or "", TextColor3 = THEME.sub, TextSize = 11 })

            local function topButton(label, x)
                local btn = new("TextButton", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, x, 0, 9),
                    BackgroundColor3 = THEME.card, AutoButtonColor = false, Text = label, FontFace = FONT_BOLD,
                    TextSize = 14, TextColor3 = THEME.sub, BorderSizePixel = 0 }, top)
                corner(btn, 7)
                btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundColor3 = THEME.cardHover, TextColor3 = THEME.text }) end)
                btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundColor3 = THEME.card, TextColor3 = THEME.sub }) end)
                return btn
            end
            local closeBtn = topButton("×", -40)
            local miniBtn = topButton("–", -74)
            draggable(top, main)

            -- barra lateral
            local sidebar = new("Frame", { Name = "Sidebar", Position = UDim2.fromOffset(0, 46),
                Size = UDim2.new(0, 150, 1, -46), BackgroundColor3 = THEME.panel, BorderSizePixel = 0 }, main)
            corner(sidebar, 12)
            -- só o canto de baixo-esquerdo fica redondo (acompanha a janela)
            new("Frame", { Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = THEME.panel, BorderSizePixel = 0 }, sidebar)
            new("Frame", { Size = UDim2.new(0, 12, 1, 0), Position = UDim2.new(1, -12, 0, 0),
                BackgroundColor3 = THEME.panel, BorderSizePixel = 0 }, sidebar)
            new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0),
                BackgroundColor3 = THEME.stroke, BorderSizePixel = 0 }, sidebar)
            local tabList = new("Frame", { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 10),
                BackgroundTransparency = 1 }, sidebar)
            new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)

            local pages = new("Frame", { Name = "Pages", Position = UDim2.fromOffset(150, 46),
                Size = UDim2.new(1, -150, 1, -46), BackgroundTransparency = 1 }, main)

            -- botão flutuante pra reabrir
            local launcher, launcherLabel = fillButton(gui, "V", { Name = "Launcher", Size = UDim2.fromOffset(48, 48),
                Position = UDim2.new(0, 24, 0.5, -24), Visible = false }, nil, 24)
            launcherLabel.FontFace = FONT_HEAVY
            launcherLabel.TextSize = 22
            outline(launcher.Fill, Color3.new(1, 1, 1), 2, 0.6)
            draggable(launcher, launcher)

            local window = { Name = cfg.Name, Tabs = {} }
            local function hide()
                tween(main, 0.2, { Size = UDim2.fromOffset(W, 0) })
                task.delay(0.2, function() main.Visible = false main.Size = UDim2.fromOffset(W, H) end)
                launcher.Visible = true
            end
            closeBtn.Activated:Connect(hide)
            miniBtn.Activated:Connect(hide)
            launcher.Activated:Connect(function()
                if launcher:GetAttribute("V3ntDragged") then return end -- foi arrasto, não clique
                launcher.Visible = false
                main.Visible = true
                main.Size = UDim2.fromOffset(W, 0)
                tween(main, 0.25, { Size = UDim2.fromOffset(W, H) })
            end)

            local function selectTab(tab)
                for _, t in ipairs(window.Tabs) do
                    local on = t == tab
                    t._page.Visible = on
                    tween(t._btn, 0.18, { BackgroundTransparency = on and 0 or 1 })
                    tween(t._label, 0.18, { TextColor3 = on and THEME.text or THEME.sub })
                    tween(t._bar, 0.18, { Size = UDim2.fromOffset(3, on and 18 or 0) })
                end
                window.SelectedTab = tab
            end

            function window:CreateTab(tcfg)
                tcfg = type(tcfg) == "table" and tcfg or { Name = tostring(tcfg) }
                local name = tostring(tcfg.Name)
                local tab = { Name = name, Sections = {} }
                local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = THEME.card,
                    BackgroundTransparency = 1, AutoButtonColor = false, Text = "", BorderSizePixel = 0,
                    LayoutOrder = #window.Tabs + 1 }, tabList)
                corner(btn, 8)
                local bar = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(3, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, btn)
                corner(bar, 2)
                accentGradient(bar, 90)
                local label = text(btn, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -18, 1, 0),
                    Text = name, FontFace = FONT_BOLD, TextColor3 = THEME.sub })
                tab._btn, tab._label, tab._bar = btn, label, bar
                btn.MouseEnter:Connect(function()
                    if window.SelectedTab ~= tab then tween(label, 0.15, { TextColor3 = THEME.text }) end
                end)
                btn.MouseLeave:Connect(function()
                    if window.SelectedTab ~= tab then tween(label, 0.15, { TextColor3 = THEME.sub }) end
                end)

                local page = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                    BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.accent,
                    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false }, pages)
                new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
                new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
                    PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }, page)
                tab._page = page
                btn.Activated:Connect(function() selectTab(tab) end)
                table.insert(window.Tabs, tab)
                if #window.Tabs == 1 then selectTab(tab) end

                local order = 0
                local function nextOrder() order = order + 1 return order end

                -- cartão base: título + descrição à esquerda, controle à direita
                local function card(title, note, controlWidth)
                    local c = new("Frame", { Size = UDim2.new(1, 0, 0, note and 52 or 40), BackgroundColor3 = THEME.card,
                        BorderSizePixel = 0, LayoutOrder = nextOrder() }, page)
                    corner(c, 8)
                    outline(c, THEME.stroke, 1, 0.3)
                    local w = -(controlWidth or 0) - 24
                    local t = text(c, { Position = UDim2.fromOffset(12, note and 8 or 0),
                        Size = UDim2.new(1, w, 0, note and 18 or 40), Text = title, FontFace = FONT_BOLD, TextSize = 13 })
                    if note then
                        text(c, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, w, 0, 18),
                            Text = note, TextColor3 = THEME.sub, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd })
                    end
                    c.MouseEnter:Connect(function() tween(c, 0.15, { BackgroundColor3 = THEME.cardHover }) end)
                    c.MouseLeave:Connect(function() tween(c, 0.15, { BackgroundColor3 = THEME.card }) end)
                    return c, t
                end

                function tab:CreateSection(scfg)
                    scfg = type(scfg) == "table" and scfg or { Name = tostring(scfg) }
                    local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
                        LayoutOrder = nextOrder() }, page)
                    text(holder, { Size = UDim2.new(1, 0, 1, 0), Text = string.upper(tostring(scfg.Name)),
                        FontFace = FONT_BOLD, TextSize = 11, TextColor3 = THEME.accent,
                        TextYAlignment = Enum.TextYAlignment.Bottom })
                    local section = { Name = scfg.Name }

                    function section:CreateToggle(c)
                        local row = card(tostring(c.Name), c.Note, 44)
                        local pill = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
                            Size = UDim2.fromOffset(40, 22), BackgroundColor3 = THEME.off, AutoButtonColor = false,
                            Text = "", BorderSizePixel = 0 }, row)
                        corner(pill, 11)
                        local grad = accentGradient(pill)
                        grad.Enabled = false
                        local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
                            Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, pill)
                        corner(knob, 8)
                        local value = c.Default == true
                        local function set(v, fire)
                            value = v == true
                            grad.Enabled = value
                            tween(pill, 0.18, { BackgroundColor3 = value and Color3.new(1, 1, 1) or THEME.off })
                            tween(knob, 0.18, { Position = UDim2.new(0, value and 21 or 3, 0.5, 0) })
                            if fire ~= false then safeCall(c.Callback, value) end
                        end
                        pill.Activated:Connect(function() set(not value) end)
                        set(value, false)
                        return { GetValue = function() return value end, SetValue = function(_, v, fire) set(v, fire) end }
                    end

                    function section:CreateButton(c)
                        local row = card(tostring(c.Name), c.Note, 96)
                        local b = fillButton(row, tostring(c.ButtonText or T("Executar")), {
                            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                            Size = UDim2.fromOffset(90, 28) }, nil, 7)
                        b.Activated:Connect(function() safeCall(c.Callback) end)
                        return {}
                    end

                    function section:CreateInput(c)
                        local row = card(tostring(c.Name), c.Note, 110)
                        local field = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                            Size = UDim2.fromOffset(104, 28), BackgroundColor3 = THEME.bg, BorderSizePixel = 0 }, row)
                        corner(field, 7)
                        local fs = outline(field, THEME.stroke, 1)
                        local box = new("TextBox", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0),
                            BackgroundTransparency = 1, Text = tostring(c.Default or ""),
                            PlaceholderText = tostring(c.Placeholder or ""), PlaceholderColor3 = THEME.sub,
                            FontFace = FONT_BOLD, TextSize = 12, TextColor3 = THEME.text, ClearTextOnFocus = false }, field)
                        box.Focused:Connect(function() tween(fs, 0.15, { Color = THEME.accent }) end)
                        box.FocusLost:Connect(function()
                            tween(fs, 0.15, { Color = THEME.stroke })
                            local v = box.Text:match("^%s*(.-)%s*$") or ""
                            if c.MaxLength then v = v:sub(1, c.MaxLength) end
                            box.Text = v
                            safeCall(c.Callback, v)
                        end)
                        return { SetText = function(_, t) box.Text = tostring(t) end }
                    end

                    function section:CreateText(c)
                        local row = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                            BackgroundColor3 = THEME.panel, BorderSizePixel = 0, LayoutOrder = nextOrder() }, page)
                        corner(row, 8)
                        new("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9),
                            PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, row)
                        local l = text(row, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                            Text = tostring(c.Text or c.Name), TextColor3 = THEME.sub, TextSize = 12,
                            TextYAlignment = Enum.TextYAlignment.Top })
                        local set = function(_, t) l.Text = tostring(t) end
                        return { SetText = set, Set = set }
                    end

                    table.insert(tab.Sections, section)
                    return section
                end

                return tab
            end

            function window:GetDefaultTab() return window.Tabs[1] end
            function window:Destroy()
                pcall(function() main:Destroy() end)
                pcall(function() launcher:Destroy() end)
            end

            -- entrada suave
            main.Size = UDim2.fromOffset(W, 0)
            tween(main, 0.3, { Size = UDim2.fromOffset(W, H) })
            return window
        end

        function lib:Finalize() end
        return lib
    end
end

-- ═══ FLY (reescrito do zero) ═════════════════════════════════════════════════
-- Como funciona:
--   • Um único "motor" no HumanoidRootPart: LinearVelocity (move) + AlignOrientation
--     (mantém em pé). Humanoid.PlatformStand = true durante o voo, então o
--     Humanoid não briga com o motor (era isso que fazia subir, cair e tentar de
--     novo). Enquanto calcula a rota o motor segura o personagem parado no ar.
--   • Rota simples e testada antes com Spherecast:
--       saída (o próprio lugar ou ao lado, se tiver teto) → sobe reto →
--       vai reto na altitude livre → desce (em cima do alvo ou ao lado, se tiver
--       teto) → alvo.  A altitude sobe de 20 em 20 studs até a linha ficar livre.
--   • Segue os pontos sem passar deles (velocidade limitada pelo que falta).
--   • Travou (sem chegar mais perto por 1,5s): recalcula do lugar atual, até 3x.
--   • Alvo sumiu / travou / erro / cancelado: limpa tudo e, se estiver no ar sem
--     chão perto, pousa na ilha mais próxima (ou no seu plot).
--   • hold = true: ao chegar continua parado no ar até Fly.release() (usado pra
--     segurar o "Grab" de ovos que ficam no alto).
local Fly = { current = nil, holding = nil }

-- folga usada nos testes de rota (o personagem tem ~2 de largura e ~5 de altura;
-- 4 dá margem pra não raspar em ilhas). Se não achar rota, tenta com 2.5.
local CAST_RADIUS = 4

local function castParams(ignore)
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    local list = {}
    if LP.Character then table.insert(list, LP.Character) end
    for _, x in ipairs(ignore or {}) do
        if typeof(x) == "Instance" then table.insert(list, x) end
    end
    p.FilterDescendantsInstances = list
    p.RespectCanCollide = true
    p.IgnoreWater = true
    return p
end

local castCount = 0
-- Spherecast aceita no máximo 1024 studs: testa em trechos de 900.
local function lineClear(a, b, params, radius)
    local d = b - a
    local len = d.Magnitude
    if len < 0.5 then return true end
    local dir, from, done = d.Unit, a, 0
    while done < len do
        local step = math.min(900, len - done)
        castCount = castCount + 1
        if castCount % 200 == 0 then task.wait() end
        local ok, hit = pcall(function() return workspace:Spherecast(from, radius or CAST_RADIUS, dir * step, params) end)
        if not ok or hit then return false end
        from = from + dir * step
        done = done + step
    end
    return true
end

local RING = { Vector3.zero }
for _, r in ipairs({ 14, 28, 50 }) do
    for i = 0, 7 do
        local a = i / 8 * math.pi * 2
        table.insert(RING, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
    end
end

-- Devolve a lista de pontos até o alvo (ou nil).
local planRouteOnce
local function planRoute(start, goal, params)
    local r = planRouteOnce(start, goal, params)
    if r then return r end
    local old = CAST_RADIUS
    CAST_RADIUS = 2.5
    r = planRouteOnce(start, goal, params)
    CAST_RADIUS = old
    return r
end
planRouteOnce = LPH_ENCFUNC(function(start, goal, params)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    castCount = 0
    -- perto e na mesma altura: reto
    if (goal - start).Magnitude < 40 and math.abs(goal.Y - start.Y) < 6 and lineClear(start, goal, params) then
        return { goal }
    end
    -- pontos de saída (céu livre acima) e de chegada (céu livre acima do alvo/lado)
    local exits, entries = {}, {}
    for _, off in ipairs(RING) do
        local p = start + off
        if lineClear(start, p, params) then table.insert(exits, p) end
        if #exits >= 6 then break end
    end
    for _, off in ipairs(RING) do
        local p = goal + off
        if lineClear(p, goal, params) then table.insert(entries, p) end
        if #entries >= 6 then break end
    end
    local base = math.max(start.Y, goal.Y) + 6
    for k = 0, 14 do
        local alt = base + k * 20
        local okExits, okEntries = {}, {}
        for _, e in ipairs(exits) do
            if lineClear(e, Vector3.new(e.X, alt, e.Z), params) then table.insert(okExits, e) end
        end
        if #okExits > 0 then
            for _, g in ipairs(entries) do
                if lineClear(Vector3.new(g.X, alt, g.Z), g, params) then table.insert(okEntries, g) end
            end
        end
        for _, e in ipairs(okExits) do
            for _, g in ipairs(okEntries) do
                local A, C = Vector3.new(e.X, alt, e.Z), Vector3.new(g.X, alt, g.Z)
                if lineClear(A, C, params) then
                    local route, last = {}, start
                    for _, p in ipairs({ e, A, C, g, goal }) do
                        if (p - last).Magnitude > 1 then table.insert(route, p); last = p end
                    end
                    log(("rota: %d pontos, altitude %.0f, %d testes"):format(#route, alt, castCount))
                    return route
                end
            end
        end
    end
    log("sem rota livre (" .. castCount .. " testes)")
    return nil
end, LPH_KEY, get_key())

-- Desvio: tem algo na frente (ex.: ilha em cima enquanto sobe). Procura um
-- ponto ao lado, o mais perto possível, de onde dá pra seguir até o destino do
-- trecho sem bater. Subindo/descendo: testa 16 direções na horizontal e, do
-- ponto ao lado, a coluna até a altura do destino. Andando de lado: testa
-- direita/esquerda/cima/baixo do movimento. Devolve os pontos a inserir.
local findDetour = LPH_ENCFUNC(function(pos, target, params)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local dir = target - pos
    if dir.Magnitude < 1 then return nil end
    dir = dir.Unit
    local vertical = math.abs(dir.Y) > 0.7
    local sides = {}
    if vertical then
        for i = 0, 15 do
            local a = i / 16 * math.pi * 2
            table.insert(sides, Vector3.new(math.cos(a), 0, math.sin(a)))
        end
    else
        local right = dir:Cross(Vector3.yAxis)
        if right.Magnitude < 0.1 then right = Vector3.xAxis end
        right = right.Unit
        local up = right:Cross(dir).Unit
        sides = { up, right, -right, (up + right).Unit, (up - right).Unit, -up }
    end
    for _, d in ipairs({ 12, 22, 35, 55, 80 }) do
        for _, s in ipairs(sides) do
            local side = pos + s * d
            if lineClear(pos, side, params) then
                if vertical then
                    local col = Vector3.new(side.X, target.Y, side.Z)
                    if lineClear(side, col, params) then return { side, col } end
                else
                    if lineClear(side, target, params) then return { side } end
                end
            end
        end
    end
    return nil
end, LPH_KEY, get_key())

-- motor -----------------------------------------------------------------------
local makeMotor = LPH_ENCFUNC(function(hrp, hum)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local att = Instance.new("Attachment")
    att.Name = "V3ntFlyAtt"
    att.Parent = hrp
    local lv = Instance.new("LinearVelocity")
    lv.Name = "V3ntFly"
    lv.Attachment0 = att
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.MaxForce = math.huge
    lv.VectorVelocity = Vector3.zero
    lv.Parent = hrp
    local ao = Instance.new("AlignOrientation")
    ao.Name = "V3ntFlyUp"
    ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    ao.Attachment0 = att
    ao.MaxTorque = math.huge
    ao.Responsiveness = 60
    local look = hrp.CFrame.LookVector
    ao.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z).Unit)
    ao.Parent = hrp
    hum.PlatformStand = true
    local motor = { att = att, lv = lv, ao = ao, hum = hum, hrp = hrp }
    function motor.face(dir)
        local flat = Vector3.new(dir.X, 0, dir.Z)
        if flat.Magnitude > 0.2 then ao.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit) end
    end
    function motor.destroy()
        pcall(function() lv:Destroy() end)
        pcall(function() ao:Destroy() end)
        pcall(function() att:Destroy() end)
        pcall(function()
            hum.PlatformStand = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    return motor
end, LPH_KEY, get_key())

local function groundBelow(pos, depth, params)
    local ok, r = pcall(function()
        return workspace:Raycast(pos, Vector3.new(0, -(depth or 1000), 0), params or castParams())
    end)
    if ok and r and r.Normal.Y > 0.5 then return r.Position end
end

local function plotLanding()
    local plot = getOwnPlot()
    local floor = plot and plot:FindFirstChild("Floor")
    if floor and floor:IsA("BasePart") then
        return floor.Position + Vector3.new(0, floor.Size.Y / 2 + 3.5, 0)
    end
end

local function nearestGround(origin)
    local params = castParams()
    local g = groundBelow(origin, 500, params)
    if g then return g + Vector3.new(0, 3.5, 0) end
    for _, rad in ipairs({ 40, 90, 160, 260, 400, 650, 1000 }) do
        local best, bestD
        for i = 0, 15 do
            local a = i / 16 * math.pi * 2
            local hit = groundBelow(origin + Vector3.new(math.cos(a) * rad, 200, math.sin(a) * rad), 3000, params)
            if hit then
                local d = (hit - origin).Magnitude
                if not bestD or d < bestD then best, bestD = hit, d end
            end
        end
        if best then return best + Vector3.new(0, 3.5, 0) end
    end
    return plotLanding()
end

function Fly.release()
    local h = Fly.holding
    Fly.holding = nil
    if h then h.destroy() end
end

function Fly.cancel(reason)
    local cur = Fly.current
    if cur then cur.cancelled = reason or "cancel" end
end

function Fly.isBusy()
    return Fly.current ~= nil
end

local landing = false

-- Voa até getTarget() (Vector3 ou nil = alvo sumiu). Bloqueia até terminar.
-- Devolve: chegou (bool), motivo ("ok", "lost", "stuck", "timeout", "nochar",
-- "cancel", "replace", "error").
Fly.travel = LPH_ENCFUNC(function(getTarget, opts)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    opts = opts or {}
    Fly.cancel("replace")
    Fly.release()
    -- espera o voo anterior soltar o motor
    local t0 = os.clock()
    while Fly.current and os.clock() - t0 < 1 do task.wait() end

    local _, hrp, hum = getChar()
    if not hrp then return false, "nochar" end
    local function target()
        local ok, v = pcall(getTarget)
        if ok and typeof(v) == "Vector3" then return v end
    end
    local goal = target()
    if not goal then return false, "lost" end

    local job = {}
    Fly.current = job
    local motor = makeMotor(hrp, hum)
    local params = castParams(opts.ignore)
    local result, reason = false, "error"

    local ok, err = pcall(function()
        local route = planRoute(hrp.Position, goal, params)
        if not route then
            -- reserva: sobe bem alto, vai reto e desce
            local alt = math.max(hrp.Position.Y, goal.Y) + 200
            route = { Vector3.new(hrp.Position.X, alt, hrp.Position.Z), Vector3.new(goal.X, alt, goal.Z), goal }
            log("usando rota alta de reserva")
        end
        local idx, tries, moves, detours = 1, 0, 0, 0
        local best, bestAt = math.huge, os.clock()
        local total = 0
        do local prev = hrp.Position for _, p in ipairs(route) do total = total + (p - prev).Magnitude prev = p end end
        local deadline = os.clock() + total / math.max(config.flySpeed, 10) * 2.5 + 15
        setStatus(T("Voando (%d pontos)", #route))

        while true do
            local dt = RunService.Heartbeat:Wait()
            if job.cancelled then reason = job.cancelled return end
            local _, h = getChar()
            if not h or h ~= hrp or not motor.lv.Parent then reason = "nochar" return end
            local g = target()
            if not g then reason = "lost" return end
            if os.clock() > deadline then reason = "timeout" return end

            -- alvo andou: recalcula
            if (g - goal).Magnitude > 8 then
                moves = moves + 1
                if moves > 6 then reason = "lost" return end
                goal = g
                motor.lv.VectorVelocity = Vector3.zero
                route = planRoute(h.Position, goal, params) or { goal }
                idx, best, bestAt = 1, math.huge, os.clock()
            end

            local p = route[idx]
            local delta = p - h.Position
            local dist = delta.Magnitude
            local last = idx == #route
            if dist <= (last and 1.5 or 3) then
                if last then result, reason = true, "ok" return end
                idx = idx + 1
                best, bestAt = math.huge, os.clock()
            else
                local spd = math.min(config.flySpeed, dist / math.max(dt, 1 / 240) * 0.85)
                -- olha à frente (mais longe quanto mais rápido) e desvia antes de bater.
                -- Perto do destino final não olha (o chão/plot embaixo não é obstáculo).
                local blocked = false
                if not (last and dist < 12) and detours < 10 then
                    local look = math.min(dist, spd * dt * 6 + 10)
                    local okC, hit = pcall(function()
                        return workspace:Spherecast(h.Position, 3, delta.Unit * look, params)
                    end)
                    if okC and hit then
                        blocked = true
                        motor.lv.VectorVelocity = Vector3.zero
                        local detour = findDetour(h.Position, p, params)
                        if detour then
                            detours = detours + 1
                            for i = #detour, 1, -1 do table.insert(route, idx, detour[i]) end
                            log(("desviando de %s (%d pontos)"):format(hit.Instance and hit.Instance.Name or "?", #detour))
                            best, bestAt = math.huge, os.clock()
                        else
                            tries = tries + 1
                            log("obstáculo sem desvio, recalculando (" .. tries .. ")")
                            if tries > 3 then reason = "stuck" return end
                            route = planRoute(h.Position, goal, params) or { goal }
                            idx, best, bestAt = 1, math.huge, os.clock()
                        end
                    end
                end
                if not blocked then
                    motor.lv.VectorVelocity = delta.Unit * spd
                    motor.face(delta)
                end
                if dist < best - 0.5 then
                    best, bestAt = dist, os.clock()
                elseif os.clock() - bestAt > 1.5 then
                    tries = tries + 1
                    log("voo travado, recalculando (" .. tries .. ")")
                    if tries > 3 then reason = "stuck" return end
                    motor.lv.VectorVelocity = Vector3.zero
                    route = planRoute(h.Position + Vector3.new(0, 4, 0), goal, params) or { goal }
                    idx, best, bestAt = 1, math.huge, os.clock()
                end
            end
        end
    end)
    if not ok then
        log("erro no voo:", err)
        reason = "error"
    end

    if Fly.current == job then Fly.current = nil end
    if result and opts.hold then
        motor.lv.VectorVelocity = Vector3.zero
        Fly.holding = motor
    else
        motor.destroy()
    end
    if not result and not opts.isLanding and reason ~= "replace" and reason ~= "nochar" then
        task.spawn(function() Fly.landSafe() end)
    end
    return result, reason
end, LPH_KEY, get_key())

-- Se estiver no ar sem chão perto, pousa na ilha mais próxima (ou no plot).
Fly.landSafe = LPH_ENCFUNC(function()
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    if landing or Fly.current then return end
    local _, hrp, hum = getChar()
    if not hrp then return end
    if hum.FloorMaterial ~= Enum.Material.Air then return end
    if groundBelow(hrp.Position, 30) then return end
    landing = true
    local ok, err = pcall(function()
        local spot = nearestGround(hrp.Position)
        if not spot then
            notify(T("Não achei chão perto."), "err")
            return
        end
        setStatus(T("Pousando na ilha mais próxima..."))
        local reached, why = Fly.travel(function() return spot end, { isLanding = true })
        if not reached and why ~= "replace" and why ~= "cancel" then
            local plot = plotLanding()
            if plot then Fly.travel(function() return plot end, { isLanding = true }) end
        end
    end)
    if not ok then log("erro no pouso:", err) end
    landing = false
end, LPH_KEY, get_key())

function Fly.stop()
    Fly.cancel("cancel")
    if Fly.holding then
        Fly.release()
        task.spawn(Fly.landSafe)
    end
end

-- ═══ EGGS: ESP + HUB ═════════════════════════════════════════════════════════
-- Só leitura (nada é enviado ao servidor). Fontes no dump:
--   Ovos no plot : tag "BasePlotEggVisual", atributos BrainrotIndex, Mutation,
--                  Traits ("a|b"), HatchAt, EggPlacedAt   (JumpLTMController:359)
--   Ovos no mapa : JumpLTMController.RenderedEggs[id].model (linha 1241) e os
--                  dados do pool "JumpLTM/Eggs": brainrot, mutation, traits,
--                  timer, despawnTimer, grabbed           (WorldBrainrotController:58)
--   Nomes/cores  : Datas.Animals, Datas.Rarities, Datas.Traits, Datas.Mutations

local function tryRequire(...)
    local inst = ReplicatedStorage
    for _, n in ipairs({ ... }) do
        inst = inst and inst:FindFirstChild(n)
    end
    if not (inst and inst:IsA("ModuleScript")) then return nil end
    local ok, m = pcall(require, inst)
    return ok and type(m) == "table" and m or nil
end

local AnimalsData   = tryRequire("Datas", "Animals") or {}
local RaritiesData  = tryRequire("Datas", "Rarities") or {}
local TraitsData    = tryRequire("Datas", "Traits") or {}
local MutationsData = tryRequire("Datas", "Mutations") or {}

local eggPool
do
    local Rep = tryRequire("Packages", "ReplicatorClient")
    if Rep and type(Rep.get) == "function" then
        local ok, pool = pcall(Rep.get, "JumpLTM/Eggs")
        if ok then eggPool = pool end
    end
    log("Pool JumpLTM/Eggs:", eggPool and "ok" or "indisponível (usa o overhead)")
end

-- Ícone do trait -> nome (pra ler os traits pelo overhead quando não há dados).
local traitByIcon = {}
for name, t in pairs(TraitsData) do
    if type(t) == "table" and t.Icon then traitByIcon[tostring(t.Icon)] = name end
end

-- Ícones: só os do próprio jogo (Datas.Mutations[x].Icon e Datas.Traits[x].Icon).
local function mutationIcon(m) local d = m and MutationsData[m]; return d and d.Icon end
local function traitIcon(t) local d = t and TraitsData[t]; return d and d.Icon end
local function mutationRich(m)
    local d = m and MutationsData[m]
    return (d and d.DisplayWithRichText) or (m and ("<b>" .. tostring(m) .. "</b>")) or nil
end
local function traitRich(t)
    local d = t and TraitsData[t]
    return (d and d.DisplayWithRichText) or tostring(t)
end

-- ─── Helpers de texto ────────────────────────────────────────────────────────
local function esc(v)
    return (tostring(v):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function hex(c)
    if typeof(c) ~= "Color3" then return "FFFFFF" end
    return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function fmtTime(sec)
    if type(sec) ~= "number" then return nil end
    if sec <= 0 then return T("PRONTO!") end
    sec = math.ceil(sec)
    if sec >= 3600 then return string.format("%dh%02dm", sec // 3600, (sec % 3600) // 60) end
    return string.format("%d:%02d", sec // 60, sec % 60)
end
local function fmtVal(v)
    local t = typeof(v)
    if t == "number" then
        if math.abs(v) >= 1e6 then return string.format("%.3g", v) end
        return tostring(math.floor(v * 100 + 0.5) / 100)
    elseif t == "Color3" then return "#" .. hex(v)
    elseif t == "Vector3" then return string.format("%.0f, %.0f, %.0f", v.X, v.Y, v.Z)
    elseif t == "CFrame" then return string.format("%.0f, %.0f, %.0f", v.X, v.Y, v.Z)
    elseif t == "table" then
        local parts = {}
        for k, x in pairs(v) do
            local tx = typeof(x)
            if tx ~= "table" and tx ~= "function" and tx ~= "Instance" then
                table.insert(parts, (type(k) == "number" and "" or tostring(k) .. "=") .. tostring(x))
            end
            if #parts >= 6 then break end
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

-- ─── Coleta de ovos ──────────────────────────────────────────────────────────
local function plotOwner(inst)
    while inst and inst ~= workspace do
        if inst:IsA("Model") then
            local uid = inst:GetAttribute("OwnerUserId")
            if type(uid) == "number" then return uid end
        end
        inst = inst.Parent
    end
end

local function splitTraits(v)
    if type(v) == "table" then return v end
    if type(v) == "string" and v ~= "" then return string.split(v, "|") end
    return {}
end

-- Lê o overhead do jogo que fica dentro do model (fallback dos ovos do mapa).
local function readOverhead(model)
    local out = {}
    for _, g in ipairs(model:GetDescendants()) do
        if g:IsA("BillboardGui") or (g:IsA("GuiObject") and g:FindFirstChild("DisplayName")) then
            local root = g
            local dn = root:FindFirstChild("DisplayName", true)
            if dn and dn:IsA("TextLabel") then
                out.displayName = dn.Text
                local m = root:FindFirstChild("Mutation", true)
                if m and m:IsA("TextLabel") and m.Visible then out.mutation = m.Text end
                local r = root:FindFirstChild("Rarity", true)
                if r and r:IsA("TextLabel") then out.rarity = r.Text end
                local gen = root:FindFirstChild("Generation", true)
                if gen and gen:IsA("TextLabel") and gen.Visible then out.generation = gen.Text end
                local st = root:FindFirstChild("Stolen", true)
                if st and st:IsA("TextLabel") and st.Visible then out.stolen = st.Text end
                local tr = root:FindFirstChild("Traits", true)
                if tr then
                    out.traits = {}
                    for _, img in ipairs(tr:GetChildren()) do
                        if img:IsA("ImageLabel") and img.Visible and img.Name ~= "Template" then
                            table.insert(out.traits, traitByIcon[img.Image] or img.Image)
                        end
                    end
                end
                return out
            end
        end
    end
    return out
end

local collectEggs = LPH_ENCFUNC(function()
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local list = {}
    -- Ovos colocados nos plots
    for _, m in ipairs(CollectionService:GetTagged("BasePlotEggVisual")) do
        -- ovos do meu próprio plot não aparecem
        if m:IsA("Model") and m:IsDescendantOf(workspace) and plotOwner(m) ~= LP.UserId then
            local attrs = m:GetAttributes()
            local uid = plotOwner(m)
            local owner = uid and Players:GetPlayerByUserId(uid)
            table.insert(list, {
                key = m, kind = "Plot", model = m,
                index = attrs.BrainrotIndex, mutation = attrs.Mutation,
                traits = splitTraits(attrs.Traits),
                hatchAt = attrs.HatchAt,
                owner = owner and owner.Name or (uid and ("UserId " .. uid)) or "?",
                attrs = attrs,
            })
        end
    end
    -- Ovos soltos no mapa (pool JumpLTM/Eggs)
    local rendered = JLC and type(JLC.RenderedEggs) == "table" and JLC.RenderedEggs or {}
    for id, rec in pairs(rendered) do
        local m = type(rec) == "table" and rec.model
        if typeof(m) == "Instance" and m:IsDescendantOf(workspace) then
            local data
            if eggPool then
                local ok, d = pcall(function() return eggPool:TryIndex({ "brainrots", id }) end)
                if ok and type(d) == "table" then data = d end
            end
            local oh = data and {} or readOverhead(m)
            local prompt = rec.prompt
            table.insert(list, {
                key = m, kind = "Mapa", model = m, id = id,
                index = data and data.brainrot or (typeof(prompt) == "Instance" and prompt.ObjectText) or oh.displayName,
                mutation = data and data.mutation or oh.mutation,
                traits = data and splitTraits(data.traits) or oh.traits or {},
                timer = data and data.timer, despawn = data and data.despawnTimer,
                grabbed = data and data.grabbed ~= nil or oh.stolen ~= nil,
                overhead = oh, data = data,
            })
        end
    end
    return list
end, LPH_KEY, get_key())

-- ─── Texto de info ───────────────────────────────────────────────────────────
local eggInfo = LPH_ENCFUNC(function(e, hrp)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local a = type(e.index) == "string" and AnimalsData[e.index] or nil
    local name = a and a.DisplayName or e.index or T("Ovo")
    local rarity = a and a.Rarity or (e.overhead and e.overhead.rarity)
    local rd = rarity and RaritiesData[rarity]
    local rcolor = rd and rd.Color or Color3.fromRGB(230, 230, 230)

    local traitsTxt = {}
    for _, t in ipairs(e.traits) do table.insert(traitsTxt, traitRich(t)) end

    local timerTxt
    if type(e.hatchAt) == "number" then
        timerTxt = fmtTime(e.hatchAt - workspace:GetServerTimeNow())
    elseif type(e.timer) == "number" then
        timerTxt = fmtTime(e.timer)
    elseif e.overhead and e.overhead.generation then
        timerTxt = e.overhead.generation
    end

    local pos = e.model:GetPivot().Position
    local dist = hrp and (pos - hrp.Position).Magnitude

    local L = {}
    table.insert(L, ('<font size="15"><b>%s</b></font>'):format(esc(name)))
    if rarity then
        table.insert(L, T("Raridade:") .. (' <font color="#%s"><b>%s</b></font>'):format(hex(rcolor), esc(rarity)))
    end
    table.insert(L, T("Mutação:") .. " " .. (mutationRich(e.mutation) or T("nenhuma")))
    table.insert(L, T("Traits (%d): %s", #e.traits, #traitsTxt > 0 and table.concat(traitsTxt, ", ") or T("nenhum")))
    -- o que o ovo choca (Datas.Animals[ovo].Egg.Animals)
    if a and type(a.Egg) == "table" and type(a.Egg.Animals) == "table" then
        local out = {}
        for _, x in ipairs(a.Egg.Animals) do
            if type(x) == "table" and x.Name then
                local ad = AnimalsData[x.Name]
                local r = ad and ad.Rarity and RaritiesData[ad.Rarity]
                table.insert(out, ('<font color="#%s">%s</font> (%s%%)'):format(
                    hex(r and r.Color), esc(ad and ad.DisplayName or x.Name), tostring(x.Chance or "?")))
            end
        end
        if #out > 0 then table.insert(L, T("Contém:") .. " " .. table.concat(out, ", ")) end
        if a.Egg.Timer then table.insert(L, T("Tempo de chocar:") .. " " .. esc(fmtTime(a.Egg.Timer))) end
    end
    if timerTxt then table.insert(L, T("Choca em:") .. " <b>" .. esc(timerTxt) .. "</b>") end
    if type(e.despawn) == "number" then table.insert(L, T("Some em:") .. " " .. esc(fmtTime(e.despawn))) end
    if e.kind == "Plot" then
        table.insert(L, T("Plot de:") .. " <b>" .. esc(e.owner) .. "</b>")
    else
        table.insert(L, T("No mapa") .. (e.grabbed and (' — <font color="#FF5555">' .. T("PEGO") .. '</font>') or (" — " .. T("livre"))))
    end
    if dist then table.insert(L, T("Distância: %.0f studs", dist)) end
    table.insert(L, T("Posição:") .. " " .. fmtVal(pos))
    if e.index and a and e.index ~= name then table.insert(L, T("Index:") .. " " .. esc(e.index)) end

    -- Tudo o que tiver no Datas.Animals (campos simples)
    if a then
        local keys = {}
        for k, v in pairs(a) do
            local tv = typeof(v)
            if k ~= "DisplayName" and k ~= "Rarity" and tv ~= "function" and tv ~= "Instance" then
                table.insert(keys, k)
            end
        end
        table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
        for _, k in ipairs(keys) do
            table.insert(L, ('<font color="#9A9A9A">• %s: %s</font>'):format(esc(k), esc(fmtVal(a[k]))))
        end
    end
    -- Atributos do model / dados do pool
    local extra = e.attrs or e.data
    if extra then
        local keys = {}
        for k in pairs(extra) do table.insert(keys, k) end
        table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
        for _, k in ipairs(keys) do
            local v = extra[k]
            if k == "HatchAt" or k == "EggPlacedAt" or k == "PetGrowInAt" then
                v = type(v) == "number" and (fmtTime(v - workspace:GetServerTimeNow()) or v) or v
            end
            if typeof(v) ~= "function" then
                table.insert(L, ('<font color="#7A7A7A">◦ %s: %s</font>'):format(esc(k), esc(fmtVal(v))))
            end
        end
    end

    -- texto curto do ESP: nome + mutação colorida (os ícones vão em imagens)
    local short = "<b>" .. esc(name) .. "</b>" .. (e.mutation and (" " .. mutationRich(e.mutation)) or "")
    return table.concat(L, "\n"), short, rcolor, timerTxt, dist
end, LPH_KEY, get_key())

-- ─── ESP ─────────────────────────────────────────────────────────────────────
local espFolder = Instance.new("Folder")
espFolder.Name = "EggESP"
espFolder.Parent = sg

local makeEsp = LPH_ENCFUNC(function(e)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local hl = Instance.new("Highlight")
    hl.Adornee = e.model
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = espFolder

    local bb = Instance.new("BillboardGui")
    bb.Adornee = e.model.PrimaryPart or e.model:FindFirstChildWhichIsA("BasePart", true)
    bb.Size = UDim2.new(0, 220, 0, 72)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2000
    bb.Parent = espFolder
    -- linha de ícones do jogo: mutação + traits
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = bb
    local rl = Instance.new("UIListLayout", row)
    rl.FillDirection = Enum.FillDirection.Horizontal
    rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rl.Padding = UDim.new(0, 2)
    local icons = { mutationIcon(e.mutation) }
    for _, tr in ipairs(e.traits) do table.insert(icons, traitIcon(tr)) end
    for _, img in pairs(icons) do
        if img then
            local i = Instance.new("ImageLabel")
            i.Size = UDim2.new(0, 22, 0, 22)
            i.BackgroundTransparency = 1
            i.Image = tostring(img)
            i.Parent = row
        end
    end
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 1, -22)
    t.Position = UDim2.new(0, 0, 0, 22)
    t.BackgroundTransparency = 1
    t.TextColor3 = Color3.new(1, 1, 1)
    t.TextStrokeTransparency = 0.3
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.RichText = true
    t.TextWrapped = true
    t.Parent = bb
    return { hl = hl, bb = bb, label = t }
end, LPH_KEY, get_key())

-- ═══ HUB DE OVOS ═════════════════════════════════════════════════════════════
local U, TH = V3ntUI.util, V3ntUI.Theme
local new, corner, outline, tween, text = U.new, U.corner, U.outline, U.tween, U.text

-- rótulos fixos que mudam quando troca o idioma
local i18nLabels = {}
local function reg(inst, key, ...)
    table.insert(i18nLabels, { inst, key, table.pack(...) })
    inst.Text = T(key, ...)
    return inst
end

local hubGui = newProtectedGui("V3ntJumpForEggHub")
local hubScale = new("UIScale", { Scale = 1 }, hubGui)
local function rescaleHub()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    hubScale.Scale = math.clamp(math.min(vp.X / 900, vp.Y / 620), 0.55, 1)
end
rescaleHub()
pcall(function() workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescaleHub) end)

local hub = new("Frame", { Name = "EggHub", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
    Size = UDim2.fromOffset(420, 540), BackgroundColor3 = TH.bg, BorderSizePixel = 0, Visible = false,
    Active = true, ClipsDescendants = true }, hubGui)
corner(hub, 14)
outline(hub, TH.stroke, 1)

local hubTop = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = TH.panel, BorderSizePixel = 0,
    Active = true }, hub)
corner(hubTop, 14)
do
    -- só os cantos de cima redondos
    new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = TH.panel, BorderSizePixel = 0 }, hubTop)
    local line = new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, hubTop)
    U.accentGradient(line)
end
local hubTitle = text(hubTop, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 20), Text = T("Ovos no servidor"),
    FontFace = U.FONT_HEAVY, TextSize = 15 })
reg(hubTitle, "Ovos no servidor")
local hubSub = text(hubTop, { Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -70, 0, 16),
    Text = T("carregando..."), TextColor3 = TH.sub, TextSize = 11 })
local hubClose = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -1),
    Size = UDim2.fromOffset(30, 30), BackgroundColor3 = TH.card, AutoButtonColor = false, Text = T("×"),
    FontFace = U.FONT_BOLD, TextSize = 18, TextColor3 = TH.sub, BorderSizePixel = 0 }, hubTop)
corner(hubClose, 15)
U.draggable(hubTop, hub)

local hubList = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = TH.accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y }, hub)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, hubList)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 14) }, hubList)
local emptyLabel = text(hubList, { Size = UDim2.new(1, 0, 0, 60), Text = T("Nenhum ovo no servidor agora."),
    TextColor3 = TH.sub, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = -1 })

-- Botão do card. Devolve (botão, label do texto).
--   style "green": degradê verde (Coletar) · "plain": cinza com borda
local function pillButton(parent, label, style, props)
    if style == "green" then
        return U.fillButton(parent, label, props, U.GREEN, 8)
    end
    local b = new("TextButton", { BackgroundColor3 = TH.cardHover, AutoButtonColor = false, Text = label,
        FontFace = U.FONT_BOLD, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, parent)
    for k, v in pairs(props or {}) do b[k] = v end
    corner(b, 8)
    outline(b, TH.stroke, 1)
    local sc = new("UIScale", { Scale = 1 }, b)
    b.MouseButton1Down:Connect(function() tween(sc, 0.08, { Scale = 0.95 }) end)
    b.MouseButton1Up:Connect(function() tween(sc, 0.12, { Scale = 1 }) end)
    b.MouseLeave:Connect(function() tween(sc, 0.12, { Scale = 1 }) end)
    return b, b
end

local function chip(parent, order)
    local c = new("Frame", { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = TH.panel, BorderSizePixel = 0, LayoutOrder = order }, parent)
    corner(c, 11)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, c)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, c)
    local icon = new("ImageLabel", { Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Visible = false,
        LayoutOrder = 1 }, c)
    local label = text(c, { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11,
        FontFace = U.FONT_BOLD, TextWrapped = false, LayoutOrder = 2, Text = "" })
    c.Visible = false
    return c, label, icon
end

-- Cópia visual do model pro preview 3D (sem scripts, prompts, GUIs).
local cloneForPreview = LPH_ENCFUNC(function(model)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local oldArch = model.Archivable
    model.Archivable = true
    local ok, c = pcall(function() return model:Clone() end)
    model.Archivable = oldArch
    if not ok or not c then return nil end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui")
            or d:IsA("SurfaceGui") or d:IsA("Highlight") or d:IsA("Sound") then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.Anchored = true
        end
    end
    return c
end, LPH_KEY, get_key())

-- ─── VOAR / COLETAR ──────────────────────────────────────────────────────────
local HIDDEN_POS = Vector3.new(10000, 10000, 10000)
local currentJob

-- Motivo do voo → (o que aconteceu, solução)
local FLY_PROBLEM = {
    lost    = { "O ovo sumiu no caminho", "Alguém pegou ou ele expirou. Escolha outro ovo no hub." },
    stuck   = { "O voo travou num obstáculo", "Tente de novo de outro lugar ou baixe a velocidade do fly." },
    timeout = { "O voo demorou demais", "Aumente a velocidade do fly ou chegue mais perto antes." },
    error   = { "Erro no voo", "Tente de novo. Se repetir, mande o F9 (linhas [JumpForEggs])." },
    nochar  = { "Seu personagem morreu ou resetou", "Espere renascer e tente de novo." },
}

-- Ocupação do plot: ovos/pets seus x pódios numéricos (AnimalPodiums).
-- Só uma estimativa pra avisar antes de voar; quem decide é o servidor.
local function plotOccupancy()
    local plot = getOwnPlot()
    if not plot then return nil end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    local cap = 0
    if podiums then
        for _, p in ipairs(podiums:GetChildren()) do
            if tonumber(p.Name) then cap = cap + 1 end
        end
    end
    local used = 0
    for _, tag in ipairs({ "BasePlotEggVisual", "BasePlotPet" }) do
        for _, m in ipairs(CollectionService:GetTagged(tag)) do
            if m:IsDescendantOf(plot) then used = used + 1 end
        end
    end
    if cap == 0 then return nil end
    return used, cap
end

local function eggTarget(model)
    return function()
        if not model.Parent or not model:IsDescendantOf(workspace) then return nil end
        local p = model:GetPivot().Position
        -- ovo pego por alguém vai pra (10000, 10000, 10000) (WorldBrainrotController:111)
        if (p - HIDDEN_POS).Magnitude < 5 then return nil end
        return p + Vector3.new(0, 4, 0)
    end
end

local function waitAttr(name, value, timeout)
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if LP:GetAttribute(name) == value then return true end
        task.wait(0.1)
    end
    return LP:GetAttribute(name) == value
end

-- Notificação verde de sucesso do próprio jogo (NotificationController:Success,
-- com o som "Success"). É só visual, no seu cliente. Se não der, usa a nossa.
local GameNotify = (function()
    local ok, m = pcall(function()
        local f = ReplicatedStorage:FindFirstChild("Controllers")
        local n = f and f:FindFirstChild("NotificationController")
        return n and require(n)
    end)
    return ok and type(m) == "table" and m or nil
end)()
local function successNotify(msg)
    log("[sucesso]", msg)
    if GameNotify and type(GameNotify.Success) == "function" then
        if pcall(GameNotify.Success, GameNotify, msg) then return end
    end
    notify(msg, "ok", 5)
end

-- Colocar o ovo como o clique do jogo faz (JumpLTMController:967-981):
-- RequestEggPlace:FireServer(posição) com um ponto do SEU plot (raycast pra baixo,
-- o dono do que foi atingido tem que ser você). Antes o script mandava sem posição
-- (o caminho do controle, linha 1021) e o servidor recusava. Tenta o ponto embaixo
-- de você e, se recusar, outros pontos do chão do plot, do mais perto pro mais longe.
local function placeSpots()
    local spots = {}
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LP.Character }
    local function probe(origin)
        local r = workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
        if r and plotOwner(r.Instance) == LP.UserId then table.insert(spots, r.Position) end
    end
    local _, hrp = getChar()
    if hrp then probe(hrp.Position + Vector3.new(0, 2, 0)) end
    local plot = getOwnPlot()
    local floor = plot and plot:FindFirstChild("Floor")
    if floor and floor:IsA("BasePart") then
        local extra = {}
        for ix = -2, 2 do
            for iz = -2, 2 do
                table.insert(extra, (floor.CFrame * CFrame.new(ix * floor.Size.X * 0.18,
                    floor.Size.Y / 2 + 30, iz * floor.Size.Z * 0.18)).Position)
            end
        end
        if hrp then
            table.sort(extra, function(p, q) return (p - hrp.Position).Magnitude < (q - hrp.Position).Magnitude end)
        end
        for _, o in ipairs(extra) do probe(o) end
    end
    return spots
end

-- Devolve true, ou false + motivo: "notcarrying", "noremote", "nospot", "rejected"
local placeEgg = LPH_ENCFUNC(function(tag)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    if LP:GetAttribute("CarryingJumpEgg") ~= true then return false, "notcarrying" end
    if not eggRemote then return false, "noremote" end
    local spots = placeSpots()
    if #spots == 0 then return false, "nospot" end
    for i = 1, math.min(#spots, 6) do
        eggRemote:FireServer(spots[i])
        log(("RequestEggPlace%s (%.0f, %.0f, %.0f)"):format(tag and (" " .. tag) or "", spots[i].X, spots[i].Y, spots[i].Z))
        if waitAttr("CarryingJumpEgg", false, 1.2) then return true end
        if LP:GetAttribute("CarryingJumpEgg") ~= true then return true end
    end
    return false, "rejected"
end, LPH_KEY, get_key())

-- Explica por que não colocou
local function placeProblem(reason)
    if reason == "notcarrying" then
        return notifyProblem(T("Você não está carregando nenhum ovo"), T("Pegue um ovo (botão Coletar no hub) e tente de novo."), "warn", 6)
    elseif reason == "noremote" then
        return notifyProblem(T("Não dá pra colocar ovos agora"), T("O jogo pode ter atualizado (remote não encontrada). Reinicie o script."))
    elseif reason == "nospot" then
        return notifyProblem(T("Não achei o chão do seu plot embaixo de você"),
            T("O ovo continua na sua mão. Fique em cima do chão do seu plot e use \"Colocar ovo agora\" (aba Base)."))
    end
    local used, cap = plotOccupancy()
    if used and cap and used >= cap then
        return notifyProblem(T("Seu plot está cheio (%d/%d), não deu pra colocar o ovo", used, cap),
            T("O ovo continua na sua mão. Choque, venda ou pegue um ovo/pet do plot e use \"Colocar ovo agora\" (aba Base)."))
    end
    return notifyProblem(T("O servidor recusou todos os lugares tentados"),
        T("O ovo continua na sua mão. Ande pra uma parte livre do chão do seu plot e use \"Colocar ovo agora\" (aba Base)."))
end

local function cancelJob()
    local j = currentJob
    currentJob = nil
    if j then j.cancelled = true; j.reset() end
    Fly.stop()
end

local startEggJob = LPH_ENCFUNC(function(e, ui, mode)
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    if currentJob then
        local same = currentJob.ui == ui and currentJob.mode == mode
        cancelJob()
        if same then return end -- clicar de novo = parar
    end
    local btn = mode == "collect" and ui.collectLabel or ui.flyLabel
    local original = btn.Text
    local job = { ui = ui, mode = mode, cancelled = false }
    job.reset = function() pcall(function() btn.Text = original end) end
    currentJob = job
    btn.Text = T("Parar")
    local function alive() return currentJob == job and not job.cancelled end
    local function finish(msg, kind)
        if currentJob == job then currentJob = nil end
        job.reset()
        if msg then setStatus(msg) end
        if kind then notify(msg, kind, 5) end
    end
    -- termina com problema explicado + solução
    local function fail(title, solution, land)
        if currentJob == job then currentJob = nil end
        job.reset()
        setStatus(title)
        notifyProblem(title, solution)
        if land then
            Fly.release()
            task.spawn(Fly.landSafe)
        end
    end
    local function flyFail(why, what)
        local p = FLY_PROBLEM[why]
        if p then
            fail(what .. ": " .. T(p[1]), T(p[2]), false)
        else
            finish(what .. " (" .. tostring(why) .. ").")
        end
    end
    local name = tostring(e.displayName or e.index or T("Ovo"))

    task.spawn(function()
        local ok, err = pcall(function()
            local model = e.model
            local tgt = eggTarget(model)
            if not tgt() then
                return fail(name .. T(" não está mais disponível"), T("Alguém pegou ou ele expirou. Escolha outro ovo no hub."))
            end
            -- coletar: já avisa se o plot estiver cheio, antes de voar
            if mode == "collect" then
                if not getOwnPlot() then
                    return fail(T("Você ainda não tem plot neste servidor"), T("Pegue um plot primeiro e tente de novo."))
                end
                local used, cap = plotOccupancy()
                if used and cap and used >= cap then
                    return fail(T("Seu plot está cheio (%d/%d)", used, cap),
                        T("Choque, venda ou pegue um ovo/pet do plot pra liberar espaço e tente de novo."))
                end
            end
            setStatus(T("Voando até ") .. name .. "...")
            local reached, why = Fly.travel(tgt, { ignore = { model }, hold = true })
            if not alive() then Fly.release() return end
            if not reached then
                if why == "lost" then
                    return fail(name .. T(" sumiu enquanto você ia até ele"),
                        T("Levando você pra ilha mais próxima. Escolha outro ovo no hub."))
                end
                return flyFail(why, T("Não chegou em ") .. name)
            end

            if mode == "fly" then
                local _, hrp = getChar()
                local ground = hrp and workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), (function()
                    local p = RaycastParams.new()
                    p.FilterType = Enum.RaycastFilterType.Exclude
                    p.FilterDescendantsInstances = { LP.Character }
                    return p
                end)())
                if ground then
                    Fly.release()
                    return finish(T("Chegou em ") .. name .. ".")
                end
                -- sem chão: fica parado no ar até clicar em "Soltar"
                btn.Text = T("Soltar")
                setStatus(T("Parado no ar ao lado do ovo. \"Soltar\" leva você pro chão."))
                return
            end

            -- Coletar: mesmas regras do prompt "Grab" do jogo (segura 1,25s, até 10 studs)
            if LP:GetAttribute("CarryingJumpEgg") ~= true then
                if not grabRemote then
                    return fail(T("Não dá pra pegar ovos agora"), T("O jogo pode ter atualizado (remote Grab não encontrada). Reinicie o script."), true)
                end
                setStatus(T("Pegando ") .. name .. "...")
                task.wait(1.3)
                if not alive() then Fly.release() return end
                local _, hrp = getChar()
                if not tgt() then
                    return fail(name .. T(" sumiu antes de você pegar"), T("Alguém pegou primeiro. Escolha outro ovo no hub."), true)
                end
                if not (hrp and (model:GetPivot().Position - hrp.Position).Magnitude <= 10) then
                    return fail(T("Você ficou longe demais do ovo (mais de 10 studs)"),
                        T("Tente de novo. Se repetir, baixe a velocidade do fly."), true)
                end
                grabRemote:FireServer("JumpLTM/Eggs", e.id)
                log("Grab", e.id)
                if not waitAttr("CarryingJumpEgg", true, 3) then
                    return fail(T("O servidor não deixou pegar ") .. name,
                        T("Alguém pegou antes, ou você já carrega outro ovo. Escolha outro ovo."), true)
                end
            end
            if not alive() then Fly.release() return end

            -- Levar pro plot
            if not plotLanding() then
                return fail(T("Seu plot não foi encontrado"), T("O ovo continua na sua mão. Pegue um plot e coloque nele."), true)
            end
            setStatus(T("Levando ") .. name .. T(" pro seu plot..."))
            reached, why = Fly.travel(plotLanding, {})
            if not alive() then return end
            if not reached then
                return flyFail(why, T("Não chegou no seu plot"))
            end
            -- espera encostar no chão do plot
            local t0 = os.clock()
            local _, _, hum = getChar()
            while hum and hum.FloorMaterial == Enum.Material.Air and os.clock() - t0 < 1.5 do task.wait() end
            if not onOwnPlot() then
                return fail(T("Você não ficou em cima do seu plot"),
                    T("O ovo continua na sua mão. Ande até o chão do plot e use \"Colocar ovo agora\" (aba Base)."))
            end
            setStatus(T("Colocando ") .. name .. "...")
            local placed, why2 = placeEgg("(coletar)")
            if currentJob == job then currentJob = nil end
            job.reset()
            if placed then
                setStatus(name .. T(" colocado no seu plot!"))
                successNotify(name .. T(" foi colocado no seu plot!"))
            else
                setStatus(T("Não deu pra colocar o ovo."))
                placeProblem(why2)
            end
        end)
        if not ok then
            log("erro no voo/coleta:", err)
            fail(T("Erro no voo/coleta"), T("Tente de novo. Se repetir, mande o F9 (linhas [JumpForEggs])."), true)
        end
    end)
end, LPH_KEY, get_key())

-- ─── CARD ────────────────────────────────────────────────────────────────────
local function makeCard(e)
    local card = new("Frame", { Size = UDim2.new(1, 0, 0, 172), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = TH.card, BorderSizePixel = 0 }, hubList)
    corner(card, 12)
    local cardStroke = outline(card, TH.stroke, 1, 0.2)

    local vp = new("ViewportFrame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(116, 116),
        BackgroundColor3 = TH.panel, BorderSizePixel = 0, Ambient = Color3.fromRGB(200, 200, 200),
        LightColor = Color3.new(1, 1, 1) }, card)
    corner(vp, 10)
    local cam = new("Camera", { FieldOfView = 40 }, vp)
    vp.CurrentCamera = cam
    local world = new("WorldModel", {}, vp)
    local center, radius = Vector3.zero, 5
    local copy = cloneForPreview(e.model)
    if copy then
        copy.Parent = world
        local cf, size = copy:GetBoundingBox()
        center, radius = cf.Position, math.max(size.Magnitude / 2, 1)
    end

    local name = text(card, { Position = UDim2.fromOffset(138, 10), Size = UDim2.new(1, -150, 0, 20),
        FontFace = U.FONT_HEAVY, TextSize = 15, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })

    local chips = new("Frame", { Position = UDim2.fromOffset(138, 36), Size = UDim2.new(1, -150, 0, 22),
        BackgroundTransparency = 1 }, card)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder }, chips)
    local rarityChip, rarityLabel = chip(chips, 1)
    local mutChip, mutLabel, mutIcon = chip(chips, 2)
    local goneChip, goneLabel = chip(chips, 3)
    goneLabel.TextColor3 = Color3.fromRGB(255, 120, 120)

    local traitsRow = new("Frame", { Position = UDim2.fromOffset(138, 64), Size = UDim2.new(1, -150, 0, 20),
        BackgroundTransparency = 1 }, card)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, traitsRow)
    local traitIcons = {}
    for i, t in ipairs(e.traits) do
        local img = traitIcon(t)
        if img and i <= 6 then
            table.insert(traitIcons, new("ImageLabel", { Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1,
                Image = tostring(img), LayoutOrder = i }, traitsRow))
        end
    end
    local traitsText = text(traitsRow, { Size = UDim2.new(1, -#traitIcons * 24, 1, 0), TextSize = 11,
        TextColor3 = TH.sub, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 99 })

    local line1 = text(card, { Position = UDim2.fromOffset(138, 88), Size = UDim2.new(1, -150, 0, 16),
        TextSize = 11, TextColor3 = TH.sub, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
    local line2 = text(card, { Position = UDim2.fromOffset(138, 106), Size = UDim2.new(1, -150, 0, 16),
        TextSize = 11, TextColor3 = TH.sub, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })

    -- botões
    local isMap = e.kind == "Mapa" and e.id ~= nil
    local ui = { card = card, cam = cam, center = center, radius = radius, angle = math.random() * math.pi * 2 }
    ui.flyBtn, ui.flyLabel = pillButton(card, T("Voar"), "plain", { Position = UDim2.fromOffset(10, 134),
        Size = UDim2.fromOffset(116, 28) })
    ui.collectBtn, ui.collectLabel = pillButton(card, isMap and T("Coletar") or T("Só no mapa"), isMap and "green" or "plain",
        { Position = UDim2.fromOffset(138, 134), Size = UDim2.new(0.5, -82, 0, 28) })
    local moreBtn = pillButton(card, T("Detalhes"), "plain", { AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 134), Size = UDim2.new(0.5, -82, 0, 28) })
    if not isMap then ui.collectLabel.TextColor3 = TH.sub end
    ui.seq = 0

    local details = text(card, { Position = UDim2.fromOffset(12, 172), Size = UDim2.new(1, -24, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11, TextColor3 = TH.sub, Visible = false,
        TextYAlignment = Enum.TextYAlignment.Top })
    new("UIPadding", { PaddingBottom = UDim.new(0, 12) }, details)

    ui.flyBtn.Activated:Connect(safe("voar", function() startEggJob(ui.e, ui, "fly") end))
    ui.collectBtn.Activated:Connect(safe("coletar", function()
        if isMap then startEggJob(ui.e, ui, "collect") end
    end))
    moreBtn.Activated:Connect(function()
        details.Visible = not details.Visible
        moreBtn.Text = details.Visible and T("Fechar") or T("Detalhes")
    end)

    function ui.update(ev, hrp)
        ui.e = ev
        local full, _, rcolor, timerTxt, dist = eggInfo(ev, hrp)
        local a = type(ev.index) == "string" and AnimalsData[ev.index] or nil
        ev.displayName = a and a.DisplayName or ev.index
        name.Text = esc(ev.displayName or T("Ovo"))
        name.TextColor3 = rcolor
        cardStroke.Color = rcolor
        -- raridade (cor do jogo)
        local rarity = a and a.Rarity or (ev.overhead and ev.overhead.rarity)
        rarityChip.Visible = rarity ~= nil
        rarityLabel.Text = tostring(rarity or "")
        rarityLabel.TextColor3 = rcolor
        -- mutação: ícone do jogo + nome colorido (Datas.Mutations)
        mutChip.Visible = ev.mutation ~= nil
        if ev.mutation then
            mutLabel.Text = mutationRich(ev.mutation) or tostring(ev.mutation)
            local ic = mutationIcon(ev.mutation)
            mutIcon.Visible = ic ~= nil
            if ic then mutIcon.Image = tostring(ic) end
        end
        -- "Some em": o servidor manda o tempo de vez em quando; aqui ele conta
        -- de 1 em 1 segundo e se acerta quando chega um valor novo
        if type(ev.despawn) == "number" then
            if ev.despawn ~= ui.despawnRaw then
                ui.despawnRaw, ui.despawnAt = ev.despawn, os.clock()
            end
            local left = math.max(0, ui.despawnRaw - (os.clock() - ui.despawnAt))
            goneChip.Visible = true
            goneLabel.Text = T("Some em ") .. esc(fmtTime(left))
        else
            goneChip.Visible = false
        end
        -- traits
        local names = {}
        for _, t in ipairs(ev.traits) do table.insert(names, traitRich(t)) end
        traitsText.Text = #names > 0 and table.concat(names, ", ") or T("Sem traits")
        -- linhas
        local where = ev.kind == "Plot" and (T("Plot de ") .. esc(ev.owner))
            or (ev.grabbed and ('<font color="#FF5566">' .. T("Pego por alguém") .. '</font>') or T("No mapa · livre"))
        line1.Text = where .. (dist and T("  ·  %.0f studs", dist) or "")
        local hatch = ""
        if a and type(a.Egg) == "table" and type(a.Egg.Animals) == "table" then
            local out = {}
            for _, x in ipairs(a.Egg.Animals) do
                if type(x) == "table" and x.Name then
                    local ad = AnimalsData[x.Name]
                    table.insert(out, esc(ad and ad.DisplayName or x.Name) .. " " .. tostring(x.Chance or "?") .. "%")
                end
            end
            hatch = table.concat(out, ", ")
        end
        line2.Text = hatch ~= "" and (T("Contém: ") .. hatch) or ""
        if details.Visible then details.Text = full end
        details.Text = full
        -- ordem fixa (raridade mais alta primeiro, depois a ordem em que apareceu):
        -- antes era pela distância e os cards trocavam de lugar o tempo todo
        local rd = rarity and RaritiesData[rarity]
        card.LayoutOrder = -((rd and rd.Weight or 0) * 100000) + ui.seq
    end
    return ui
end

-- ─── REFRESH (ESP + HUB) ─────────────────────────────────────────────────────
local entries = {}
local cardSeq = 0
local passesFilter = function() return true end -- trocado pelo filtro mais abaixo

local function clearEntry(key)
    local ent = entries[key]
    if not ent then return end
    if ent.esp then pcall(function() ent.esp.hl:Destroy(); ent.esp.bb:Destroy() end) end
    if ent.ui then
        pcall(function() ent.ui.card:Destroy() end)
    end
    entries[key] = nil
end

local function refresh()
    local _, hrp = getChar()
    local all = collectEggs()
    local list = {}
    for _, e in ipairs(all) do
        if passesFilter(e) then table.insert(list, e) end
    end
    local seen = {}
    local plots, mapa = 0, 0
    for _, e in ipairs(list) do
        seen[e.key] = true
        if e.kind == "Plot" then plots = plots + 1 else mapa = mapa + 1 end
        local ent = entries[e.key]
        if not ent then ent = {}; entries[e.key] = ent end
        local _, short, rcolor, timerTxt, dist = eggInfo(e, hrp)

        if toggles.esp then
            ent.esp = ent.esp or makeEsp(e)
            ent.esp.hl.FillColor = rcolor
            ent.esp.hl.OutlineColor = rcolor
            ent.esp.label.Text = T("%s\n%s%s", short,
                timerTxt and (esc(timerTxt) .. "  ") or "", dist and T("%.0f studs", dist) or "")
        elseif ent.esp then
            pcall(function() ent.esp.hl:Destroy(); ent.esp.bb:Destroy() end)
            ent.esp = nil
        end

        if toggles.hub then
            if not ent.ui then
                cardSeq = cardSeq + 1
                ent.ui = makeCard(e)
                ent.ui.seq = cardSeq
            end
            ent.ui.update(e, hrp)
        elseif ent.ui then
            pcall(function() ent.ui.card:Destroy() end)
            ent.ui = nil
        end
    end
    for key in pairs(entries) do
        if not seen[key] then clearEntry(key) end
    end
    emptyLabel.Visible = #list == 0
    hubSub.Text = T("%d ovos  ·  %d no mapa  ·  %d em plots", #list, mapa, plots)
        .. (filter.enabled and T("  ·  filtro: %d de %d", #list, #all) or "")
    emptyLabel.Text = (filter.enabled and #all > 0) and T("Nenhum ovo passa no filtro agora.") or T("Nenhum ovo no servidor agora.")
end

task.spawn(function()
    while alive do
        if toggles.esp or toggles.hub then
            local ok, err = pcall(refresh)
            if not ok then log("refresh erro:", err) end
        end
        task.wait(0.5)
    end
    for key in pairs(entries) do clearEntry(key) end
end)

table.insert(conns, RunService.RenderStepped:Connect(safe("preview", function(dt)
    if not toggles.hub then return end
    for _, ent in pairs(entries) do
        local ui = ent.ui
        if ui then
            ui.angle = ui.angle + dt * 0.8
            local d = ui.radius / math.tan(math.rad(ui.cam.FieldOfView / 2)) * 1.1
            ui.cam.CFrame = CFrame.lookAt(ui.center + Vector3.new(math.sin(ui.angle) * d, ui.radius * 0.4,
                math.cos(ui.angle) * d), ui.center)
        end
    end
end)))

-- ═══ FILTRO DE OVOS ══════════════════════════════════════════════════════════
-- Com o filtro ligado, só aparecem (no hub e no ESP) os ovos que passam em TODAS
-- as categorias marcadas. Categoria sem nada marcado não filtra.
--   Ovos: nome exato do ovo (Datas.Animals) · Raridades · Mutações ("Sem mutação" = normal)
local NO_MUTATION = "__none"
local filterToggleOpt -- toggle da janela principal (pra sincronizar)
local filterChanged   -- avisa o painel pra repintar

local function filterCount()
    local n = 0
    for _, set in ipairs({ filter.eggs, filter.rarities, filter.mutations }) do
        for _, v in pairs(set) do if v then n = n + 1 end end
    end
    return n
end

passesFilter = function(e)
    if not filter.enabled then return true end
    local a = type(e.index) == "string" and AnimalsData[e.index] or nil
    if next(filter.eggs) and not filter.eggs[e.index] then return false end
    if next(filter.rarities) then
        local r = a and a.Rarity or (e.overhead and e.overhead.rarity)
        if not (r and filter.rarities[r]) then return false end
    end
    if next(filter.mutations) then
        if not filter.mutations[e.mutation or NO_MUTATION] then return false end
    end
    return true
end

local saveQueued = false
local function filterUpdated()
    if filterChanged then pcall(filterChanged) end
    pcall(refresh)
    if not saveQueued then -- junta vários cliques num save só
        saveQueued = true
        task.delay(1, function() saveQueued = false; saveConfig() end)
    end
end

local function setFilterEnabled(v, fromMain)
    filter.enabled = v == true
    if filterToggleOpt and not fromMain then pcall(function() filterToggleOpt:SetValue(filter.enabled, false) end) end
    filterUpdated()
end

-- listas pro painel
local EGG_LIST, RARITY_LIST, MUTATION_LIST = {}, {}, {}
for idx, a in pairs(AnimalsData) do
    if type(a) == "table" and type(a.Egg) == "table" then table.insert(EGG_LIST, idx) end
end
local function rarityWeight(r) local d = RaritiesData[r]; return d and d.Weight or 0 end
table.sort(EGG_LIST, function(x, y)
    local rx, ry = rarityWeight(AnimalsData[x].Rarity), rarityWeight(AnimalsData[y].Rarity)
    if rx ~= ry then return rx > ry end
    return tostring(x) < tostring(y)
end)
for r in pairs(RaritiesData) do table.insert(RARITY_LIST, r) end
table.sort(RARITY_LIST, function(x, y) return rarityWeight(x) < rarityWeight(y) end)
for m, d in pairs(MutationsData) do
    if type(d) == "table" then table.insert(MUTATION_LIST, m) end
end
table.sort(MUTATION_LIST, function(x, y)
    local ox = MutationsData[x].Order or 999
    local oy = MutationsData[y].Order or 999
    if ox ~= oy then return ox < oy end
    return tostring(x) < tostring(y)
end)
table.insert(MUTATION_LIST, 1, NO_MUTATION)

-- ─── PAINEL ──────────────────────────────────────────────────────────────────
local BrainrotAssets = tryRequire("Shared", "BrainrotAssets")
local filterGui = newProtectedGui("V3ntJumpForEggFilter")
local filterScale = new("UIScale", { Scale = 1 }, filterGui)
do
    local function rs()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        filterScale.Scale = math.clamp(math.min(vp.X / 720, vp.Y / 640), 0.5, 1)
    end
    rs()
    pcall(function() workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rs) end)
end

local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(600, 540), BackgroundColor3 = TH.bg, BorderSizePixel = 0, Visible = false,
    Active = true, ClipsDescendants = true }, filterGui)
corner(panel, 14)
outline(panel, TH.stroke, 1)
local ptop = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = TH.panel, BorderSizePixel = 0,
    Active = true }, panel)
corner(ptop, 14)
new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = TH.panel,
    BorderSizePixel = 0 }, ptop)
do
    local line = new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, ptop)
    U.accentGradient(line)
end
local pTitle = text(ptop, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -220, 0, 20), Text = T("Filtro de ovos"),
    FontFace = U.FONT_HEAVY, TextSize = 15 })
reg(pTitle, "Filtro de ovos")
local pSub = text(ptop, { Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -220, 0, 16), Text = "",
    TextColor3 = TH.sub, TextSize = 11 })
U.draggable(ptop, panel)

-- switch "Ativo" no topo
local onLabel = text(ptop, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0),
    Size = UDim2.fromOffset(60, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Right,
    FontFace = U.FONT_BOLD, TextSize = 12, TextColor3 = TH.sub })
reg(onLabel, "Ativo")
local pill = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -54, 0.5, 0),
    Size = UDim2.fromOffset(40, 22), BackgroundColor3 = TH.off, AutoButtonColor = false, Text = "",
    BorderSizePixel = 0 }, ptop)
corner(pill, 11)
local pillGrad = U.accentGradient(pill)
pillGrad.Enabled = false
local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
    Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, pill)
corner(knob, 8)
pill.Activated:Connect(function() setFilterEnabled(not filter.enabled) end)
local pClose = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -1),
    Size = UDim2.fromOffset(30, 30), BackgroundColor3 = TH.card, AutoButtonColor = false, Text = T("×"),
    FontFace = U.FONT_BOLD, TextSize = 18, TextColor3 = TH.sub, BorderSizePixel = 0 }, ptop)
corner(pClose, 15)
pClose.Activated:Connect(function() panel.Visible = false end)

local body = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -104),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = TH.accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y }, panel)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, body)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14),
    PaddingRight = UDim.new(0, 16) }, body)

-- rodapé
local foot = new("Frame", { Position = UDim2.new(0, 0, 1, -50), Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = TH.panel, BorderSizePixel = 0 }, panel)
local footHint = text(foot, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -260, 1, 0), TextSize = 11,
    TextColor3 = TH.sub, Text = "" })
reg(footHint, "Categoria sem nada marcado = mostra todos dela.")

local panelOrder = 0
local function sectionTitle(key, ...)
    panelOrder = panelOrder + 1
    local l = text(body, { Size = UDim2.new(1, 0, 0, 20), Text = "", FontFace = U.FONT_BOLD,
        TextSize = 11, TextColor3 = TH.accent, LayoutOrder = panelOrder })
    return reg(l, key, ...)
end
-- grade com altura calculada pelo próprio layout (sem AutomaticSize, que fazia
-- as grades se sobreporem em algumas telas)
local function grid(cell)
    panelOrder = panelOrder + 1
    local g = new("Frame", { Size = UDim2.new(1, 0, 0, cell.Y.Offset), BackgroundTransparency = 1,
        LayoutOrder = panelOrder }, body)
    local layout = new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(8, 8),
        SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = 0 }, g)
    local function fit() g.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 2) end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
    task.defer(fit)
    return g
end

local selectables = {} -- { paint = fn }
-- item selecionável (chip ou card): borda e fundo mudam quando marcado
local function selectable(parent, order, set, key)
    local b = new("TextButton", { BackgroundColor3 = TH.card, AutoButtonColor = false, Text = "",
        BorderSizePixel = 0, LayoutOrder = order }, parent)
    corner(b, 10)
    local st = outline(b, TH.stroke, 1.5)
    local check = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Visible = false, ZIndex = 5 }, b)
    corner(check, 7)
    U.accentGradient(check, 45)
    local function paint()
        local on = set[key] == true
        st.Color = on and TH.accent or TH.stroke
        b.BackgroundColor3 = on and TH.cardHover or TH.card
        check.Visible = on
    end
    b.Activated:Connect(function()
        set[key] = not set[key] or nil
        paint()
        filterUpdated()
    end)
    paint()
    table.insert(selectables, paint)
    return b
end

-- Raridades
sectionTitle("RARIDADES")
do
    local g = grid(UDim2.fromOffset(130, 34))
    for i, r in ipairs(RARITY_LIST) do
        local b = selectable(g, i, filter.rarities, r)
        local rd = RaritiesData[r]
        text(b, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -30, 1, 0), Text = r,
            FontFace = U.FONT_BOLD, TextSize = 12, TextColor3 = rd and rd.Color or TH.text, TextWrapped = false,
            TextTruncate = Enum.TextTruncate.AtEnd })
    end
end

-- Mutações (com o ícone do jogo)
sectionTitle("MUTAÇÕES")
do
    local g = grid(UDim2.fromOffset(130, 34))
    for i, m in ipairs(MUTATION_LIST) do
        local b = selectable(g, i, filter.mutations, m)
        local ic = m ~= NO_MUTATION and mutationIcon(m) or nil
        if ic then
            new("ImageLabel", { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(20, 20),
                BackgroundTransparency = 1, Image = tostring(ic) }, b)
        end
        local lab = text(b, { Position = UDim2.fromOffset(ic and 32 or 10, 0), Size = UDim2.new(1, ic and -52 or -30, 1, 0),
            Text = m == NO_MUTATION and T("Sem mutação") or (mutationRich(m) or m), FontFace = U.FONT_BOLD,
            TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
        if m == NO_MUTATION then reg(lab, "Sem mutação") end
    end
end

-- Ovos (com preview 3D)
sectionTitle("OVOS (%d)", #EGG_LIST)
local eggPreviews = {}
do
    local g = grid(UDim2.fromOffset(130, 158))
    for i, idx in ipairs(EGG_LIST) do
        local a = AnimalsData[idx]
        local rd = RaritiesData[a.Rarity]
        local b = selectable(g, i, filter.eggs, idx)
        b.ClipsDescendants = true
        local vp = new("ViewportFrame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 92),
            BackgroundColor3 = TH.panel, BorderSizePixel = 0, Ambient = Color3.fromRGB(210, 210, 210),
            LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1) }, b)
        corner(vp, 8)
        local loading = text(vp, { Size = UDim2.fromScale(1, 1), Text = "...", TextColor3 = TH.sub,
            TextXAlignment = Enum.TextXAlignment.Center })
        -- nome: no máximo 2 linhas, encolhe se precisar (não invade a linha da raridade)
        local nameL = text(b, { Position = UDim2.fromOffset(8, 104), Size = UDim2.new(1, -16, 0, 30),
            Text = esc(a.DisplayName or idx), FontFace = U.FONT_BOLD, TextSize = 11, TextScaled = true,
            TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd })
        new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8 }, nameL)
        text(b, { Position = UDim2.fromOffset(8, 136), Size = UDim2.new(1, -16, 0, 14), Text = tostring(a.Rarity or ""),
            TextSize = 10, TextColor3 = rd and rd.Color or TH.sub, FontFace = U.FONT_BOLD, TextWrapped = false,
            TextTruncate = Enum.TextTruncate.AtEnd })
        table.insert(eggPreviews, { vp = vp, index = idx, loaded = false, loading = loading })
    end
end

-- Modelo do ovo pro preview. Cada fonte tem limite de tempo (algumas funções do
-- jogo esperam o download do modelo e travavam todos os previews). Ordem:
--   1) um ovo igual que já esteja no mapa ou num plot (o mais rápido)
--   2) Shared.Animals:GetAnimatedModel(nome, "Idle") (WorldBrainrotController:92)
--   3) Shared.BrainrotAssets.getModel(nome)
--   4) ReplicatedStorage.Models.Animals[nome]
local SharedAnimals = tryRequire("Shared", "Animals")
local function withTimeout(fn, seconds)
    local done, result = false, nil
    task.spawn(function()
        local ok, r = pcall(fn)
        if ok then result = r end
        done = true
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < seconds do task.wait(0.05) end
    return result
end
local function findEggModel(index)
    for _, e in ipairs(collectEggs()) do
        if e.index == index and e.model and e.model.Parent then return e.model, false end
    end
    if SharedAnimals and type(SharedAnimals.GetAnimatedModel) == "function" then
        local m = withTimeout(function() return SharedAnimals:GetAnimatedModel(index, "Idle") end, 3)
        if typeof(m) == "Instance" then return m, true end
    end
    if BrainrotAssets and type(BrainrotAssets.getModel) == "function" then
        local m = withTimeout(function() return BrainrotAssets.getModel(index) end, 3)
        if typeof(m) == "Instance" then return m, false end
    end
    local found
    pcall(function()
        local mf = ReplicatedStorage:FindFirstChild("Models")
        local an = mf and mf:FindFirstChild("Animals")
        found = an and an:FindFirstChild(index)
    end)
    if found then return found, false end
    return nil
end

-- deixa só o visual (sem scripts, GUIs, sons) e ancorado
local function previewOnly(m)
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui")
            or d:IsA("SurfaceGui") or d:IsA("Highlight") or d:IsA("Sound") then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
        end
    end
    return m
end

-- carrega os previews só quando o painel abre (o jogo pode baixar o modelo)
local function loadPreview(p)
    if p.loaded then return end
    p.loaded = true
    task.spawn(function()
        local ok, err = pcall(function()
            local model, isOwn = findEggModel(p.index)
            if not model then
                p.loading.Text = "?"
                p.loaded = false -- tenta de novo na próxima vez que abrir o painel
                return
            end
            local copy
            if isOwn then
                copy = previewOnly(model) -- modelo novo, já é nosso
            else
                local old = model.Archivable
                model.Archivable = true
                local okc, c = pcall(function() return model:Clone() end)
                model.Archivable = old
                copy = okc and c and previewOnly(c) or nil
            end
            if not copy then p.loading.Text = "?" return end
            if copy:IsA("BasePart") then
                local holder = Instance.new("Model")
                copy.Parent = holder
                copy = holder
            end
            local cam = new("Camera", { FieldOfView = 40 }, p.vp)
            p.vp.CurrentCamera = cam
            local world = new("WorldModel", {}, p.vp)
            copy.Parent = world
            pcall(function() copy:PivotTo(CFrame.new()) end)
            local cf, size = copy:GetBoundingBox()
            p.center, p.radius, p.cam = cf.Position, math.max(size.Magnitude / 2, 0.5), cam
            p.angle = math.random() * math.pi * 2
            p.loading.Visible = false
        end)
        if not ok then
            log("preview de", p.index, "falhou:", err)
            pcall(function() p.loading.Text = "?" end)
        end
    end)
end

table.insert(conns, RunService.RenderStepped:Connect(safe("filter preview", function(dt)
    if not panel.Visible then return end
    for _, p in ipairs(eggPreviews) do
        if p.cam then
            p.angle = p.angle + dt * 0.7
            local d = p.radius / math.tan(math.rad(20)) * 1.1
            p.cam.CFrame = CFrame.lookAt(p.center + Vector3.new(math.sin(p.angle) * d, p.radius * 0.4,
                math.cos(p.angle) * d), p.center)
        end
    end
end)))

-- botões do rodapé
do
    local clear, clearL = pillButton(foot, T("Limpar tudo"), "plain", { AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -132, 0.5, 0), Size = UDim2.fromOffset(110, 30) })
    reg(clearL, "Limpar tudo")
    clear.Activated:Connect(function()
        -- limpa os conjuntos no lugar (os botões guardam a referência deles)
        for _, set in ipairs({ filter.eggs, filter.rarities, filter.mutations }) do
            for k in pairs(set) do set[k] = nil end
        end
        filterUpdated()
    end)
    local done, doneL = pillButton(foot, T("Pronto"), "green", { AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(110, 30) })
    reg(doneL, "Pronto")
    done.Activated:Connect(function() panel.Visible = false end)
end

filterChanged = function()
    for _, paint in ipairs(selectables) do paint() end
    pillGrad.Enabled = filter.enabled
    tween(pill, 0.18, { BackgroundColor3 = filter.enabled and Color3.new(1, 1, 1) or TH.off })
    tween(knob, 0.18, { Position = UDim2.new(0, filter.enabled and 21 or 3, 0.5, 0) })
    onLabel.TextColor3 = filter.enabled and TH.text or TH.sub
    local ne, nr, nm = 0, 0, 0
    for _ in pairs(filter.eggs) do ne = ne + 1 end
    for _ in pairs(filter.rarities) do nr = nr + 1 end
    for _ in pairs(filter.mutations) do nm = nm + 1 end
    pSub.Text = T("%s  ·  %d ovos  ·  %d raridades  ·  %d mutações marcadas", 
        filter.enabled and T("Ligado") or T("Desligado"), ne, nr, nm)
end
filterChanged()

local function openFilterPanel()
    panel.Visible = true
    for _, p in ipairs(eggPreviews) do loadPreview(p) end
end

-- ═══ TRAMPOLIM: STATUS + AUTO UPGRADE ════════════════════════════════════════
-- Lê o que o próprio jogo mostra (só leitura):
--   PlayerGui.TrampolineSignGui (JumpLTMController:1095): Title "TRAMPOLINE x/y",
--     Upgrade.Price, LockOverlay (level necessário)
--   PlayerGui.JumpLTMLevel (JumpLTMLevelController:180): "Level N a/b XP"
--   Map.BaseTrampolines: pad (tag JumpPad) perto da placa → atributo JumpForce
local function plain(t) return (tostring(t or ""):gsub("<[^>]->", "")) end

local readTrampoline = LPH_ENCFUNC(function()
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    local info = {}
    local pg = LP:FindFirstChild("PlayerGui")
    local sign = pg and pg:FindFirstChild("TrampolineSignGui")
    if sign then
        info.found = true
        local title = sign:FindFirstChild("Title")
        local t = title and plain(title.Text) or ""
        info.tier, info.maxTier = t:match("(%d+)%s*/%s*(%d+)")
        info.tier, info.maxTier = tonumber(info.tier), tonumber(info.maxTier)
        info.isMax = t:find("MAX") ~= nil
        local up = sign:FindFirstChild("Upgrade")
        info.upgradeVisible = up and up.Visible or false
        local price = up and up:FindFirstChild("Price")
        info.price = price and plain(price.Text) or nil
        local lock = sign:FindFirstChild("LockOverlay")
        info.locked = lock and lock.Visible or false
        local req = lock and lock:FindFirstChild("Rebirth")
        info.reqLevel = req and tonumber(plain(req.Text):match("(%d+)")) or nil
    end
    local bar = pg and pg:FindFirstChild("JumpLTMLevel")
    local label = bar and bar:FindFirstChild("Label", true)
    if label and label:IsA("TextLabel") then
        local p = plain(label.Text)
        info.level = tonumber(p:match("Level%s*(%d+)"))
        local a, b = p:match("(%d+)%s*/%s*(%d+)")
        info.xp, info.xpNeed = tonumber(a), tonumber(b)
        info.levelMax = p:find("MAX") ~= nil
    end
    pcall(function()
        local plot = getOwnPlot()
        info.order = plot and plot:GetAttribute("Order")
        local map = workspace:FindFirstChild("Map")
        local bt = map and map:FindFirstChild("BaseTrampolines")
        local signModel = bt and info.order and bt:FindFirstChild(("TrampolineSign%s"):format(tostring(info.order)))
        local signPart = signModel and signModel:FindFirstChild("Sign")
        if signPart then
            local best, bestD
            for _, pad in ipairs(CollectionService:GetTagged("JumpPad")) do
                if pad:IsA("BasePart") and pad:IsDescendantOf(bt) then
                    local d = (pad.Position - signPart.Position).Magnitude
                    if not bestD or d < bestD then best, bestD = pad, d end
                end
            end
            if best and bestD < 80 then info.jumpForce = best:GetAttribute("JumpForce") or 150 end
        end
    end)
    return info
end, LPH_KEY, get_key())

local upgradesDone, lastTier, lastUpgradeAt = 0, nil, 0
local trampolineHook -- a janela principal liga isso no texto do trampolim

local function trampolineText(info)
    if not info.found then
        return T("Trampolim: a placa só aparece no servidor do Jump for Eggs (e depois de você ter um plot).")
    end
    local L = {}
    if info.isMax then
        table.insert(L, T("Trampolim: tier %s (MÁXIMO)", tostring(info.maxTier or info.tier or "?")))
    else
        table.insert(L, T("Trampolim: tier %s de %s", tostring(info.tier or "?"), tostring(info.maxTier or "?")))
        local nextTxt = T("Próximo upgrade: ") .. (info.price or "?")
        if info.reqLevel then
            nextTxt = nextTxt .. T(" · precisa level %d%s", info.reqLevel, info.locked and T(" (bloqueado)") or "")
        end
        table.insert(L, nextTxt)
    end
    if info.level then
        if info.levelMax then
            table.insert(L, T("Seu level: %d (MÁXIMO)", info.level))
        else
            table.insert(L, T("Seu level: %d · %s/%s XP", info.level, tostring(info.xp or "?"), tostring(info.xpNeed or "?")))
        end
    end
    if info.jumpForce then table.insert(L, T("Força do pulo: %s", tostring(info.jumpForce))) end
    table.insert(L, T("Auto upgrade: %s · %d upgrade(s) nesta sessão", 
        toggles.upgrade and T("ligado") or T("desligado"), upgradesDone))
    return table.concat(L, "\n")
end

task.spawn(LPH_ENCFUNC(function()
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    while alive do
        local ok, err = pcall(function()
            local info = readTrampoline()
            if info.tier then
                if lastTier and info.tier > lastTier then
                    notify(T("Trampolim subiu pro tier %d!", info.tier), "ok", 6)
                end
                lastTier = info.tier
            end
            -- auto upgrade: só quando a placa do jogo libera (botão visível, sem trava de level)
            if toggles.upgrade and upgradeRemote and info.found and not info.isMax and info.upgradeVisible
                and not info.locked and info.order ~= nil and os.clock() - lastUpgradeAt >= 3 then
                lastUpgradeAt = os.clock()
                upgradeRemote:FireServer(info.order)
                upgradesDone = upgradesDone + 1
                log("RequestTrampolineUpgrade", info.order)
            end
            if trampolineHook then trampolineHook(trampolineText(info)) end
        end)
        if not ok then log("erro no trampolim:", err) end
        task.wait(1)
    end
end, LPH_KEY, get_key()))

-- ═══ AUTO COLOCAR OVO / BRAINROT ═════════════════════════════════════════════
local autoPlaceWarnAt = 0
task.spawn(LPH_ENCFUNC(function()
    LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
    while alive do
        task.wait(1)
        pcall(function()
            -- Ovo: só se carregando (CarryingJumpEgg) e no próprio plot; não atrapalha a coleta
            if toggles.egg and eggRemote and not currentJob and LP:GetAttribute("CarryingJumpEgg") == true and onOwnPlot() then
                local placed, why = placeEgg("(auto)")
                if placed then
                    setStatus(T("Ovo colocado."))
                    successNotify(T("Ovo colocado no seu plot!"))
                elseif why == "rejected" and os.clock() - (autoPlaceWarnAt or 0) > 20 then
                    autoPlaceWarnAt = os.clock() -- não repete o aviso toda hora
                    placeProblem(why)
                end
            end
            -- Brainrot: só se carregando (CarryingBaseBrainrot) e no próprio plot
            if toggles.brainrot and brainRemote and LP:GetAttribute("CarryingBaseBrainrot") == true and onOwnPlot() then
                brainRemote:FireServer()
                log("RequestBrainrotPlace (auto)")
                setStatus(T("Brainrot colocado."))
            end
        end)
    end
end, LPH_KEY, get_key()))

-- ═══ JANELA PRINCIPAL ════════════════════════════════════════════════════════
local mainGui = newProtectedGui("V3ntJumpForEggWindow")

local function shutdown()
    alive = false
    pcall(cancelJob)
    pcall(Fly.stop)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, g in ipairs({ sg, hubGui, mainGui, filterGui }) do pcall(function() g:Destroy() end) end
end

local hubToggleOpt
hubClose.Activated:Connect(function()
    if hubToggleOpt then hubToggleOpt:SetValue(false) else toggles.hub = false; hub.Visible = false end
end)

local mainWindow
local LANGS = {
    { code = "pt", name = "Português" },
    { code = "en", name = "English" },
    { code = "es", name = "Español" },
}
local setLanguage -- definida depois do buildMainUI

local function buildMainUI()
    -- limpa uma janela anterior (troca de idioma recria a janela)
    if mainWindow then pcall(function() mainWindow:Destroy() end) end
    for _, c in ipairs(mainGui:GetChildren()) do
        if c:IsA("UIScale") then c:Destroy() end
    end
    local UI = V3ntUI.new(mainGui)
    local window = UI:CreateWindow({ Name = "V3nt - Jump For Egg" })
    mainWindow = window

    -- Ovos
    local eggTab = window:CreateTab({ Name = T("Ovos") })
    local vis = eggTab:CreateSection({ Name = T("Visual") })
    vis:CreateToggle({ Name = T("ESP de ovos"), Note = T("Contorno, nome, mutação, traits e timer em cada ovo."),
        Default = toggles.esp, Callback = function(v) toggles.esp = v; pcall(refresh) end })
    hubToggleOpt = vis:CreateToggle({ Name = T("Hub de ovos"), Note = T("Lista com preview 3D, voar e coletar."),
        Default = toggles.hub, Callback = function(v) toggles.hub = v; hub.Visible = v; pcall(refresh) end })

    local flySec = eggTab:CreateSection({ Name = T("Fly") })
    flySec:CreateInput({ Name = T("Velocidade do fly"), Note = T("De 10 a 999. Fica salva em workspace/") .. CONFIG_FILE,
        Default = tostring(config.flySpeed), Placeholder = "60", MaxLength = 4,
        Callback = function(v)
            local n = tonumber(v)
            if not n then return notify(T("Velocidade inválida."), "warn", 4) end
            config.flySpeed = math.clamp(math.floor(n), 10, 999)
            if saveConfig() then
                notify(T("Velocidade %d salva.", config.flySpeed), "ok", 4)
            else
                notify(T("Velocidade %d (o executor não deixou salvar o arquivo).", config.flySpeed), "warn", 5)
            end
        end })
    flySec:CreateButton({ Name = T("Parar voo"), Note = T("Cancela e leva pro chão se estiver no ar."),
        ButtonText = T("Parar"), Callback = function() cancelJob() end })
    flySec:CreateButton({ Name = T("Pousar"), Note = T("Vai pra ilha mais próxima (ou pro seu plot)."),
        ButtonText = T("Pousar"), Callback = function() task.spawn(Fly.landSafe) end })

    -- Filtro
    local filterTab = window:CreateTab({ Name = T("Filtro") })
    local fsec = filterTab:CreateSection({ Name = T("Filtro de ovos") })
    filterToggleOpt = fsec:CreateToggle({ Name = T("Filtro ativo"),
        Note = T("Só mostra no hub e no ESP os ovos que passam no filtro."), Default = filter.enabled,
        Callback = function(v) setFilterEnabled(v, true) end })
    fsec:CreateButton({ Name = T("Escolher ovos, raridades e mutações"), Note = T("Abre o painel com todos os ovos do jogo."),
        ButtonText = T("Abrir"), Callback = function() openFilterPanel() end })

    -- Base
    local baseTab = window:CreateTab({ Name = T("Base") })
    local auto = baseTab:CreateSection({ Name = T("Automático") })
    local function remoteToggle(name, note, key, remote)
        auto:CreateToggle({ Name = name, Note = remote and note or (note .. T(" (remote não encontrada)")),
            Default = toggles[key],
            Callback = function(v)
                if v and not remote then notify(name .. T(": remote não encontrada no jogo."), "err", 5) end
                toggles[key] = v and remote ~= nil
            end })
    end
    remoteToggle(T("Auto colocar ovo"), T("Coloca o ovo que você carrega quando estiver no seu plot."), "egg", eggRemote)
    remoteToggle(T("Auto colocar brainrot"), T("Coloca o brainrot que você carrega no seu plot."), "brainrot", brainRemote)
    remoteToggle(T("Auto upgrade trampolim"), T("Compra o próximo tier quando a placa do jogo liberar."), "upgrade", upgradeRemote)
    local manual = baseTab:CreateSection({ Name = T("Manual") })
    manual:CreateButton({ Name = T("Colocar ovo agora"), Note = T("Coloca o ovo que você está carregando no seu plot."),
        ButtonText = T("Colocar"), Callback = function()
            if LP:GetAttribute("CarryingJumpEgg") ~= true then
                return notifyProblem(T("Você não está carregando nenhum ovo"), T("Pegue um ovo (botão Coletar no hub) e tente de novo."), "warn", 6)
            end
            if not onOwnPlot() then
                return notifyProblem(T("Você não está em cima do seu plot"), T("Ande até o chão do seu plot e clique de novo."), "warn", 6)
            end
            task.spawn(function()
                local placed, why = placeEgg("(manual)")
                if placed then
                    successNotify(T("Ovo colocado no seu plot!"))
                else
                    placeProblem(why)
                end
            end)
        end })

    -- Status
    local statusTab = window:CreateTab({ Name = T("Status") })
    local trampSec = statusTab:CreateSection({ Name = T("Trampolim") })
    local trampText = trampSec:CreateText({ Text = T("Lendo o trampolim...") })
    trampolineHook = function(t) trampText:SetText(t) end
    local geral = statusTab:CreateSection({ Name = T("Geral") })
    local statusText = geral:CreateText({ Text = T("Pronto.") })
    local lastS = 0
    statusHook = function(msg)
        if os.clock() - lastS < 0.3 then return end
        lastS = os.clock()
        statusText:SetText(msg)
    end
    geral:CreateText({ Text = T("Remotes: Ovo %s · Brainrot %s · Grab %s · Upgrade %s",
        eggRemote and "ok" or "X", brainRemote and "ok" or "X", grabRemote and "ok" or "X", upgradeRemote and "ok" or "X") })
    geral:CreateButton({ Name = T("Fechar script"), Note = T("Para tudo e fecha as janelas."), ButtonText = T("Fechar"),
        Callback = shutdown })

    -- Idioma
    local langTab = window:CreateTab({ Name = T("Idioma") })
    local lsec = langTab:CreateSection({ Name = T("Idioma") })
    for _, l in ipairs(LANGS) do
        local current = config.lang == l.code
        lsec:CreateButton({ Name = l.name, Note = current and T("Idioma atual") or T("Toque pra usar este idioma"),
            ButtonText = current and T("Em uso") or T("Usar"),
            Callback = function() setLanguage(l.code) end })
    end
    return true
end

setLanguage = function(code)
    if code == config.lang then return end
    config.lang = code
    saveConfig()
    -- textos fixos do hub e do filtro
    for _, r in ipairs(i18nLabels) do
        pcall(function() r[1].Text = T(r[2], table.unpack(r[3], 1, r[3].n)) end)
    end
    -- cards do hub são recriados (botões e rótulos no idioma novo)
    for key in pairs(entries) do clearEntry(key) end
    pcall(refresh)
    pcall(filterChanged)
    -- janela principal recriada
    local ok, err = pcall(buildMainUI)
    if not ok then log("erro ao recriar a janela:", err) end
    local langName = code
    for _, l in ipairs(LANGS) do if l.code == code then langName = l.name end end
    notify(T("Idioma alterado: %s", langName), "ok", 4)
end

local okUI, errUI = pcall(buildMainUI)
if not okUI then
    log("erro ao abrir a janela:", errUI)
    notify(T("A janela principal deu erro (veja F9)."), "err")
end
setStatus(T("Pronto."))
