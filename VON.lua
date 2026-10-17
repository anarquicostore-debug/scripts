-- ============================================================
-- VON CODE REDEEMER 
-- ============================================================

-- ── Serviços ─────────────────────────────────────────────────
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local Debris           = game:GetService("Debris")
local Lighting         = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")
local service      = ReplicatedStorage   -- o script original usa "service" = RS

-- ── Carrega Skibidi UI (loadstring6) ─────────────────────────
local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/blookzz/skibidi/refs/heads/main/UILib.lua"))()

-- ── vonCodeRedeemer (estrutura idêntica ao original) ─────────
local vonCodeRedeemer
do
    local env = (typeof(getgenv) == "function" and pcall(getgenv) and getgenv()) or shared or _G
    local existing = rawget(env, "VON_CODE_REDEEMER")
    if type(existing) == "table" and not existing.dead then
        local guiAlive = typeof(existing.gui) == "Instance" and existing.gui.Parent ~= nil
        local justStarted = existing.gui == nil and os.clock() - (tonumber(existing.startedAt) or 0) < 60
        if guiAlive or justStarted then
            warn("[VON] code redeemer is already running - not starting a second copy. Press RightShift to show or hide the panel.")
            if guiAlive then pcall(function() existing.gui.Enabled = true end) end
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "VON Code Redeemer",
                    Text = "Already running. RightShift toggles the panel.",
                    Duration = 4,
                })
            end)
            return
        end
        pcall(existing.unload, "superseded by a new execution")
    end

    vonCodeRedeemer = {
        dead      = false,
        startedAt = os.clock(),
        gui       = nil,
        onUnload  = {},
        lastText  = nil,
        lastTextAt = 0,
        lastCode  = nil,
        lastCodeAt = 0,
        addCleanup = function(fn)
            vonCodeRedeemer.onUnload[#vonCodeRedeemer.onUnload + 1] = fn
        end,
        unload = function(reason)
            if vonCodeRedeemer.dead then return end
            vonCodeRedeemer.dead = true
            for i = #vonCodeRedeemer.onUnload, 1, -1 do
                pcall(vonCodeRedeemer.onUnload[i])
            end
            vonCodeRedeemer.onUnload = {}
            warn("[VON] instance unloaded - " .. tostring(reason))
        end,
    }
    rawset(env, "VON_CODE_REDEEMER", vonCodeRedeemer)
end

-- ── premium = true (cracked – sem Luarmor) ───────────────────
local premium = true
local discord = "cracked"
local tbl32 = {
    dev      = true,
    premium  = true,
    discord  = discord,
    expires  = math.huge,
    version  = "0010",
    note     = "",
}

-- ── fn29: aplica accent derivado (idêntico ao original) ──────
local accent
local function fn29(accent2)
    if typeof(accent2) ~= "Color3" then return end
    local h, s, v2 = Color3.toHSV(accent2)
    local theme = lib.Theme
    theme.Accent    = accent2
    theme.AccentDim = Color3.fromHSV(h, s, math.max(v2 * 0.45, 0.05))
    theme.AccentSec = Color3.fromHSV(h, math.max(s * 0.65, 0), math.min(v2 * 1.3, 1))
    theme.ToggleOn  = Color3.fromHSV(h, s, math.max(v2 * 0.75, 0.08))
    theme.Knob      = theme.AccentSec
end
accent = lib.Theme.Accent

-- ── tbl21: gradient state ────────────────────────────────────
local tbl21 = { Enabled = false, Colour = Color3.fromRGB(120, 80, 220) }

-- ── tbl22: tema atual ────────────────────────────────────────
local tbl22 = { Name = "gold", Ready = false }

-- ── tbl23: config salva ──────────────────────────────────────
local tbl23 = {}
pcall(function()
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then return end
    if not isfile("von_autocode.json") then return end
    local data = HttpService:JSONDecode(readfile("von_autocode.json"))
    if type(data) ~= "table" then return end
    tbl23 = data
    if type(data.theme) == "string" and lib.Presets[data.theme:lower()] then
        tbl22.Name = data.theme:lower()
        lib.SetTheme(tbl22.Name)
        accent = lib.Theme.Accent
    end
    if type(data.accent) == "table" then
        local color = Color3.fromRGB(tonumber(data.accent.R) or 220, tonumber(data.accent.G) or 120, tonumber(data.accent.B) or 60)
        accent = color; fn29(color)
    end
    if data.accentGradient == true then tbl21.Enabled = true end
    if type(data.accentGradient2) == "table" then
        tbl21.Colour = Color3.fromRGB(tonumber(data.accentGradient2.R) or 120, tonumber(data.accentGradient2.G) or 80, tonumber(data.accentGradient2.B) or 220)
    end
    if tbl21.Enabled then
        lib.Theme.AccentGrad1 = lib.Theme.Accent
        lib.Theme.AccentGrad2 = tbl21.Colour
    end
end)

-- ── fn46: detecta http request do executor ───────────────────
local function fn46()
    if syn and typeof(syn.request) == "function" then return syn.request, "syn.request" end
    if http and typeof(http.request) == "function" then return http.request, "http.request" end
    if typeof(http_request) == "function" then return http_request, "http_request" end
    if typeof(request) == "function" then return request, "request" end
    if fluxus and typeof(fluxus.request) == "function" then return fluxus.request, "fluxus.request" end
    if typeof(httprequest) == "function" then return httprequest, "httprequest" end
    return nil, "none"
end

-- ── AI providers ─────────────────────────────────────────────
local tbl24 = { Cerebras = "cerebras", Groq = "groq", SambaNova = "sambanova", Gemini = "gemini" }
local tbl25 = { "Cerebras", "Groq", "SambaNova", "Gemini" }
local tbl36_urls = {
    cerebras  = "https://api.cerebras.ai/v1/chat/completions",
    groq      = "https://api.groq.com/openai/v1/chat/completions",
    sambanova = "https://api.sambanova.ai/v1/chat/completions",
}
local tbl26 = {
    cerebras  = "https://cloud.cerebras.ai/",
    groq      = "https://console.groq.com/keys",
    sambanova = "https://cloud.sambanova.ai/apis",
    gemini    = "https://aistudio.google.com/apikey",
}
local tbl27 = {
    cerebras  = { "gpt-oss-120b", "llama-3.3-70b", "llama3.1-8b" },
    groq      = { "openai/gpt-oss-20b" },
    sambanova = { "gpt-oss-120b" },
    gemini    = { "gemini-3.5-flash-lite", "gemini-3.7-flash", "gemini-3.1-flash-lite", "gemini-2.5-flash-lite", "gemini-3.6-flash", "gemini-3.5-flash", "gemini-2.5-flash" },
}

-- ── Estado AI / config ───────────────────────────────────────
local str9  = "groq"         -- provider
local str10 = ""             -- api key
local str11 = "openai/gpt-oss-20b" -- model preset
local str12 = ""             -- custom model id

local function fn30() -- modelo efectivo
    if str12 ~= "" then return str12 end
    if str11 ~= "" then return str11 end
    return (tbl27[str9] and tbl27[str9][1]) or "openai/gpt-oss-20b"
end

local function fn31() return game.GameId == 7709344486 end -- Steal a Brainrot

-- ── Estado de colecção ───────────────────────────────────────
local flag19 = true    -- autoCode
local v85    = true    -- useAI
local n32    = 3       -- submitAfter (code)
local n33    = 1       -- submitAfter (riddle)
local tbl28  = {}      -- early-submit positions

local tbl29 = {
    MinChars  = 20,
    MinSpaces = 1,
    InlineMin = 10,
    InlineCode = false,
}

-- tbl30 = triggers
local tbl30 = {
    "code is",
    "the code is",
    "use code",
    "question is",
    "", "", "", "", "", "",
}

local flag20 = false  -- colectando
local tbl35  = {}     -- segmentos colectados
local n37    = 0      -- total segmentos esperados
local str15  = nil    -- "code" | "riddle" | nil
local n38    = 0      -- segmentos prontos
local n39    = 0      -- segmentos recebidos
local n34    = 0      -- force-scan restante
local n35    = 0      -- pendente AI
local flag21 = false  -- force-scan ativo
local flag22 = false  -- force-AI ativo
local str13  = "firesignal"  -- entry method efectivo
local str14  = "childadded"  -- scan mode efectivo
local n40    = 0      -- geração (para descartar respostas AI velhas)
local module = nil    -- NotificationController

-- tbl31: config persistente
local tbl31 = {
    entryMethod  = (tbl23.entryMethod ~= nil and tbl23.entryMethod ~= "Firesignal") and "Remote" or "Firesignal",
    scanMode     = (tbl23.scanMode ~= nil and tbl23.scanMode ~= "ChildAdded") and "Controller" or "ChildAdded",
    antiRagdoll  = tbl23.antiRagdoll == true,
    autoBuy      = tbl23.autoBuy == true,
    anchorPlayer = tbl23.anchorPlayer == true,
    fpsBoost     = tbl23.fpsBoost == true,
    fpsCap       = tonumber(tbl23.fpsCap),
}

-- ── v86: status log (set depois de criar GUI) ────────────────
local v86 = nil

-- ── fn32: log ────────────────────────────────────────────────
local function fn32(msg, color)
    print("[VON] " .. tostring(msg))
    if v86 then v86.Log(tostring(msg), color) end
end

-- ── fn47: conta espaços ──────────────────────────────────────
local function fn47(str)
    local n = 0
    for _ in str:gmatch(" ") do n += 1 end
    return n
end

-- ── fn48: é riddle? ──────────────────────────────────────────
local function fn48(text)
    if not text or text == "" then return false end
    local ok = #text >= tbl29.MinChars
    if ok then ok = fn47(text) >= tbl29.MinSpaces end
    return ok
end

-- ── fn53: substituições literais (tbl37) ─────────────────────
local tbl37_replacements = { { kw = "admin war", rep = "jandel" } }
local function fn53(text)
    local lower = text:lower()
    for _, r in ipairs(tbl37_replacements) do
        if lower:find(r.kw, 1, true) then return r.rep end
    end
    return nil
end

-- ── fn52: match trigger ──────────────────────────────────────
local function fn52(text)
    local lower = text:lower()
    for _, trig in ipairs(tbl30) do
        if trig == "" then return true, nil, nil end
        local pos = lower:find(trig, 1, true)
        if pos then
            local after = text:sub(pos + #trig):match("^[%s:%-]*(.*)")
            return true, trig, (after and after ~= "" and after or nil)
        end
    end
    return false, nil, nil
end

-- ── fn60 (redeem sanitize+submit) ────────────────────────────
-- forward declarations
local fn57, fn58, fn55, fn60

local function sanitize(code)
    return string.sub(string.gsub(tostring(code), "[^%w]", ""), 1, 50)
end

fn60 = function(code)
    local clean = sanitize(code)
    if clean == "" then
        fn32("Redeem: nothing left after sanitising - not submitted", Color3.fromRGB(220, 80, 80))
        return false
    end
    local elapsed = os.clock() - vonCodeRedeemer.lastCodeAt
    if clean == vonCodeRedeemer.lastCode and elapsed < 2 then
        fn32("Redeem: [" .. clean .. "] was already submitted " .. math.floor(elapsed * 1000) .. "ms ago - duplicate dropped", Color3.fromRGB(200, 200, 90))
        return false
    end
    vonCodeRedeemer.lastCode   = clean
    vonCodeRedeemer.lastCodeAt = os.clock()

    local method = str13
    -- cracked: remote sempre disponível
    if method == "remote" and not fn55() then
        fn32("Redeem: no captured code remote - falling back to firesignal", Color3.fromRGB(255, 200, 90))
        method = "firesignal"
    end

    local ok, result
    if method == "remote" then
        ok, result = pcall(fn58, clean)
    else
        ok, result = pcall(fn57, clean)
    end

    if ok then
        fn32("Redeem: submitted via " .. tostring(result) .. " -> " .. clean, Color3.fromRGB(120, 200, 80))
    else
        vonCodeRedeemer.lastCode = nil
        fn32("Redeem FAILED (" .. method .. "): " .. tostring(result), Color3.fromRGB(220, 80, 80))
    end
    if clean ~= code then
        fn32("Redeem: sanitised [" .. tostring(code) .. "] -> [" .. clean .. "] (game strips non-alphanumerics, 50 char cap)", Color3.fromRGB(200, 200, 90))
    end
    return ok
end

-- ── Redeem via Firesignal ─────────────────────────────────────
local v89, v90, str16 = nil, nil, nil

local function fn54(timeout)
    -- procura PlayerGui.Codes ou similar
    timeout = timeout or 3
    local codesGui = playerGui:WaitForChild("Codes", timeout)
    return codesGui
end

local function fn56(timeout)
    if v89 and v89.Parent and v90 and v90.Parent then return v89, v90 end
    local codesGui = fn54(timeout or 3)
    if not codesGui then error("PlayerGui.Codes not found", 0) end
    local codeFrame = codesGui:FindFirstChild("Codes")
    if not codeFrame then error("Codes.Codes not found", 0) end
    local codeRedeem = codeFrame:FindFirstChild("CodeRedeem")
    if not codeRedeem then error("CodeRedeem not found", 0) end
    local textBox = codeRedeem:FindFirstChild("TextBox")
    if not textBox then error("CodeRedeem.TextBox not found", 0) end
    local confirm = codeFrame:FindFirstChild("Confirm")
    if not confirm then error("Codes.Confirm not found", 0) end
    v89 = textBox
    v90 = confirm:FindFirstChildWhichIsA("TextButton") or confirm
    str16 = nil
    return v89, v90
end

local function clickButton(btn)
    if typeof(firesignal) == "function" then
        if str16 == "click" then firesignal(btn.MouseButton1Click); return "MouseButton1Click" end
        if str16 == "activated" then firesignal(btn.Activated); return "Activated" end
        if typeof(getconnections) == "function" then
            local ok, conns = pcall(getconnections, btn.MouseButton1Click)
            if ok and conns and #conns > 0 then str16 = "click"; firesignal(btn.MouseButton1Click); return "MouseButton1Click" end
            ok, conns = pcall(getconnections, btn.Activated)
            if ok and conns and #conns > 0 then str16 = "activated"; firesignal(btn.Activated); return "Activated" end
        end
        firesignal(btn.MouseButton1Click); return "MouseButton1Click (unverified)"
    else
        error("this executor has no firesignal - switch Code Entry to Remote", 0)
    end
end

fn57 = function(text)
    local tb, btn = fn56(3)
    tb.Text = text
    return clickButton(btn)
end

-- ── Redeem via Remote ─────────────────────────────────────────
local capturedRemote    = nil
local isRemoteEvent     = false
local tbl12_run_done    = false
local tbl12_armed       = false
local tbl12_busy        = false

fn55 = function()
    if capturedRemote and capturedRemote.Parent then return capturedRemote end
    return nil
end

local function notifySuccess()
    -- tenta chamar módulo de notificação para confirmar
    pcall(function()
        local controllers = service:FindFirstChild("Controllers")
        controllers = controllers and controllers:FindFirstChild("NotificationController")
        if controllers then
            local m = require(controllers)
            module = m
            if typeof(m.Success) == "function" then
                m:Success("remote method does not create a notification here. submit was successful!")
            end
        end
    end)
end

fn58 = function(code)
    local remote = fn55()
    if not remote then error("code remote not captured", 0) end
    if isRemoteEvent then
        remote:FireServer(code)
        notifySuccess()
        return "remote FireServer"
    end
    task.spawn(function()
        local ok, result = pcall(function() return remote:InvokeServer(code) end)
        if ok then notifySuccess()
        else fn32("Redeem FAILED (remote): " .. tostring(result), Color3.fromRGB(220, 80, 80)) end
    end)
    return "remote InvokeServer"
end

-- ── tbl12: captura de remote (probe via __namecall / hookmetamethod) ──
local tbl12 = {
    armed    = false,
    installed = false,
    unavailable = false,
    busy     = false,
    done     = false,
    hit      = nil,
    seen     = {},
    name     = nil,
    parent   = nil,
    probe    = "VON_PROBE_" .. tostring(math.random(100000, 999999)),
    candidates = {},
}

local function tbl12_install()
    -- hook __namecall para capturar o remote que recebe o probe
    local function makeHandler(orig)
        return function(self, ...)
            local method = tostring(debug and debug.info and debug.info(1, "n") or "")
            if tbl12.armed then
                local args = { ... }
                local argStr = ""
                pcall(function()
                    for i, a in ipairs(args) do
                        argStr ..= (i > 1 and ", " or "") .. tostring(a):sub(1, 30)
                    end
                end)
                local entry = { name = tostring(self and self.Name or "?"), method = method, preview = argStr }
                tbl12.seen[#tbl12.seen + 1] = entry
                if typeof(self) == "Instance" and (self:IsA("RemoteFunction") or self:IsA("RemoteEvent")) then
                    local lower = tostring(args[1] or ""):lower()
                    if lower == tostring(tbl12.probe):lower() then
                        tbl12.hit = self
                    end
                end
            end
            return orig(self, ...)
        end
    end

    if typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function" then
        if pcall(function()
            local mt = getrawmetatable(game)
            local orig = rawget(mt, "__namecall")
            if typeof(orig) ~= "function" then error("no namecall", 0) end
            setreadonly(mt, false)
            mt.__namecall = makeHandler(orig)
            setreadonly(mt, true)
            tbl12.restore = function()
                pcall(function()
                    setreadonly(mt, false)
                    mt.__namecall = orig
                    setreadonly(mt, true)
                end)
            end
        end) then
            tbl12.installed = true
            return true
        end
    end
    if typeof(hookmetamethod) == "function" then
        if pcall(function()
            local orig2
            local function handler(self, ...) return orig2(self, ...) end
            orig2 = hookmetamethod(game, "__namecall", makeHandler(handler))
        end) then
            tbl12.installed = true
            return true
        end
    end
    tbl12.unavailable = true
    return false
end
vonCodeRedeemer.addCleanup(function()
    tbl12.armed = false
    if tbl12.restore then
        tbl12.restore()
        tbl12.restore = nil
        tbl12.installed = false
    end
end)

local function tbl12_run()
    if capturedRemote and capturedRemote.Parent then return capturedRemote end
    if tbl12.busy or tbl12.done then return nil end
    tbl12.busy = true

    local function success(remote, reason)
        if tbl12.restore then tbl12.restore(); tbl12.restore = nil end
        tbl12.installed = false
        tbl12.busy = false
        tbl12.done = true
        capturedRemote = remote
        tbl12.name   = remote.Name
        tbl12.parent = remote.Parent
        isRemoteEvent = remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")
        fn32("Remote: captured \"" .. remote.Name .. "\" (" .. remote.ClassName .. ") - " .. reason, Color3.fromRGB(120, 200, 80))
        return remote
    end

    local function fail(reason, color2)
        if tbl12.restore then tbl12.restore(); tbl12.restore = nil end
        tbl12.installed = false
        tbl12.busy = false
        tbl12.done = true
        fn32("Remote: " .. reason, color2 or Color3.fromRGB(200, 200, 90))
        return nil
    end

    local okFind, tb, btn = pcall(fn56, 20)
    if not okFind or not tb or not btn then
        return fail("capture skipped - " .. tostring(tb))
    end

    if tbl12_install() then
        local saved = tb.Text
        tbl12.hit  = nil
        tbl12.seen = {}
        tbl12.armed = true
        local okFire, fireResult = pcall(fn57, tbl12.probe)
        if okFire then
            local deadline = os.clock() + 5
            while os.clock() < deadline and not tbl12.hit do task.wait() end
        end
        tbl12.armed = false
        tb.Text = saved
        if tbl12.hit then
            return success(tbl12.hit, "sent probe as argument, via " .. tostring(fireResult))
        end
        if not okFire then
            return fail("capture could not submit the probe - " .. tostring(fireResult))
        end
        -- nenhum remote capturou o probe, log das chamadas vistas
        local calls = {}
        for i, e in ipairs(tbl12.seen) do calls[i] = e.name .. ":" .. e.method .. "(" .. e.preview .. ")" end
        fn32("Remote: no remote sent probe. Calls seen: " .. (#calls > 0 and table.concat(calls, " | ") or "none"), Color3.fromRGB(255, 200, 90))
    else
        fn32("Remote: __namecall hook unavailable - trying Confirm handler", Color3.fromRGB(255, 200, 90))
    end

    -- fallback: ler remotes do handler do Confirm button
    local candidates = {}
    local function collect(arg2)
        if typeof(arg2) == "Instance" then
            if (arg2:IsA("RemoteFunction") or arg2:IsA("RemoteEvent")) and arg2:IsDescendantOf(service) then
                local found = false
                for _, c in ipairs(candidates) do if c == arg2 then found = true; break end end
                if not found then candidates[#candidates+1] = arg2 end
            end
        elseif type(arg2) == "string" and #arg2 > 0 and #arg2 <= 200 then
            local r = service:FindFirstChild(arg2, true)
            if r and (r:IsA("RemoteFunction") or r:IsA("RemoteEvent")) then
                local found = false
                for _, c in ipairs(candidates) do if c == r then found = true; break end end
                if not found then candidates[#candidates+1] = r end
            end
        end
    end

    if typeof(getconnections) == "function" and typeof(debug) == "table" and typeof(debug.getconstants) == "function" then
        local visited = {}
        local function scan(v, depth)
            if depth > 4 then return end
            local k = type(v)
            if k == "function" then
                if visited[v] then return end
                visited[v] = true
                local ok2, consts = pcall(debug.getconstants, v)
                if ok2 and consts then for _, c in pairs(consts) do collect(c) end end
                if typeof(debug.getupvalues) == "function" then
                    local ok3, ups = pcall(debug.getupvalues, v)
                    if ok3 and ups then for _, u in pairs(ups) do scan(u, depth+1) end end
                end
            elseif k == "table" then
                if visited[v] then return end
                visited[v] = true
                for _, val in pairs(v) do scan(val, depth+1) end
            end
        end
        for _, sig in ipairs({ btn.MouseButton1Click, btn.Activated }) do
            local ok2, conns = pcall(getconnections, sig)
            if ok2 and conns then
                for _, conn in ipairs(conns) do
                    local ok3, fn_conn = pcall(function() return conn.Function end)
                    if ok3 and type(fn_conn) == "function" then scan(fn_conn, 0) end
                end
            end
        end
    end

    tbl12.candidates = candidates
    if #candidates == 1 then return success(candidates[1], "read out of Confirm handler") end
    -- prefere RemoteFunction dentro de service.Packages.Net
    local net = service:FindFirstChild("Packages") and service.Packages:FindFirstChild("Net")
    if net then
        local funcs = {}
        for _, c in ipairs(candidates) do
            if c:IsA("RemoteFunction") and c.Parent == net then funcs[#funcs+1] = c end
        end
        if #funcs == 1 then return success(funcs[1], "the only Net RemoteFunction in handler") end
    end
    local names = {}
    for i, c in ipairs(candidates) do names[i] = c.Name end
    return fail("could not identify the code remote" .. (#names > 0 and " - Confirm handler touches " .. #names .. " (" .. table.concat(names, ", ") .. ")" or "") .. ". Remote falls back to Firesignal.", Color3.fromRGB(220, 200, 80))
end

-- ── fn34: pré-aquecer GUI / remote ───────────────────────────
local function fn34()
    task.spawn(function()
        pcall(fn54, 10)
        pcall(fn56, 10)
        pcall(fn55)
        if v90 and typeof(getconnections) == "function" then
            pcall(function()
                local c1 = getconnections(v90.MouseButton1Click)
                if c1 and #c1 > 0 then str16 = "click"; return end
                local c2 = getconnections(v90.Activated)
                if c2 and #c2 > 0 then str16 = "activated" end
            end)
        end
        fn32("Redeem path prewarmed (gui:" .. tostring(v89 ~= nil) .. " remote:" .. tostring(capturedRemote ~= nil) .. " signal:" .. tostring(str16 or "probe on use") .. ")")
    end)
end

-- ── fn35: reset colecção ─────────────────────────────────────
local function fn35()
    flag20 = false
    tbl35  = {}
    n37    = 0
    str15  = nil
    n38    = 0
    n39    = 0
    n34    = 0
    n35    = 0
    flag21 = false
    n40   += 1
end

-- ── fn33: carrega KB do GitHub ───────────────────────────────
local v87 = false  -- KB carregada?
local kbCache = nil
local function fn33()
    if v87 then return kbCache end
    local ok, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/blookzz/von/refs/heads/main/prompt.txt")
    end)
    if ok and type(result) == "string" and result ~= "" then
        kbCache = result
        v87 = true
        fn32("AI: knowledge base loaded (" .. #result .. " chars) from GitHub", Color3.fromRGB(120, 200, 80))
        if #result > 28000 then
            fn32("AI: that KB is large enough to blow Groq's free-tier 8k tokens/minute – trim prompt.txt, or switch to Gemini", Color3.fromRGB(255, 200, 90))
        end
    else
        fn32("AI: FAILED to load knowledge base from https://raw.githubusercontent.com/blookzz/von/refs/heads/main/prompt.txt", Color3.fromRGB(220, 80, 80))
    end
    return kbCache
end

-- ── cleanAI ──────────────────────────────────────────────────
local function cleanAI(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("<think>.-</think>", " "):gsub("^%s*<think>.*", " "):gsub("\r", ""):gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "):gsub("[%.!]+$", ""))
end

-- ── fn49: pergunta ao AI, retorna resposta ───────────────────
local function fn49(question)
    local httpFn = fn46()
    if not httpFn then
        fn32("AI: no http function available", Color3.fromRGB(220, 80, 80))
        return nil
    end
    if str10 == "" then
        fn32("AI: locked – authenticate in the Key System (Main tab) to use AI answers", Color3.fromRGB(220, 80, 80))
        return nil
    end
    local provider = str9
    local model    = fn30()
    local kb       = fn33()
    local system   = (kb or "You are an assistant that answers Roblox game riddles concisely.") ..
        "\n\nAnswer with ONLY the answer code. No explanation, no punctuation at the end."

    local t0 = os.clock()
    local ok, resp

    if provider == "gemini" then
        local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent"
        ok, resp = pcall(httpFn, {
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json", ["x-goog-api-key"] = str10 },
            Body    = HttpService:JSONEncode({
                contents = {{ parts = {{ text = system .. "\n\nQuestion: " .. question }} }},
                generationConfig = { temperature = 0, maxOutputTokens = 64 },
            }),
        })
    else
        local url = tbl36_urls[provider]
        if not url then
            fn32("AI: unknown provider '" .. provider .. "'", Color3.fromRGB(220, 80, 80))
            return nil
        end
        ok, resp = pcall(httpFn, {
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. str10 },
            Body    = HttpService:JSONEncode({
                model       = model,
                max_tokens  = 64,
                temperature = 0,
                messages    = {
                    { role = "system", content = system },
                    { role = "user",   content = "Riddle / question: " .. question },
                },
            }),
        })
    end

    if not ok then
        fn32("AI: " .. tostring(resp) .. " – " .. str9 .. " / " .. model, Color3.fromRGB(220, 80, 80))
        return nil
    end

    local body = (type(resp) == "table" and (resp.Body or resp.body)) or ""
    local decoded
    local ok2 = pcall(function() decoded = HttpService:JSONDecode(body) end)
    if not ok2 then
        fn32("AI: invalid JSON response", Color3.fromRGB(220, 80, 80))
        return nil
    end

    -- verificar erros
    if decoded.error then
        local msg = tostring(decoded.error.message or decoded.error)
        if msg:find("rate.limit") or msg:find("429") then
            fn32("AI: that is the free-tier rate limit, not a bad key – wait it out or switch provider on the AI tab", Color3.fromRGB(200, 200, 90))
        elseif msg:find("401") or msg:find("invalid") then
            fn32("AI: key rejected – check it is a " .. str9 .. " key and was pasted whole", Color3.fromRGB(200, 200, 90))
        else
            fn32("AI: error – " .. msg, Color3.fromRGB(220, 80, 80))
        end
        return nil
    end

    local answer
    if provider == "gemini" then
        answer = decoded.candidates and decoded.candidates[1] and decoded.candidates[1].content and decoded.candidates[1].content.parts and decoded.candidates[1].content.parts[1] and decoded.candidates[1].content.parts[1].text
    else
        answer = decoded.choices and decoded.choices[1] and decoded.choices[1].message and decoded.choices[1].message.content
    end

    if not answer then
        fn32("AI: no answer in response – check key / model", Color3.fromRGB(255, 100, 50))
        return nil
    end

    answer = cleanAI(answer)
    local elapsed = math.floor((os.clock() - t0) * 10) / 10
    fn32("AI answered in " .. elapsed .. "s – submitting", Color3.fromRGB(120, 200, 80))
    return answer
end

-- ── fn63: pede AI de forma async, coloca no slot ─────────────
local function fn61() -- "tracked code" log
    local parts = {}
    for i = 1, n39 do if tbl35[i] ~= nil then parts[#parts+1] = tbl35[i] end end
    fn32("Tracked code: [" .. table.concat(parts) .. "]  (" .. (n37 - n38) .. " remaining)")
end

local function fn62() -- verifica se colecção está completa e submete
    if not flag20 then return false end
    if n37 <= 0 then return false end
    if n38 < n37 or n35 > 0 then return true end -- ainda pendente
    local parts = {}
    for i = 1, n37 do parts[i] = tbl35[i] or "" end
    local code = table.concat(parts)
    fn35()
    if code == "" then fn32("Collection finished but code was empty"); return true end
    fn60(code)
    fn32("Full code assembled – " .. code, Color3.fromRGB(255, 200, 90))
    if not flag19 then fn32("Auto Enter off – not submitted: " .. code) end
    return true
end

local function fn65(idx) -- early-submit
    if not tbl28[idx] then return end
    local parts = {}
    for i = 1, idx do
        if tbl35[i] == nil then return end
        parts[i] = tbl35[i]
    end
    local code = table.concat(parts)
    if code == "" then return end
    if flag19 then fn60(code) end
    fn32("Early submit @" .. idx .. " – " .. code .. (flag19 and "" or " (Auto Enter off – not submitted)"), Color3.fromRGB(255, 200, 90))
end

local function fn63(text, slot) -- async AI para slot
    n35 += 1
    local gen = n40
    task.spawn(function()
        local answer = fn49(text)
        if gen ~= n40 then
            fn32("AI: answer for #" .. slot .. " arrived after reset – discarded", Color3.fromRGB(255, 200, 90))
            return
        end
        local seg = (answer and answer ~= "") and answer or ""
        tbl35[slot] = seg
        n38 += 1
        n35 -= 1
        if seg == "" then fn32("AI: no answer for #" .. slot .. " – empty segment")
        else fn32("AI: answer for #" .. slot .. " – [" .. seg .. "]") end
        fn61(); fn62()
    end)
end

local function fn64(text) -- inicia colecção de riddle
    flag22 = false; fn35()
    flag20 = true; str15 = "riddle"; n37 = 1; n39 = 1
    fn63(text, 1)
end

-- ── fn59: handler principal de notificação ───────────────────
local flag28_busy = false  -- a submeter via remote confirmation

local function fn59(lastText, source)
    if vonCodeRedeemer.dead then return end
    if not lastText or lastText == "" then return end
    if source and source ~= str14 then return end
    if lastText == "remote method does not create a notification here. submit was successful!" then return end

    local now2 = os.clock()
    if lastText == vonCodeRedeemer.lastText and now2 - vonCodeRedeemer.lastTextAt < 0.25 then
        fn32("Notification repeated within " .. math.floor((now2 - vonCodeRedeemer.lastTextAt) * 1000) .. "ms - ignored as a duplicate: " .. lastText)
        return
    end
    vonCodeRedeemer.lastText   = lastText
    vonCodeRedeemer.lastTextAt = now2

    -- force-scan
    if flag21 and flag20 and n34 > 0 then
        table.insert(tbl35, lastText)
        n34 -= 1
        if n34 <= 0 then
            local code = table.concat(tbl35)
            fn35(); fn60(code)
            fn32("Notification (Force Scan): " .. lastText)
            fn32("Submit Code – " .. code, Color3.fromRGB(255, 200, 90))
            fn32("Force Scan complete")
        else
            fn65(#tbl35)
            fn32("Notification (Force Scan): " .. lastText)
            fn32("Code update: [" .. table.concat(tbl35) .. "]  (" .. n34 .. " remaining)")
        end
        return
    end

    -- a colectar
    if flag20 then
        if not str15 then
            local isRiddle = flag22 or fn48(lastText)
            local count = isRiddle and n33 or n32
            str15 = isRiddle and "riddle" or "code"
            n37 = count > 0 and count or 1
            fn32("Classified as " .. str15 .. " (" .. #lastText .. " chars / " .. fn47(lastText) .. " spaces vs min " .. tbl29.MinChars .. " / " .. tbl29.MinSpaces .. ") – collecting " .. n37 .. " notification(s)", Color3.fromRGB(255, 200, 90))
        end

        if n37 <= n39 then
            fn32("Ignoring extra notification while completing: " .. lastText)
            return
        end

        n39 += 1
        local slot = n39
        local useAI = premium and (v85 or flag22)
        local sendToAI
        if useAI then
            sendToAI = flag22 and true or fn48(lastText)
        else
            sendToAI = false
        end

        if sendToAI then
            flag22 = false
            fn32("Notification #" .. slot .. "/" .. n37 .. " (AI): " .. lastText)
            fn63(lastText, slot)
        else
            local replacement = fn53(lastText)
            local seg = replacement ~= nil and replacement or lastText
            tbl35[slot] = seg
            n38 += 1
            local finished = fn62()
            if not finished then fn65(slot) end
            if replacement ~= nil then
                fn32("Notification #" .. slot .. "/" .. n37 .. " literal (replaced): [" .. lastText .. "] → [" .. seg .. "]")
            else
                fn32("Notification #" .. slot .. "/" .. n37 .. " literal: " .. seg)
            end
            if finished then fn61() end
        end
        return
    end

    -- ainda não colectando: verificar trigger
    local matched, trigWord, inline = fn52(lastText)
    if not matched then
        if flag22 and premium then
            fn32("Force AI – this notification is the question, asking the AI: " .. lastText, Color3.fromRGB(255, 200, 90))
            fn64(lastText)
            return
        end
        fn32("Notification scanned (no match): " .. lastText)
        return
    end

    -- inline code? (todo o código está na mesma notificação)
    if premium and inline and #inline > tbl29.InlineMin then
        local str17 = "one notification (" .. #inline .. " chars after \"" .. tostring(trigWord) .. "\")"
        if tbl29.InlineCode and not flag22 then
            local rep = fn53(inline); rep = rep ~= nil and rep or inline
            fn35()
            if flag19 then fn60(rep) end
            fn32("Trigger – all in " .. str17 .. " – code: " .. rep, Color3.fromRGB(255, 200, 90))
            if not flag19 then fn32("Auto Enter off – not submitted: " .. rep) end
            return
        end
        if premium and (v85 or flag22) then
            fn32("Trigger – all in " .. str17 .. " – riddle, asking the AI: " .. inline, Color3.fromRGB(255, 100, 90))
            fn64(inline)
            return
        end
        fn32("Trigger – all in " .. str17 .. ", but AI is off (AI tab → Use AI Answers) – falling back to normal collection", Color3.fromRGB(255, 100, 90))
    end

    local collectCount = (fn48(lastText) and n33 or n32)
    if collectCount <= 0 then
        -- submit=0: submete de imediato
        if flag22 and premium then
            fn32("Trigger (single notification) – Force AI, asking the AI: " .. lastText, Color3.fromRGB(255, 200, 90))
            fn64(lastText); return
        end
        local rep = fn53(lastText); rep = rep ~= nil and rep or lastText
        if rep ~= "" then
            fn32("Text entered: " .. rep)
            if flag19 then fn60(rep) end
        end
        return
    end

    fn35()
    flag20 = true
    n37 = 0
    str15 = nil
    fn32("Trigger" .. (trigWord and " \"" .. trigWord .. "\"" or "") .. " – tracking started, riddle/code decided by the next notification: " .. lastText, Color3.fromRGB(200, 200, 90))
end

-- ── ChildAdded scan ───────────────────────────────────────────
local obj_watched = {}
local function fn50(arg) -- está "morto" (dentro da codebox)?
    if not arg or not arg.Parent then return true end
    if v89 and arg:IsDescendantOf(v89.Parent or game) then return false end
    return false
end

local function fn51(arg) -- texto actual de um elemento
    if arg:IsA("TextLabel") or arg:IsA("TextButton") or arg:IsA("TextBox") then
        return arg.Text
    end
    return nil
end

local function fn60_watch(arg)
    if obj_watched[arg] then return end
    if fn50(arg) then return end
    obj_watched[arg] = true
    if arg:IsA("TextLabel") or arg:IsA("TextButton") or arg:IsA("TextBox") then
        arg:GetPropertyChangedSignal("Text"):Connect(function()
            if not fn50(arg) and arg.Text ~= "" then fn59(arg.Text, "childadded") end
        end)
    end
    for _, d in ipairs(arg:GetDescendants()) do fn60_watch(d) end
    arg.DescendantAdded:Connect(function(d)
        if fn50(d) then return end
        local wasNew = not obj_watched[d]
        fn60_watch(d)
        if wasNew then
            local txt = fn51(d)
            if txt and txt ~= "" then fn59(txt, "childadded") end
        end
    end)
end

local function fn36() -- inicia ChildAdded scan
    local names = { "TopNotification" }
    for _, name in ipairs(names) do
        local g = playerGui:FindFirstChild(name)
        if g then fn60_watch(g) end
    end
    playerGui.ChildAdded:Connect(function(child)
        for _, name in ipairs(names) do
            if child.Name == name then fn60_watch(child) end
        end
    end)
end

-- ── Controller scan ───────────────────────────────────────────
local controllerHooked = false
local function fn37()
    if controllerHooked then return end
    local ok, result = pcall(function()
        local ctrl = service:WaitForChild("Controllers", 10):WaitForChild("NotificationController", 10)
        local mod  = require(ctrl)
        module = mod
        local origNotify = mod.Notify
        if typeof(origNotify) ~= "function" then error("NotificationController.Notify is not a function", 0) end
        local hooked = function(self, text, ...)
            local active = not vonCodeRedeemer.dead and not flag28_busy
            if active and type(text) == "string" and text ~= "" then
                local arg5 = select(3, ...)
                if arg5 == "Top" then
                    pcall(fn59, text, "controller")
                end
            end
            return origNotify(self, text, ...)
        end
        mod.Notify = hooked
        controllerHooked = true
        vonCodeRedeemer.addCleanup(function()
            if mod.Notify == hooked then mod.Notify = origNotify end
        end)
    end)
    if ok then
        fn32("Controller: NotificationController.Notify hooked", Color3.fromRGB(120, 200, 80))
    else
        fn32("Controller: hook FAILED (" .. tostring(result) .. ") - Controller scan mode will not receive anything", Color3.fromRGB(220, 80, 80))
    end
end

-- ── fn39: spawn watcher (Steal a Brainrot específico) ────────
local function fn39()
    local ok, result = pcall(function()
        return playerGui:WaitForChild("Notification", 5):WaitForChild("Notifications", 10)
    end)
    if not ok or not result then fn32("Spawn watcher: Notification folder not found"); return end
    local function checkLabel(child)
        if vonCodeRedeemer.dead then return end
        if not child:IsA("TextLabel") then return end
        local text = child.Text
        if type(text) ~= "string" then return end
        local match = text:gsub("<[^>]+>", ""):match("^(.-)%s+spawned!%s*$")
        if match and match ~= "" then
            fn32("Spawn detected: " .. match .. " spawned!")
        end
    end
    for _, child in ipairs(result:GetChildren()) do checkLabel(child) end
    result.ChildAdded:Connect(function(child) task.wait(); checkLabel(child) end)
end

-- ── Anti Ragdoll ─────────────────────────────────────────────
local charState = {}
local antiRagdollConn = nil
local flag23 = false -- antiRagdoll activo
local flag24 = false -- autoBuy activo

local function refreshChar()
    local char = localPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    charState = { character = char, humanoid = hum, root = root }
    local cam = workspace.CurrentCamera
    if cam then cam.CameraSubject = hum end
    return true
end

local function isRagdolled()
    local hum = charState.humanoid
    if not hum then return false end
    local s = hum:GetState()
    if s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown then return true end
    local attr = localPlayer:GetAttribute("RagdollTime")
    if attr and attr - workspace:GetServerTimeNow() > 0 then return true end
    return false
end

local function stripRagdollConstraints()
    local char = charState.character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then
            pcall(function() d:Destroy() end)
        end
    end
end

local function unragdoll()
    local hum  = charState.humanoid
    local root = charState.root
    if not hum or not root then return end
    pcall(function() localPlayer:SetAttribute("RagdollTime", workspace:GetServerTimeNow()) end)
    if hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Running) end
    local flag25 = tbl31.anchorPlayer
    if not flag25 then root.Anchored = false end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)
    local cam = workspace.CurrentCamera
    if cam and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
end

local function fn40() -- inicia anti-ragdoll loop
    if not refreshChar() then return end
    if antiRagdollConn then return end
    antiRagdollConn = RunService.RenderStepped:Connect(function()
        if not flag23 or not premium then return end
        local hum = charState.humanoid
        if not hum or not hum.Parent then refreshChar(); return end
        if isRagdolled() then stripRagdollConstraints(); unragdoll() end
    end)
    vonCodeRedeemer.addCleanup(function()
        if antiRagdollConn then antiRagdollConn:Disconnect(); antiRagdollConn = nil end
    end)
end

-- ── Anchor Player ─────────────────────────────────────────────
local flag25 = false
local function fn41(anchored)
    flag25 = anchored
    local char = localPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        pcall(function() hrp.Anchored = anchored end)
    end
end

-- ── Auto Buy ─────────────────────────────────────────────────
local buyRegistry    = {}
local buyRegistryBuilt = false
local buyKeywords    = { "buy", "purchase", "claim", "steal", "collect" }

local function fn42() -- build registry
    if buyRegistryBuilt then return end
    buyRegistryBuilt = true
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then buyRegistry[d] = true end
    end
    workspace.DescendantAdded:Connect(function(d)
        if d:IsA("ProximityPrompt") then buyRegistry[d] = true end
    end)
    workspace.DescendantRemoving:Connect(function(d) buyRegistry[d] = nil end)
    fn32("Auto Buy: prompt registry built", Color3.fromRGB(120, 200, 80))
end

local function isBuyPrompt(pp)
    local combined = ((pp.Name or "") .. " " .. (pp.ActionText or "") .. " " .. (pp.ObjectText or "")):lower()
    for _, kw in ipairs(buyKeywords) do
        if combined:find(kw, 1, true) then return true end
    end
    return false
end

local function getPromptPos(pp)
    local p = pp.Parent
    if not p then return nil end
    if p:IsA("Attachment") then return p.WorldPosition end
    if p:IsA("BasePart") then return p.Position end
    local model = p:FindFirstAncestorOfClass("Model")
    if model then
        local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        if primary then return primary.Position end
    end
    return nil
end

local function fn43() -- nearest buy prompt
    local char = localPlayer.Character
    char = char and char:FindFirstChild("HumanoidRootPart")
    if not char then return nil, math.huge end
    local best, bestDist = nil, math.huge
    for pp in pairs(buyRegistry) do
        if pp.Parent and pp.Enabled and isBuyPrompt(pp) then
            local pos = getPromptPos(pp)
            if pos then
                local d = (char.Position - pos).Magnitude
                if d < bestDist then bestDist = d; best = pp end
            end
        end
    end
    return best, bestDist
end

local function fn44(pp) -- dispara prompt
    if not pp or not pp.Parent or not pp.Enabled then return false, "prompt unavailable" end
    if typeof(fireproximityprompt) == "function" then
        local ok = pcall(fireproximityprompt, pp)
        return ok, not ok and "fireproximityprompt failed" or nil
    end
    local ok = pcall(function()
        pp:InputHoldBegin()
        task.wait(math.max(pp.HoldDuration, 0.05) + 0.05)
        pp:InputHoldEnd()
    end)
    return ok, not ok and "InputHold failed" or nil
end

-- ── tbl33/tbl34: whitelist para optimizer ────────────────────
local tbl33 = {}
local tbl34 = {}
local flag27 = false
local flag26 = false -- fpsOptimizer activo

local function fn45_build()
    table.clear(tbl33); table.clear(tbl34)
    local function mark(t, obj) if obj then t[obj] = true end end
    mark(tbl33, workspace:FindFirstChild("Camera"))
    mark(tbl33, workspace:FindFirstChild("Terrain"))
    mark(tbl33, workspace:FindFirstChild("Characters"))
    mark(tbl33, workspace:FindFirstChild("Plots"))
    mark(tbl33, workspace:FindFirstChild("RenderedMovingAnimals"))
    local function findPath(...)
        local v = workspace
        for _, n in ipairs({...}) do v = v:FindFirstChild(n); if not v then return nil end end
        return v
    end
    mark(tbl34, findPath("Map", "Spawn"))
    mark(tbl34, findPath("Map", "__StreamCheck_DontDelete"))
    mark(tbl34, findPath("Characters", "Carpet"))
    mark(tbl34, findPath("Characters", "BindableEvents"))
    mark(tbl34, findPath("Map", "Ground_Left"))
    mark(tbl34, findPath("Map", "Ground_Right"))
end

local function fn60_optimizer()
    for _, d in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if d:IsA("Texture") or d:IsA("Decal") or d:IsA("SurfaceAppearance") then d:Destroy()
            elseif d:IsA("SpecialMesh") then d.TextureId = ""
            elseif d:IsA("MeshPart") then d.TextureID = ""; d.CastShadow = false
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Highlight") or d:IsA("Explosion") or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then d:Destroy()
            elseif d:IsA("BasePart") then d.CastShadow = false; d.Material = Enum.Material.Plastic; d.MaterialVariant = ""; d.Reflectance = 0
            end
        end)
    end
end

local function fn56_optimizer()
    fn45_build()
    for _, child in ipairs(workspace:GetChildren()) do
        if not tbl33[child] and not child.Name:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") and not Players:FindFirstChild(child.Name) then
            pcall(function() child:Destroy() end)
        end
    end
    -- mapa
    local map = workspace:FindFirstChild("Map")
    if map then
        for _, c in ipairs(map:GetChildren()) do
            if not tbl34[c] then pcall(function() c:Destroy() end) end
        end
    end
    fn60_optimizer()
end

local function fn57_lighting()
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Clouds") then
            pcall(function() c:Destroy() end)
        end
    end
end

local function fn46_optimizer_hooks()
    if flag27 then return end
    flag27 = true
    workspace.DescendantAdded:Connect(function(d)
        if not flag26 or not premium then return end
        task.defer(function()
            if not flag26 or not premium then return end
            if d:IsA("Texture") or d:IsA("Decal") or d:IsA("SurfaceAppearance") or d:IsA("PointLight") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Highlight") or d:IsA("AnimationController") then
                pcall(function() d:Destroy() end)
            end
        end)
    end)
    Lighting.DescendantAdded:Connect(function(d)
        if not flag26 or not premium then return end
        if d:IsA("PostEffect") or d:IsA("Atmosphere") or d:IsA("Clouds") then
            pcall(function() d:Destroy() end)
        end
    end)
end

-- ── fn38: telemetria (von worker, não crítico) ────────────────
local function fn38(data)
    local httpFn = fn46()
    if not httpFn then return end
    local ok, body = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then return end
    pcall(httpFn, {
        Url     = "https://vonscripts.meowstieebo123.workers.dev/",
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = body,
    })
end

-- ── fn51_ui: aplica unlock premium na UI ─────────────────────
local v98  -- main panel ref
local v99, v96, v97  -- tab refs
local flag19_save -- save callback

local function fn53_ui() -- atualiza status "Whitelist" na UI
    -- chamado após premium=true estar definido
    fn32("Whitelist: premium session as " .. tostring(discord) .. " (script v" .. tbl32.version .. ")", Color3.fromRGB(120, 200, 80))
    task.spawn(fn33)
end

-- ── fn51: save config ─────────────────────────────────────────
local lastSaveWarnAt = -math.huge
local function fn51()
    if typeof(writefile) ~= "function" then return end
    local ok, err = pcall(function()
        writefile("von_autocode.json", HttpService:JSONEncode({
            entryMethod    = tbl31.entryMethod,
            scanMode       = tbl31.scanMode,
            antiRagdoll    = tbl31.antiRagdoll,
            autoBuy        = tbl31.autoBuy,
            anchorPlayer   = tbl31.anchorPlayer,
            fpsBoost       = tbl31.fpsBoost,
            fpsCap         = tbl31.fpsCap,
            theme          = tbl22.Name,
            accent         = accent and { R = math.floor(accent.R * 255), G = math.floor(accent.G * 255), B = math.floor(accent.B * 255) } or nil,
            accentGradient  = tbl21.Enabled,
            accentGradient2 = tbl21.Colour and { R = math.floor(tbl21.Colour.R * 255), G = math.floor(tbl21.Colour.G * 255), B = math.floor(tbl21.Colour.B * 255) } or nil,
        }))
    end)
    if not ok then
        local now2 = os.clock()
        if now2 - lastSaveWarnAt > 60 then
            lastSaveWarnAt = now2
            fn32("Config: SAVE FAILED – " .. tostring(err) .. " (settings will not survive a re-execute)", Color3.fromRGB(220, 80, 80))
        end
    end
end

-- ── tbl21.Collect: aplica estado de gradiente ─────────────────
tbl21.Collect = function()
    if tbl21.Enabled then
        lib.Theme.AccentGrad1 = lib.Theme.Accent
        lib.Theme.AccentGrad2 = tbl21.Colour
    end
end

-- ══════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════
-- ██ SKIBIDI UI ████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════

-- ── tbl13: FPS Booster reversível (idêntico ao original) ─────
local tbl13 = {
    enabled    = false,
    hooked     = false,
    running    = false,
    capApplied = false,
    saved      = setmetatable({}, { __mode = "k" }),
    set = function(obj, prop, val)
        pcall(function()
            local cur = obj[prop]
            if cur == val then return end
            local t = tbl13.saved[obj]
            if not t then t = {}; tbl13.saved[obj] = t end
            if t[prop] == nil then t[prop] = cur end
            obj[prop] = val
        end)
    end,
    apply = function(obj)
        if obj == workspace.Terrain then
            tbl13.set(obj, "Decoration",       false)
            tbl13.set(obj, "WaterWaveSize",    0)
            tbl13.set(obj, "WaterWaveSpeed",   0)
            tbl13.set(obj, "WaterReflectance", 0)
        elseif obj:IsA("BasePart") then
            tbl13.set(obj, "Material",         Enum.Material.Plastic)
            tbl13.set(obj, "MaterialVariant",  "")
            tbl13.set(obj, "Reflectance",      0)
            tbl13.set(obj, "CastShadow",       false)
            if obj:IsA("MeshPart") then tbl13.set(obj, "TextureID", "") end
        elseif obj:IsA("Decal") then
            tbl13.set(obj, "Transparency", 1)
        elseif obj:IsA("SpecialMesh") then
            tbl13.set(obj, "TextureId", "")
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Light") or obj:IsA("PostEffect") or obj:IsA("Clouds") then
            tbl13.set(obj, "Enabled", false)
        elseif obj:IsA("Atmosphere") then
            tbl13.set(obj, "Density", 0)
            tbl13.set(obj, "Glare",   0)
            tbl13.set(obj, "Haze",    0)
        end
    end,
    applyAll = function()
        tbl13.set(Lighting, "GlobalShadows", false)
        pcall(function()
            tbl13.set(settings().Rendering, "QualityLevel", Enum.QualityLevel.Level01)
        end)
        for _, d in ipairs(Lighting:GetDescendants()) do tbl13.apply(d) end
        local descs = workspace:GetDescendants()
        for i = 1, #descs do
            if not tbl13.enabled then return end
            tbl13.apply(descs[i])
            if i % 1500 == 0 then task.wait() end
        end
    end,
    restore = function()
        local saved = tbl13.saved
        tbl13.saved = setmetatable({}, { __mode = "k" })
        local n = 0
        for obj, props in pairs(saved) do
            for prop, val in pairs(props) do
                pcall(function() obj[prop] = val end)
            end
            n += 1
            if n % 1500 == 0 then task.wait() end
        end
        return n
    end,
    hook = function()
        if tbl13.hooked then return end
        tbl13.hooked = true
        local function onNew(d)
            if vonCodeRedeemer.dead or not tbl13.enabled or not premium then return end
            task.defer(function()
                if tbl13.enabled and d.Parent then tbl13.apply(d) end
            end)
        end
        workspace.DescendantAdded:Connect(onNew)
        Lighting.DescendantAdded:Connect(onNew)
    end,
    start = function()
        if tbl13.enabled then return end
        tbl13.enabled = true
        tbl13.hook()
        task.spawn(function()
            tbl13.running = true
            fn32("FPS Booster: sweeping…", Color3.fromRGB(255, 200, 90))
            tbl13.applyAll()
            tbl13.running = false
            if tbl13.enabled then
                fn32("FPS Booster ON – reversible, turn it off to restore the visuals", Color3.fromRGB(120, 200, 120))
            end
        end)
    end,
    stop = function()
        if not tbl13.enabled then return end
        tbl13.enabled = false
        task.spawn(function()
            fn32("FPS Booster OFF – restored " .. tbl13.restore() .. " object(s)", Color3.fromRGB(120, 200, 120))
        end)
    end,
    applyCap = function(n)
        local num = tonumber(n)
        if num then
            if typeof(setfpscap) ~= "function" then
                fn32("FPS Cap: this executor has no setfpscap", Color3.fromRGB(255, 200, 90))
                return false
            end
            local ok, err = pcall(setfpscap, math.floor(num))
            if ok then tbl13.capApplied = true
            else fn32("FPS Cap: setfpscap failed – " .. tostring(err), Color3.fromRGB(220, 80, 80)) end
            return ok
        end
        return false
    end,
}

vonCodeRedeemer.addCleanup(function()
    if flag25 then fn41(false) end
    tbl13.stop()
    if tbl13.capApplied then tbl13.applyCap(60) end
    flag23 = false; flag25 = false; flag24 = false; flag26 = false; flag19 = false
end)

-- ── localPlayer.CharacterAdded: re-aplica feats ──────────────
localPlayer.CharacterAdded:Connect(function(character)
    if vonCodeRedeemer.dead then return end
    character:WaitForChild("Humanoid", 8)
    task.wait(0.5)
    if not premium then return end
    if flag23 then fn40() end
    if flag25 then fn41(true) end
end)

-- ── Heartbeat loop central (Anchor + AutoBuy + Optimizer) ────
local hbAutoBuyLast   = 0
local hbOptimizerAcc  = 0
local hbAutoBuyTimer  = 0

RunService.Heartbeat:Connect(function(dt)
    if vonCodeRedeemer.dead or not premium then return end

    -- Anchor Player: mantém HRP anchored mesmo se o jogo o desancora
    if flag25 then
        local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") and not hrp.Anchored then
            hrp.Anchored = true
        end
    end

    -- FPS Optimizer (destruidora): limpa a cada ~2s via flag26 + n36_acc
    if flag26 then
        hbOptimizerAcc += dt
        if hbOptimizerAcc >= 2 then
            hbOptimizerAcc = 0
            pcall(fn56_optimizer)
            pcall(fn57_lighting)
        end
    end

    -- Auto Buy: verifica a cada 0.2s
    if flag24 then
        hbAutoBuyTimer += dt
        if hbAutoBuyTimer >= 0.2 then
            hbAutoBuyTimer = 0
            local pp, dist = fn43()
            if pp then
                local maxDist = (pp.MaxActivationDistance or 10) + 5
                if dist <= maxDist then
                    local isNew = pp ~= hbAutoBuyLast
                    local cooldownOk = isNew or (os.clock() - hbAutoBuyLast >= 3)
                    if cooldownOk then
                        hbAutoBuyLast = os.clock()
                        task.spawn(function()
                            local ok, err = fn44(pp)
                            if not ok and flag24 then
                                fn32("Auto Buy: " .. tostring(err), Color3.fromRGB(255, 200, 90))
                            end
                        end)
                    end
                end
            end
        end
    end
end)

-- ── tbl14: sistema paid/free/locked ──────────────────────────
-- premium=true → tabsLast=false → tabs na ordem premium (Main, Triggers, Admin Abuse, AI, UI, Status)
local tbl14 = {
    tabsLast = false,  -- sempre false quando premium=true
    rows     = {},
    freeRows = {},
    paid = function(arg) tbl14.rows[#tbl14.rows+1] = arg.Frame; return arg end,
    free = function(arg) tbl14.freeRows[#tbl14.freeRows+1] = arg.Frame; return arg end,
    locked = function()
        -- noop: cracked, tudo desbloqueado
    end,
}

-- ── Painel principal ─────────────────────────────────────────
local v88 = lib.CreatePanel({
    Name          = "vonAutoCode",
    Title         = "VON CODE REDEEMER",
    SubTitle      = ".gg/vonhub",
    Icon          = "locate-fixed",
    Width         = 560,
    Height        = 250,
    Tabs          = {
        { Name = "Main",        Icon = "house"     },
        { Name = "Triggers",    Icon = "zap"       },
        { Name = "Admin Abuse", Icon = "shield"    },
        { Name = "AI",          Icon = "bot"       },
        { Name = "UI",          Icon = "palette"   },
        { Name = "Status",      Icon = "activity"  },
    },
    TabSide       = "left",
    TabWidth      = 140,
    DefaultTab    = 1,
    Discord       = true,
    ClampToScreen = true,
    ToggleKey     = "",
    Scaler        = true,
    MinSize       = { 320, 220 },
    MaxSize       = { 900, 700 },
})
local gui = v88.Gui
vonCodeRedeemer.gui = gui
vonCodeRedeemer.addCleanup(function() pcall(lib.Unload) end)

-- tabs na ordem premium
local v99 = v88.GetTab(1)   -- Main
local v98 = v88.GetTab(2)   -- Triggers
local tabAdmin  = v88.GetTab(3)  -- Admin Abuse
local tabAI     = v88.GetTab(4)  -- AI
local tabUI     = v88.GetTab(5)  -- UI
local tabStatus = v88.GetTab(6)  -- Status

-- ── fn48: save (idêntico ao original: lib.SaveConfig) ────────
local function fn48()
    if vonCodeRedeemer.dead then return end
    local ok, err = lib.SaveConfig("von_autocode")
    if not ok then
        local now2 = os.clock()
        if now2 - (vonCodeRedeemer.lastSaveWarnAt or -math.huge) > 60 then
            vonCodeRedeemer.lastSaveWarnAt = now2
            fn32("Config: SAVE FAILED – " .. tostring(err) .. " (settings will not survive a re-execute)", Color3.fromRGB(220, 80, 80))
        end
    end
end

-- save debounced ao redimensionar
do
    local pending = false
    local function fn49()
        if not pending then
            pending = true
            task.delay(0.4, function()
                pending = false
                fn48()
            end)
        end
    end
    v88.Frame:GetPropertyChangedSignal("Size"):Connect(function()
        if vonCodeRedeemer.dead or v88.IsMinimized() then return end
        fn49()
    end)
    vonCodeRedeemer.addCleanup(function() pcall(lib.SaveConfig, "von_autocode") end)
end

-- fn50: liga TextChanged de um input ao save
local function fn50(inputWidget, cb)
    local tb = inputWidget and inputWidget.TextBox
    if not tb then return end
    tb:GetPropertyChangedSignal("Text"):Connect(function()
        if vonCodeRedeemer.dead then return end
        if cb then pcall(cb, tb.Text) end
        fn48()
    end)
end

-- ── fn58: mostra notificação no topo (fallback) ──────────────
local function fn58(text, avatarId)
    local sgName = "vonNotifGui"
    local sg = playerGui:FindFirstChild(sgName)
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = sgName; sg.ResetOnSpawn = false; sg.DisplayOrder = 100; sg.Parent = playerGui
        local holder = Instance.new("Frame")
        holder.Name = sgName; holder.Size = UDim2.new(1,0,0.2,0)
        holder.Position = UDim2.new(0,0,0,0); holder.BackgroundTransparency = 1; holder.Parent = sg
    end
    local holder = sg:FindFirstChild(sgName)
    if not holder then return end
    local frame = Instance.new("Frame")
    frame.Name = "Notification"; frame.Size = UDim2.new(0.5,0,0,50)
    frame.Position = UDim2.new(0.25,0,0,10); frame.BackgroundColor3 = Color3.fromRGB(40,40,40)
    frame.BorderSizePixel = 0; frame.Parent = holder
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(100,200,255); stroke.Thickness = 2
    if avatarId and avatarId ~= 0 and avatarId ~= "" then
        local img = Instance.new("ImageLabel", frame)
        img.BackgroundTransparency = 1; img.Size = UDim2.fromScale(1,1)
        img.SizeConstraint = Enum.SizeConstraint.RelativeYY
        img.Position = UDim2.fromScale(0,0.5) + UDim2.fromOffset(-12,0)
        img.AnchorPoint = Vector2.new(1,0.5)
        img.Image = type(avatarId)=="string" and avatarId or ("rbxthumb://type=AvatarHeadShot&id=" .. tostring(avatarId) .. "&w=420&h=420")
        Instance.new("UICorner", img).CornerRadius = UDim.new(0.12, 0)
    end
    local lbl = Instance.new("TextLabel", frame)
    lbl.Name = "Text"; lbl.Size = UDim2.new(1,-20,1,0)
    lbl.Position = UDim2.new(0,10,0,0); lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200,255,200); lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham; lbl.Text = text; lbl.TextWrapped = true
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.25,0,0.05,0)
    }):Play()
    task.delay(5, function()
        if not (frame and frame.Parent) then return end
        local t = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.25,0,-0.1,0)
        })
        t.Completed:Connect(function() if frame then frame:Destroy() end end)
        t:Play()
    end)
end

-- fn57: toca som "Blop" do jogo
local function fn57_blop()
    pcall(function()
        local sounds = service:FindFirstChild("Sounds")
        sounds = sounds and sounds:FindFirstChild("Sfx")
        sounds = sounds and sounds:FindFirstChild("Blop")
        if not sounds then return end
        local clone = sounds:Clone()
        clone.Parent = v88.Frame
        Debris:AddItem(clone, 0.5)
        clone:Play()
    end)
end

-- fn59: userId de username
local function fn59(name)
    if name == "" then return localPlayer.UserId end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name or p.DisplayName == name then return p.UserId end
    end
    local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
    return ok and id or localPlayer.UserId
end

-- fn56_notif: obtém módulo de notificação
local function fn56_notif()
    if module then return module end
    pcall(function()
        local ctrl = service:WaitForChild("Controllers", 5):WaitForChild("NotificationController", 5)
        module = require(ctrl)
    end)
    return module
end

-- fn55_test: envia notificação de teste
local function fn55_test(avatarUser, msg)
    local user = tostring(avatarUser or ""):gsub("^%s+",""):gsub("%s+$","")
    local text = tostring(msg or ""):gsub("^%s+",""):gsub("%s+$","")
    if text == "" then fn32("Test Notification: enter a message first", Color3.fromRGB(200,200,90)); return end
    task.spawn(function()
        fn57_blop()
        local uid = fn59(user)
        local mod = fn56_notif()
        if mod then
            if pcall(function() mod:Notify(text, 5, nil, "Top", uid) end) then
                fn32("Test Notification sent via controller: " .. text, Color3.fromRGB(120,200,120))
                return
            end
        end
        fn58(text, uid)
        fn32("Test Notification sent via fallback GUI: " .. text, Color3.fromRGB(120,200,120))
    end)
end

-- ── panelSize flag (persist tamanho) ─────────────────────────
lib.Flags.panelSize = {
    Kind = "table",
    Get  = function() local w, h = v88.GetSize(); return { W = w, H = h } end,
    Set  = function(v)
        if type(v) ~= "table" then return end
        local w, h = tonumber(v.W), tonumber(v.H)
        if w and h then v88.SetSize(w, h) end
    end,
}

-- ── fn53: atualiza label Whitelist ───────────────────────────
local whitelist_kv_setter = nil
local function fn53()
    if whitelist_kv_setter then
        if premium then whitelist_kv_setter("✓ " .. tostring(discord or "User"))
        else whitelist_kv_setter("Locked") end
    end
    fn48()
end

-- ── fn54: painel Key System ──────────────────────────────────
local v93 = nil
local function fn54()
    if v93 and v93.Gui and v93.Gui.Parent then v93.SetVisible(true); return end
    v93 = lib.CreatePanel({
        Name = "vonKeySystem", Title = "VON KEY SYSTEM", Icon = "key-round",
        Width = 380, Height = 240, ClampToScreen = true,
    })
    local content = v93.Content
    lib.CreateParagraph(content, {
        Title   = premium and "Premium" or "Whitelist required",
        Content = premium and ("Signed in as " .. tostring(discord) .. ". " .. (tbl32.expires == math.huge and "Lifetime key." or "Key expires in " .. math.floor(tbl32.expires / 86400) .. " day(s)."))
            or [[The AI features need a key. Get one in the Discord, then put this line ABOVE the loadstring in your executor and re-execute:

script_key = "YOUR-KEY";]],
    })
    if typeof(setclipboard) == "function" and not premium then
        lib.CreateButton(content, {
            Text = "Copy loader template",
            Tooltip = "Paste into your executor, then swap in your key",
            OnClick = function()
                setclipboard("script_key = \"PASTE-YOUR-KEY\";\nloadstring(game:HttpGet(\"https://api.luarmor.net/files/v4/loaders/4f6400411509c4f698f893d1a8ad2684.lua\"))()")
                lib.ShowNotification("VON Key System", "Loader copied", 3)
            end,
        })
    end
    if typeof(setclipboard) == "function" then
        lib.CreateButton(content, {
            Text = premium and "Discord" or "Purchase",
            OnClick = function()
                setclipboard("https://discord.gg/rNvAU6cjVB")
                lib.ShowNotification("VON Key System", "Link copied to clipboard", 3)
            end,
        })
    end
end

-- ── fn56_preview: painel Premium Preview ─────────────────────
local v94 = nil
local function fn56_preview()
    if v94 and v94.Gui and v94.Gui.Parent then v94.SetVisible(true); return end
    v94 = lib.CreatePanel({
        Name = "vonPremiumPreview", Title = "VON PREMIUM PREVIEW", SubTitle = "look only",
        Icon = "eye", Width = 560, Height = 310,
        Tabs = {
            { Name = "Main",        Icon = "house"  },
            { Name = "Triggers",    Icon = "zap"    },
            { Name = "Admin Abuse", Icon = "shield" },
            { Name = "AI",          Icon = "bot"    },
            { Name = "UI",          Icon = "palette"},
            { Name = "Status",      Icon = "activity"},
        },
        TabSide = "left", TabWidth = 140, DefaultTab = 1,
        Discord = true, ClampToScreen = true, Scaler = true,
        MinSize = { 320, 220 }, MaxSize = { 900, 700 },
    })
    local locked = tbl14.locked
    local function dis(w) w.SetDisabled(true); return w end
    local function noEdit(w)
        if w.TextBox then w.TextBox.TextEditable = false end
        if w.Frame then
            for _, d in ipairs(w.Frame:GetDescendants()) do
                if d:IsA("TextBox") then d.TextEditable = false end
            end
        end
        return w
    end
    local pt1 = v94.GetTab(1)
    lib.CreateParagraph(pt1, { Title = "Premium", Content = "This is the premium panel, every tab of it, to look at. Nothing in here works – it is a picture of the real thing. Get a key to unlock all of it." })
    lib.CreateKeyValue(pt1, { Label = "Whitelist", Value = "✓ Premium", Tooltip = "AI features need a Luarmor key on the loader line" })
    lib.CreateButton(pt1, { Text = "Key System / Whitelist", Tooltip = "The one live button in here: the purchase link and loader template", OnClick = fn54 })
    dis(lib.CreateToggle(pt1, { Label = "Auto Enter Code", Default = true }))
    dis(lib.CreateButton(pt1, { Text = "Cancel Current Code", OnClick = locked }))
    dis(lib.CreateButton(pt1, { Text = "Apply Recommended Config (Full)", OnClick = locked }))
    local pc = lib.CreateSection(pt1, { Title = "Detection & Capture", Icon = "radar", Open = false, Tooltip = "How notifications are read, and how many are collected before a code is submitted." }).Content
    lib.CreateDropdown(pc, { Label = "Code Entry", Options = { "Firesignal", "Remote" }, Default = "Remote", Placeholder = "Remote", OnChanged = locked })
    lib.CreateDropdown(pc, { Label = "Scan Source", Options = { "ChildAdded", "Controller" }, Default = "Controller", Placeholder = "Controller", OnChanged = locked })
    noEdit(lib.CreateTextInput(pc, { Label = "Submit Code After",  Placeholder = "0", Default = "3", Width = 44, NumericOnly = true }))
    noEdit(lib.CreateTextInput(pc, { Label = "Submit Riddle After", Placeholder = "0", Default = "1", Width = 44, NumericOnly = true }))
    lib.CreateDropdown(pc, { Label = "Also Redeem At", Options = { "1","2","3","4" }, Multi = true, Placeholder = "off", OnChanged = locked })
    noEdit(lib.CreateTextInput(pc, { Label = "Chars After Trigger", Placeholder = "0", Default = "10", Width = 44, NumericOnly = true }))
    dis(lib.CreateToggle(pc, { Label = "One Line Isn't Riddle", Default = false }))
    local mc = lib.CreateSection(pt1, { Title = "Manual Overrides", Icon = "wrench", Open = false, Tooltip = "Force a scan or an AI answer right now." }).Content
    dis(lib.CreateButton(mc, { Text = "Force Scan + Code", OnClick = locked }))
    lib.CreateKeybind(mc, { Label = "Force Scan Key", OnChanged = locked })
    dis(lib.CreateButton(mc, { Text = "Force AI Answer", OnClick = locked }))
    lib.CreateKeybind(mc, { Label = "Force AI Key", OnChanged = locked })
    local tc2 = lib.CreateSection(pt1, { Title = "Test Notification", Icon = "flask-conical", Open = false }).Content
    lib.CreateParagraph(tc2, { Title = "Heads up", Content = "This fires a genuine Top notification, so the scanner will treat it as real." })
    noEdit(lib.CreateTextInput(tc2, { Label = "Avatar User", Placeholder = "blank = you", Width = 150 }))
    noEdit(lib.CreateTextInput(tc2, { Label = "Message", Placeholder = "notification text", Width = 150 }))
    dis(lib.CreateButton(tc2, { Text = "Send Test Notification", OnClick = locked }))
    noEdit(lib.CreateInputList(v94.GetTab(2), { Label = "Triggers  (blank = all)", Count = 10, Height = 200, Defaults = { "code is","the code is","use code","question is" }, Placeholder = function(i) return "keyword "..i end }))
    local at3 = v94.GetTab(3)
    local ac3 = lib.CreateSection(at3, { Title = "Character", Icon = "person-standing", Open = false }).Content
    dis(lib.CreateToggle(ac3, { Label = "Anti Ragdoll" })); dis(lib.CreateToggle(ac3, { Label = "Anchor Player" }))
    dis(lib.CreateToggle(lib.CreateSection(at3, { Title = "World", Icon = "earth", Open = false }).Content, { Label = "Auto Buy" }))
    local ac5 = lib.CreateSection(at3, { Title = "Performance", Icon = "gauge", Open = false }).Content
    dis(lib.CreateToggle(ac5, { Label = "FPS Booster  (not destructive)" }))
    lib.CreateSlider(ac5, { Label = "FPS Cap", Min = 5, Max = 240, Default = 60, Step = 5, Format = "%d fps", OnChanged = locked })
    dis(lib.CreateToggle(ac5, { Label = "FPS Optimizer  (destructive)" }))
    local at4 = v94.GetTab(4)
    dis(lib.CreateToggle(at4, { Label = "Use AI Answers", Default = true }))
    local ac6 = lib.CreateSection(at4, { Title = "Provider & Key", Icon = "key-round", Open = false }).Content
    lib.CreateDropdown(ac6, { Label = "Provider", Options = tbl25, Default = "Groq", OnChanged = locked })
    noEdit(lib.CreateTextInput(ac6, { Label = "API Key", Placeholder = "paste key…", Width = 190 }))
    lib.CreateDropdown(ac6, { Label = "Model", Options = tbl27.groq, Default = tbl27.groq[1], OnChanged = locked })
    noEdit(lib.CreateTextInput(ac6, { Label = "Custom Model ID", Placeholder = "blank = use preset", Width = 190 }))
    local ac7 = lib.CreateSection(at4, { Title = "Riddle Detection", Icon = "puzzle", Open = false }).Content
    noEdit(lib.CreateTextInput(ac7, { Label = "Min Length", Placeholder = "0", Default = "20", Width = 44, NumericOnly = true }))
    noEdit(lib.CreateTextInput(ac7, { Label = "Min Spaces", Placeholder = "0", Default = "1",  Width = 44, NumericOnly = true }))
    local at5 = v94.GetTab(5)
    local ac9 = lib.CreateSection(at5, { Title = "Theme & Accent", Icon = "palette", Open = false }).Content
    local thnames = lib.GetThemeNames(); local thcaps = {}
    for i,n in ipairs(thnames) do thcaps[i] = n:sub(1,1):upper()..n:sub(2) end
    lib.CreateDropdown(ac9, { Label = "Theme", Options = thcaps, Default = tbl22.Name:sub(1,1):upper()..tbl22.Name:sub(2), OnChanged = locked })
    lib.CreateColorPicker(ac9, { Label = "Accent Colour", Default = accent, OnChanged = locked })
    local ac10 = lib.CreateSection(at5, { Title = "Gradient Accent", Icon = "layers", Open = false }).Content
    dis(lib.CreateToggle(ac10, { Label = "Gradient Accent", Default = tbl21.Enabled }))
    lib.CreateColorPicker(ac10, { Label = "Gradient Colour", Default = tbl21.Colour, OnChanged = locked })
    dis(lib.CreateToggle(ac10, { Label = "Animated Gradient", Default = false }))
    local previewLog = lib.CreateStatusLog(v94.GetTab(6), { Height = 185, MaxLines = 200 })
    previewLog.Log("Whitelist: premium session as Premium (script v"..tbl32.version..")", Color3.fromRGB(120,200,80))
    previewLog.Log("Code Entry method → remote")
    previewLog.Log("Scan Source → controller")
    previewLog.Log("Classified as riddle (63 chars / 11 spaces vs min 20 / 1) – collecting 1 notification(s)", Color3.fromRGB(255,200,90))
    previewLog.Log("Notification #1/1 (AI): what is the rarest mutation in the game right now")
    previewLog.Log("AI answered in 0.4s – submitting", Color3.fromRGB(120,200,120))
    previewLog.Log("This is a preview – the real log is on your own Status tab.", Color3.fromRGB(255,100,90))
end

-- ══ STATUS TAB ════════════════════════════════════════════════
v86 = lib.CreateStatusLog(tabStatus, { Height = 185, MaxLines = 200 })

-- ══ MAIN TAB (v99) ════════════════════════════════════════════
do
    local kv = lib.CreateKeyValue(v99, {
        Label   = "Whitelist",
        Value   = "✓ " .. tostring(discord or "User"),
        Tooltip = "AI features need a Luarmor key on the loader line",
    })
    whitelist_kv_setter = kv.SetValue

    lib.CreateButton(v99, {
        Text    = "Key System / Whitelist",
        Tooltip = "Your tier, key expiry, and how to unlock the AI",
        OnClick = fn54,
    })

    tbl14.free(lib.CreateButton(v99, {
        Text    = "Preview Premium",
        Icon    = "eye",
        Tooltip = "Opens a look-only copy of everything a key unlocks. Nothing in it works.",
        OnClick = fn56_preview,
    }))

    lib.CreateToggle(v99, {
        Label     = "Auto Enter Code",
        Default   = true,
        Flag      = "autoCode",
        OnChanged = function(v)
            flag19 = v
            fn48()
        end,
    })

    tbl14.paid(lib.CreateButton(v99, {
        Text    = "Cancel Current Code",
        Tooltip = "Drops the code in progress and any pending AI answer. Next trigger starts fresh.",
        OnClick = function()
            local had = flag20 or flag22 or n35 > 0
            fn35(); flag22 = false; vonCodeRedeemer.lastCode = nil
            if had then fn32("Cancelled – dropped the code in progress; ready for the next trigger", Color3.fromRGB(255,200,90))
            else fn32("Nothing in progress – ready for the next trigger") end
        end,
    }))

    -- Apply Recommended: Free (Firesignal + ChildAdded) / Full (Remote + Controller)
    do
        local function applyFree()
            tbl31.entryMethod = "Firesignal"; tbl31.scanMode = "ChildAdded"
            str13 = "firesignal"; str14 = "childadded"
            if v96 then v96.Set("Firesignal") end
            if v97 then v97.Set("ChildAdded") end
            fn32("Recommended config (Free) applied"); fn48()
        end
        local function applyFull()
            tbl31.entryMethod = "Remote"; tbl31.scanMode = "Controller"
            str13 = "remote"; str14 = "controller"
            if v96 then v96.Set("Remote") end
            if v97 then v97.Set("Controller") end
            fn32("Recommended config (Full) applied"); fn48()
        end
        local v95 = lib.CreateButton(v99, {
            Text = "Apply Recommended Config (Free)",
            Tooltip = "Applies our recommended settings for free users. Firesignal + ChildAdded.",
            Confirm = true, ConfirmText = "Apply? Overwrites those settings",
            OnClick = applyFree,
        })
        tbl14.paid(lib.CreateButton(v99, {
            Text = "Apply Recommended Config (Full)",
            Tooltip = "Remote entry, Controller scan, AI on. For premium users.",
            Confirm = true, ConfirmText = "Apply? Overwrites those settings",
            OnClick = applyFull,
        }))
    end

    -- Detection & Capture
    local capture = lib.CreateSection(v99, {
        Title = "Detection & Capture", Icon = "radar", Open = true,
        Tooltip = "How notifications are read, and how many are collected before a code is submitted.",
    }).Content

    v96 = lib.CreateDropdown(capture, {
        Label = "Code Entry",
        Options = { "Firesignal", "Remote" },
        Default = tbl31.entryMethod,
        Placeholder = "Firesignal",
        Tooltip = "Firesignal types and clicks Confirm. Remote calls the code remote directly.",
        Flag = "entryMethod",
        OnChanged = function(v)
            if v == nil then return end
            tbl31.entryMethod = v
            str13 = v == "Remote" and "remote" or "firesignal"
            fn32("Code Entry method → " .. str13); fn48()
        end,
    })

    v97 = lib.CreateDropdown(capture, {
        Label = "Scan Source",
        Options = { "ChildAdded", "Controller" },
        Default = tbl31.scanMode,
        Placeholder = "ChildAdded",
        Tooltip = "ChildAdded watches PlayerGui text. Controller intercepts earlier.",
        Flag = "scanMode",
        OnChanged = function(v)
            if v == nil then return end
            tbl31.scanMode = v
            str14 = v == "Controller" and "controller" or "childadded"
            fn32("Scan Source → " .. str14); fn48()
        end,
    })

    for _, flagName in ipairs({ "entryMethod", "scanMode" }) do
        local f = lib.Flags[flagName]
        if f then f.Get = function() return tbl31[flagName] end end
    end

    fn50(lib.CreateTextInput(capture, {
        Label = "Submit Code After", Placeholder = "0", Default = "3", Width = 44, NumericOnly = true,
        Tooltip = "Notifications to collect when the first one is a plain code segment. Recommended: 3.",
        Flag = "codeCount",
        OnSubmit = function(v) n32 = tonumber(v) or 0; fn35(); fn48() end,
    }))

    fn50(lib.CreateTextInput(capture, {
        Label = "Submit Riddle After", Placeholder = "0", Default = "1", Width = 44, NumericOnly = true,
        Tooltip = "Notifications to collect when the first one meets the AI thresholds (a riddle). Recommended: 1.",
        Flag = "riddleCount",
        OnSubmit = function(v) n33 = tonumber(v) or 0; fn35(); fn48() end,
    }))

    lib.CreateDropdown(capture, {
        Label = "Also Redeem At", Options = { "1","2","3","4" }, Multi = true, Placeholder = "off",
        Tooltip = "Optional. Also submits the code so far at ticked notifications.",
        Flag = "retypeAt",
        OnChanged = function(v)
            tbl28 = {}
            for _, s in ipairs(v or {}) do
                local n = tonumber(s); if n then tbl28[n] = true end
            end
            fn48()
        end,
    })

    do
        local w = tbl14.paid(fn50(lib.CreateTextInput(capture, {
            Label = "Chars After Trigger", Placeholder = "0", Default = "10", Width = 44, NumericOnly = true,
            Tooltip = "Characters after the trigger that mean the content is in the same notification.",
            Flag = "inlineMinChars",
            OnSubmit = function(v) tbl29.InlineMin = tonumber(v) or 0; fn35(); fn48() end,
        })))
    end

    tbl14.paid(lib.CreateToggle(capture, {
        Label = "One Line Isn't Riddle", Default = false,
        Tooltip = "On: one-line notifications are submitted as plain codes, not sent to the AI.",
        Flag = "inlineAsCode",
        OnChanged = function(v)
            tbl29.InlineCode = v
            fn32("One-line notifications → " .. (v and "plain code" or "riddle (AI)")); fn48()
        end,
    }))

    -- Manual Overrides
    local manual = lib.CreateSection(v99, {
        Title = "Manual Overrides", Icon = "wrench", Open = false,
        Tooltip = "Force a scan or an AI answer right now, and bind either of them to a key.",
    }).Content

    local function forceScan()
        local count = n32 > 0 and n32 or 1
        fn35()
        if flag22 then flag22 = false; fn32("Force Scan: Force AI disarmed - the scan captures verbatim") end
        flag20 = true; n34 = count; flag21 = true
        fn32("Force Scan started – collecting " .. count .. " notification(s)", Color3.fromRGB(255,200,90))
    end

    local function forceAI()
        if flag21 then
            fn32("Force AI: denied – a Force Scan is collecting verbatim. Let it finish, or start the scan again", Color3.fromRGB(255,100,90))
            return
        end
        flag22 = true
        fn32("Force AI armed – next notification goes to the AI" .. (flag20 and "" or " and starts the code"), Color3.fromRGB(255,200,90))
    end

    lib.CreateButton(manual, { Text = "Force Scan + Code", Tooltip = "Capture the next N notifications verbatim, then redeem.", OnClick = forceScan })
    local keyScan = lib.CreateKeybind(manual, { Label = "Force Scan Key", Tooltip = "Press this key to run Force Scan + Code", Flag = "forceScanKey", OnChanged = fn48 })
    tbl14.paid(lib.CreateButton(manual, { Text = "Force AI Answer", Tooltip = "Next notification goes to the AI, ignoring toggle and thresholds.", OnClick = forceAI }))
    local keyAI = tbl14.paid(lib.CreateKeybind(manual, { Label = "Force AI Key", Tooltip = "Press this key to arm Force AI Answer", Flag = "forceAiKey", OnChanged = fn48 }))

    local keybindDebounce = 0
    UserInputService.InputBegan:Connect(function(input, gp)
        if vonCodeRedeemer.dead or gp then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == Enum.KeyCode.Unknown then return end
        if os.clock() - keybindDebounce < 0.2 then return end
        if keyScan and input.KeyCode == keyScan.GetValue() then
            keybindDebounce = os.clock(); forceScan()
        elseif keyAI and input.KeyCode == keyAI.GetValue() then
            keybindDebounce = os.clock(); forceAI()
        end
    end)

    -- Test Notification
    local testSec = lib.CreateSection(v99, {
        Title = "Test Notification", Icon = "flask-conical", Open = false,
        Tooltip = "Fire a fake Top notification to test the scanner without waiting for a real code.",
    }).Content
    lib.CreateParagraph(testSec, {
        Title   = "Heads up",
        Content = "This fires a genuine Top notification, so the scanner will treat it as real. With Auto Enter Code on, a message that matches your triggers will start a collection and eventually submit a code.",
    })
    local tiAvatarUser = lib.CreateTextInput(testSec, { Label = "Avatar User", Placeholder = "blank = you", Width = 150, Tooltip = "Username to show the avatar of. Cosmetic only." })
    local tiMessage    = lib.CreateTextInput(testSec, { Label = "Message", Placeholder = "notification text", Width = 150, Tooltip = "Sent as a Top notification. Include a trigger keyword to test the full collect + redeem path." })
    lib.CreateButton(testSec, {
        Text = "Send Test Notification", Tooltip = "Sends a real Top notification.",
        OnClick = function() fn55_test(tiAvatarUser.GetValue(), tiMessage.GetValue()) end,
    })
end

-- ══ TRIGGERS TAB (v98) ════════════════════════════════════════
lib.CreateInputList(v98, {
    Label = "Triggers  (blank = all)", Count = 10, Height = 200,
    Defaults = { "code is", "the code is", "use code", "question is" },
    Placeholder = function(i) return "keyword " .. i end,
    Flag = "triggers",
    OnChanged = function(list)
        if type(list) == "table" then tbl30 = list end
        fn48()
    end,
})

-- ══ ADMIN ABUSE TAB ═══════════════════════════════════════════
do
    local secChar = lib.CreateSection(tabAdmin, { Title = "Character", Icon = "person-standing", Open = true, Tooltip = "Toggles that only affect your own character." }).Content

    tbl14.paid(lib.CreateToggle(secChar, {
        Label = "Anti Ragdoll", Default = tbl31.antiRagdoll,
        Tooltip = "Strips ragdoll constraints and forces the humanoid back to Running the moment it gets ragdolled.",
        OnChanged = function(v)
            flag23 = v; tbl31.antiRagdoll = v
            if v then fn40() end
            fn32("Anti Ragdoll: " .. (v and "ON" or "OFF")); fn48()
        end,
    }))

    tbl14.paid(lib.CreateToggle(secChar, {
        Label = "Anchor Player", Default = tbl31.anchorPlayer,
        Tooltip = "Anchors HumanoidRootPart: immune to knockback, falling and conveyors, but you can float.",
        OnChanged = function(v)
            tbl31.anchorPlayer = v; fn41(v)
            fn32("Anchor Player: " .. (v and "ON" or "OFF")); fn48()
        end,
    }))

    local secWorld = lib.CreateSection(tabAdmin, { Title = "World", Icon = "earth", Open = true, Tooltip = "Toggles that interact with the map around you." }).Content

    tbl14.paid(lib.CreateToggle(secWorld, {
        Label = "Auto Buy", Default = tbl31.autoBuy,
        Tooltip = "Fires the nearest buy/purchase/claim/steal/collect ProximityPrompt in range.",
        OnChanged = function(v)
            flag24 = v; tbl31.autoBuy = v
            if v then fn42() end
            fn32("Auto Buy: " .. (v and "ON" or "OFF")); fn48()
        end,
    }))

    local secPerf = lib.CreateSection(tabAdmin, { Title = "Performance", Icon = "gauge", Open = false, Tooltip = "Reversible FPS Booster and FPS cap, plus the destructive Optimizer." }).Content

    tbl14.paid(lib.CreateToggle(secPerf, {
        Label = "FPS Booster  (not destructive)", Default = tbl31.fpsBoost,
        Tooltip = "Blanks textures, flattens materials, disables particles, lights and effects. Off restores all.",
        OnChanged = function(v)
            tbl31.fpsBoost = v
            if v then tbl13.start() else tbl13.stop() end
            fn48()
        end,
    }))

    tbl14.paid(lib.CreateSlider(secPerf, {
        Label = "FPS Cap", Min = 5, Max = 240, Default = tbl31.fpsCap or 60, Step = 5, Format = "%d fps",
        Tooltip = "Caps the frame rate with setfpscap. 60 is Roblox's default.",
        Flag = "fpsCap",
        OnChanged = function(v)
            tbl31.fpsCap = v; tbl13.applyCap(v); fn48()
        end,
    }))

    tbl14.paid(lib.CreateToggle(secPerf, {
        Label = "FPS Optimizer  (destructive)", Default = false,
        Tooltip = "Strips textures, particles, lights and post-effects every 2s. PERMANENT: rejoin to undo.",
        OnChanged = function(v)
            flag26 = v
            if v then
                fn46_optimizer_hooks()
                fn56_optimizer(); fn57_lighting()
                fn32("Optimizer: initial pass running…", Color3.fromRGB(255,100,90))
                task.spawn(function()
                    pcall(fn60_optimizer)
                    fn32("Optimizer: initial pass complete", Color3.fromRGB(120,200,120))
                end)
            else
                fn32("FPS Optimizer: OFF – rejoin to restore visuals")
            end
            fn48()
        end,
    }))

    lib.CreateParagraph(secPerf, {
        Title   = "FPS Optimizer is destructive",
        Content = "It deletes the map's visuals for good. Turning it back off does not bring anything back – you have to rejoin.\n\nIt can also delete ProximityPrompts, which breaks Auto Buy.\n\nIt is never saved, so it always starts off.",
    })
end

-- ══ AI TAB ════════════════════════════════════════════════════
do
    tbl14.paid(lib.CreateToggle(tabAI, {
        Label = "Use AI Answers", Default = v85,
        Tooltip = "Riddles go to the AI and its answer is what gets redeemed.",
        OnChanged = function(v) v85 = v; fn48() end,
    }))

    local secProv = lib.CreateSection(tabAI, { Title = "Provider & Key", Icon = "key-round", Open = true, Tooltip = "Which service answers the riddle, the key it needs, and the model to ask for." }).Content

    local ddModel = nil
    tbl14.paid(lib.CreateDropdown(secProv, {
        Label = "Provider", Options = tbl25, Default = "Groq",
        Tooltip = "All free and none needs a card. Every one needs a key you paste below.",
        OnChanged = function(v)
            if not v then return end
            str9  = tbl24[v] or "groq"
            str11 = tbl27[str9] and tbl27[str9][1] or ""
            if ddModel then ddModel.SetOptions(tbl27[str9] or {}); ddModel.Set(str11) end
            fn32("AI provider → " .. str9 .. " / " .. fn30()); fn48()
        end,
    }))

    fn50(tbl14.paid(lib.CreateTextInput(secProv, {
        Label = "API Key", Placeholder = "paste key…", Width = 190,
        Tooltip = "Your own provider key. There is no built-in one.", Flag = "aiUserKey",
        OnSubmit = function(v)
            str10 = (v or ""):gsub("^%s+",""):gsub("%s+$",""); fn48()
        end,
    })))

    ddModel = tbl14.paid(lib.CreateDropdown(secProv, {
        Label = "Model", Options = tbl27.groq, Default = tbl27.groq[1],
        Tooltip = "Presets for the selected provider. Overridden by Custom Model ID below.",
        OnChanged = function(v) str11 = v or ""; fn32("AI model → " .. fn30()); fn48() end,
    }))

    fn50(tbl14.paid(lib.CreateTextInput(secProv, {
        Label = "Custom Model ID", Placeholder = "blank = use preset", Width = 190,
        Tooltip = "Any model ID the provider accepts. Overrides the Model dropdown.",
        OnSubmit = function(v) str12 = (v or ""):gsub("^%s+",""):gsub("%s+$",""); fn48() end,
    })))

    local secRiddle = lib.CreateSection(tabAI, { Title = "Riddle Detection", Icon = "puzzle", Open = false, Tooltip = "The two thresholds that separate a riddle from a plain code. Both have to be met." }).Content
    fn50(tbl14.paid(lib.CreateTextInput(secRiddle, {
        Label = "Min Length", Placeholder = "0", Default = "20", Width = 44, NumericOnly = true,
        Tooltip = "A notification this long, with at least Min Spaces spaces, is a riddle.",
        OnSubmit = function(v) tbl29.MinChars = tonumber(v) or 20; fn48() end,
    })))
    fn50(tbl14.paid(lib.CreateTextInput(secRiddle, {
        Label = "Min Spaces", Placeholder = "0", Default = "1", Width = 44, NumericOnly = true,
        Tooltip = "Second half of the riddle test. Codes have no spaces, so even 1 separates them.",
        OnSubmit = function(v) tbl29.MinSpaces = tonumber(v) or 1; fn48() end,
    })))

    local secGetKey = lib.CreateSection(tabAI, { Title = "Getting a Key", Icon = "key-round", Open = false, Tooltip = "Copy a provider's key page to your clipboard. All four are free." }).Content
    lib.CreateParagraph(secGetKey, {
        Title   = "There is no built-in key",
        Content = "Premium sessions make one on a provider's site and paste it into API Key above – all four are free and none needs a card. Cerebras is the fastest, so start there.",
    })
    for _, provName in ipairs({ "Cerebras", "Groq", "SambaNova", "Gemini" }) do
        tbl14.paid(lib.CreateButton(secGetKey, {
            Text = "📋 " .. provName .. " key page",
            Tooltip = "Copy " .. provName .. " key page URL to clipboard.",
            OnClick = function()
                local url = tbl26[tbl24[provName]]
                if typeof(setclipboard) == "function" and url then
                    setclipboard(url); lib.ShowNotification("AI", provName .. " URL copied", 3)
                else fn32("AI: setclipboard not available – open manually: " .. tostring(url)) end
            end,
        }))
    end
end

-- ══ UI TAB ════════════════════════════════════════════════════
do
    local secTheme = lib.CreateSection(tabUI, { Title = "Theme & Accent", Icon = "palette", Open = true, Tooltip = "The whole palette, plus the highlight colour on top of it." }).Content
    local thnames = lib.GetThemeNames(); local thcaps = {}
    for i, n in ipairs(thnames) do thcaps[i] = n:sub(1,1):upper()..n:sub(2) end
    lib.CreateDropdown(secTheme, {
        Label = "Theme", Options = thcaps, Default = tbl22.Name:sub(1,1):upper()..tbl22.Name:sub(2),
        Tooltip = "Swaps the whole palette.",
        OnChanged = function(v)
            if not v then return end
            tbl22.Name = v:lower()
            pcall(function() lib.SetTheme(tbl22.Name) end)
            accent = lib.Theme.Accent; fn48()
        end,
    })
    lib.CreateColorPicker(secTheme, {
        Label = "Accent Colour", Default = accent,
        Tooltip = "Repaints most of the UI right away.",
        OnChanged = function(v) accent = v; fn29(v); fn48() end,
    })

    local secGrad = lib.CreateSection(tabUI, { Title = "Gradient Accent", Icon = "layers", Open = false, Tooltip = "Blend the accent into a second colour, optionally animated." }).Content
    lib.CreateToggle(secGrad, {
        Label = "Gradient Accent", Default = tbl21.Enabled,
        Tooltip = "Blends the accent into a second colour across fills, the active tab, title and outline.",
        OnChanged = function(v)
            tbl21.Enabled = v
            if v then lib.Theme.AccentGrad1 = lib.Theme.Accent; lib.Theme.AccentGrad2 = tbl21.Colour end
            fn48()
        end,
    })
    lib.CreateColorPicker(secGrad, {
        Label = "Gradient Colour", Default = tbl21.Colour,
        Tooltip = "The far end of the accent gradient.",
        OnChanged = function(v)
            tbl21.Colour = v
            if tbl21.Enabled then lib.Theme.AccentGrad2 = v end
            fn48()
        end,
    })
    lib.CreateToggle(secGrad, {
        Label = "Animated Gradient", Default = false,
        Tooltip = "Slides the gradient back and forth.",
        OnChanged = function() end,
    })
    lib.CreateParagraph(lib.CreateSection(tabUI, { Title = "How These Work", Icon = "book-open", Open = false, Tooltip = "What each appearance setting actually does, and when it applies." }).Content, {
        Title   = "About the colours",
        Content = "Theme swaps the whole palette; Accent Colour then overrides just the highlight on top of it. Gradient Accent blends the accent into the Gradient Colour across the fills, the active tab and the panel outline. Animated Gradient slides that blend back and forth.\n\nTo resize the panel, drag the grip in its bottom-right corner.",
    })
end

-- ══ INICIA ════════════════════════════════════════════════════
fn48()
tbl21.Collect and tbl21.Collect()
tbl22.Ready = true

fn36()
task.spawn(fn39)
fn34()

localPlayer.CharacterAdded:Connect(function()
    if vonCodeRedeemer.dead then return end
    task.delay(1, fn34)
end)

task.spawn(tbl12_run)
task.spawn(fn37)
-- tbl11 was removed in this version

-- aplica config guardada nos dropdowns/flags do lib
do
    local savedConf = lib.GetConfig("von_autocode")
    if type(savedConf) == "table" then
        if savedConf.entryMethod then
            local em = savedConf.entryMethod
            if v96 then v96.Set(em) end
            str13 = em == "Remote" and "remote" or "firesignal"
        end
        if savedConf.scanMode then
            local sm = savedConf.scanMode
            if v97 then v97.Set(sm) end
            str14 = sm == "Controller" and "controller" or "childadded"
        end
    end
end

-- startup logs
task.spawn(function()
    fn32("Whitelist: premium session as " .. tostring(discord) .. " (script v" .. tbl32.version .. ")", Color3.fromRGB(120, 200, 80))
    fn53()
    task.spawn(fn33)
    if fn31() then
        fn32("Game check: IN Steal a Brainrot (GameId " .. tostring(game.GameId) .. ")", Color3.fromRGB(120, 200, 80))
    else
        fn32("Game check: NOT in Steal a Brainrot (GameId " .. tostring(game.GameId) .. ") – AI still works, but its knowledge base is about Steal a Brainrot", Color3.fromRGB(255, 200, 90))
    end
    fn32("Script loaded – Luarmor removed, all features unlocked", Color3.fromRGB(120, 200, 80))
end)

-- telemetria (não crítico, sem impacto funcional)
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    local function getExec()
        if identifyexecutor then return identifyexecutor() end
        if getexecutorname then return getexecutorname() end
        if syn and syn.getexecutorname then return syn.getexecutorname() end
        if KRNL_LOADED then return "Krnl" end
        if fluxus then return "Fluxus" end
        if wave then return "Wave" end
        return "Unknown"
    end
    pcall(fn38, {
        type = "execution", script = "auto code redeemer",
        executor = getExec(),
        username = localPlayer.Name, userId = localPlayer.UserId,
    })
end)
