-- save_game.lua
-- Delta Executor - salva o jogo atual
-- Tenta todos os métodos disponíveis

-- Método 1: saveinstance (mais completo)
if saveinstance or save_instance then
    local si = saveinstance or save_instance
    local opts = {
        Mode = "full",
        NilInstances = true,
        DecompileScripts = true,
        RemovePlayerCharacters = true,
        SavePlayers = false,
        IsolateLocalPlayer = false,
        IgnoreDefaultProperties = true,
    }
    print("[1/1] Salvando com saveinstance...")
    si(opts)
    print("Salvo na pasta workspace do Delta!")
    return
end

-- Método 2: saveplace / savegame
if saveplace or savegame then
    local save = saveplace or savegame
    local name = "game_" .. game.PlaceId .. ".rbxl"
    print("[1/1] Salvando com saveplace...")
    save(name)
    print("Salvo: " .. name)
    return
end

-- Método 3: serialização manual completa via writefile
if not writefile then
    warn("Executor nao suporta nenhum metodo de save (precisa de writefile no minimo)")
    return
end

print("[save_game] Iniciando serialização manual...")

local HttpService = game:GetService("HttpService")

local SKIP_CLASSES = {
    ["Player"] = true, ["PlayerGui"] = true, ["Backpack"] = true,
    ["CoreGui"] = true, ["CoreScript"] = true,
    ["StatsItem"] = true, ["PluginGui"] = true,
}

local SKIP_NAMES = {
    ["Camera"] = true, ["Terrain"] = true,
}

local GUI_PROPS = {"Size", "Position", "AnchorPoint", "BackgroundColor3",
    "BackgroundTransparency", "BorderSizePixel", "Visible", "ZIndex",
    "LayoutOrder", "Text", "TextColor3", "TextSize", "TextScaled",
    "Font", "PlaceholderText", "Image", "ImageColor3", "ImageTransparency",
    "ScaleType", "SliceCenter", "AutoButtonColor", "Modal", "ClipsDescendants",
    "SizeConstraint", "Active", "Selectable", "TextXAlignment", "TextYAlignment",
    "TextWrapped", "RichText", "MaxVisibleGraphemes", "TextTransparency",
    "TextStrokeColor3", "TextStrokeTransparency", "Rotation",
}

local PART_PROPS = {"Size", "Position", "CFrame", "Anchored", "CanCollide",
    "Transparency", "Color", "BrickColor", "Material", "Shape", "Reflectance",
    "CastShadow", "CanQuery", "Massless",
}

local LIGHT_PROPS = {"TimeOfDay", "Brightness", "Ambient", "OutdoorAmbient",
    "ClockTime", "GeographicLatitude", "FogColor", "FogEnd", "FogStart",
    "GlobalShadows", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
}

local SOUND_PROPS = {"SoundId", "Volume", "Looped", "PlaybackSpeed",
    "Playing", "RollOffMode", "RollOffMaxDistance", "RollOffMinDistance",
}

local function safeGet(inst, propName)
    local ok, val = pcall(function() return inst[propName] end)
    if not ok then return nil end
    return val
end

local function serializeValue(val)
    if val == nil then return nil end
    local t = typeof(val)
    if t == "string" or t == "number" or t == "boolean" then
        return {type = t, value = val}
    elseif t == "Vector3" then
        return {type = "Vector3", value = {val.X, val.Y, val.Z}}
    elseif t == "Vector2" then
        return {type = "Vector2", value = {val.X, val.Y}}
    elseif t == "CFrame" then
        local comps = {val:GetComponents()}
        return {type = "CFrame", value = comps}
    elseif t == "Color3" then
        return {type = "Color3", value = {val.R, val.G, val.B}}
    elseif t == "BrickColor" then
        return {type = "BrickColor", value = val.Name}
    elseif t == "UDim2" then
        return {type = "UDim2", value = {val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset}}
    elseif t == "UDim" then
        return {type = "UDim", value = {val.Scale, val.Offset}}
    elseif t == "Rect" then
        return {type = "Rect", value = {val.Min.X, val.Min.Y, val.Max.X, val.Max.Y}}
    elseif t == "EnumItem" then
        return {type = "Enum", value = tostring(val)}
    elseif t == "NumberSequence" then
        local kps = {}
        for _, kp in ipairs(val.Keypoints) do
            table.insert(kps, {kp.Time, kp.Value, kp.Envelope})
        end
        return {type = "NumberSequence", value = kps}
    elseif t == "ColorSequence" then
        local kps = {}
        for _, kp in ipairs(val.Keypoints) do
            table.insert(kps, {kp.Time, kp.Value.R, kp.Value.G, kp.Value.B})
        end
        return {type = "ColorSequence", value = kps}
    elseif t == "NumberRange" then
        return {type = "NumberRange", value = {val.Min, val.Max}}
    else
        return {type = "string", value = tostring(val)}
    end
end

local function getPropsForClass(inst)
    local props = {}
    local cn = inst.ClassName

    -- Propriedades universais
    props["Name"] = {type = "string", value = inst.Name}

    -- BasePart
    if inst:IsA("BasePart") then
        for _, p in ipairs(PART_PROPS) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- GuiObject
    if inst:IsA("GuiObject") or inst:IsA("GuiBase2d") then
        for _, p in ipairs(GUI_PROPS) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- TextLabel/TextButton/TextBox
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        for _, p in ipairs({"Text","TextColor3","TextSize","TextScaled","Font","RichText","TextWrapped","TextXAlignment","TextYAlignment","TextTransparency","TextStrokeColor3","TextStrokeTransparency"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- ImageLabel/ImageButton
    if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
        for _, p in ipairs({"Image","ImageColor3","ImageTransparency","ScaleType","SliceCenter","ImageRectOffset","ImageRectSize"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- ScreenGui
    if inst:IsA("ScreenGui") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
        for _, p in ipairs({"Enabled","ResetOnSpawn","ZIndexBehavior","DisplayOrder","IgnoreGuiInset"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- UILayout
    if inst:IsA("UIListLayout") or inst:IsA("UIGridLayout") or inst:IsA("UITableLayout") then
        for _, p in ipairs({"FillDirection","HorizontalAlignment","VerticalAlignment","Padding","SortOrder","CellPadding","CellSize","FillDirectionMaxCells"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- UIPadding/UICorner/UIStroke/UIScale/UIAspectRatio
    if cn == "UIPadding" then
        for _, p in ipairs({"PaddingTop","PaddingBottom","PaddingLeft","PaddingRight"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end
    if cn == "UICorner" then
        local v = safeGet(inst, "CornerRadius")
        if v then props["CornerRadius"] = serializeValue(v) end
    end
    if cn == "UIStroke" then
        for _, p in ipairs({"Color","Thickness","Transparency","ApplyStrokeMode","LineJoinMode"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end
    if cn == "UIScale" then
        local v = safeGet(inst, "Scale")
        if v then props["Scale"] = serializeValue(v) end
    end
    if cn == "UIAspectRatioConstraint" then
        for _, p in ipairs({"AspectRatio","AspectType","DominantAxis"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end
    if cn == "UISizeConstraint" then
        for _, p in ipairs({"MaxSize","MinSize"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- Lighting
    if inst:IsA("Lighting") then
        for _, p in ipairs(LIGHT_PROPS) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- PostEffect
    if inst:IsA("PostEffect") then
        for _, p in ipairs({"Enabled","Size","Intensity","Brightness","Contrast","Saturation","TintColor","Threshold"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- Sound
    if inst:IsA("Sound") then
        for _, p in ipairs(SOUND_PROPS) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- Model
    if inst:IsA("Model") then
        local pp = safeGet(inst, "PrimaryPart")
        if pp then props["PrimaryPart"] = {type = "string", value = pp.Name} end
        local mc = safeGet(inst, "ModelStreamingMode")
        if mc then props["ModelStreamingMode"] = serializeValue(mc) end
    end

    -- Script source
    if inst:IsA("BaseScript") then
        if decompile then
            local ok, src = pcall(decompile, inst)
            if ok and src then props["Source"] = {type = "string", value = src} end
        end
        local disabled = safeGet(inst, "Disabled")
        if disabled ~= nil then props["Disabled"] = serializeValue(disabled) end
    end

    -- ModuleScript
    if cn == "ModuleScript" then
        if decompile then
            local ok, src = pcall(decompile, inst)
            if ok and src then props["Source"] = {type = "string", value = src} end
        end
    end

    -- Value objects
    if inst:IsA("ValueBase") then
        local v = safeGet(inst, "Value")
        if v ~= nil then props["Value"] = serializeValue(v) end
    end

    -- Decal/Texture
    if inst:IsA("Decal") then
        for _, p in ipairs({"Texture","Face","Color3","Transparency"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- SpecialMesh / Mesh
    if inst:IsA("DataModelMesh") then
        for _, p in ipairs({"MeshId","TextureId","Scale","Offset","MeshType","VertexColor"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- Weld / Motor6D / constraints
    if inst:IsA("JointInstance") then
        for _, p in ipairs({"C0","C1"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
        local p0 = safeGet(inst, "Part0")
        local p1 = safeGet(inst, "Part1")
        if p0 then props["Part0"] = {type = "string", value = p0:GetFullName()} end
        if p1 then props["Part1"] = {type = "string", value = p1:GetFullName()} end
    end

    -- ParticleEmitter / Beam / Trail
    if inst:IsA("ParticleEmitter") then
        for _, p in ipairs({"Texture","Rate","Speed","Lifetime","Size","Color","Transparency","Rotation","RotSpeed","SpreadAngle","Acceleration","Drag","LightEmission","LightInfluence","ZOffset","EmissionDirection","Enabled","LockedToPart","Shape"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- PointLight / SpotLight / SurfaceLight
    if inst:IsA("Light") then
        for _, p in ipairs({"Color","Brightness","Range","Enabled","Shadows","Angle","Face"}) do
            local v = safeGet(inst, p)
            if v ~= nil then props[p] = serializeValue(v) end
        end
    end

    -- Attachment
    if cn == "Attachment" then
        local cf = safeGet(inst, "CFrame")
        if cf then props["CFrame"] = serializeValue(cf) end
    end

    return props
end

local count = 0
local function serializeInstance(inst, depth)
    if depth > 20 then return nil end
    if SKIP_CLASSES[inst.ClassName] then return nil end
    if depth == 1 and SKIP_NAMES[inst.Name] then return nil end

    count = count + 1
    if count % 500 == 0 then
        print("[save_game] " .. count .. " objetos processados...")
        task.wait()
    end

    local data = {
        ClassName = inst.ClassName,
        Properties = getPropsForClass(inst),
        Children = {}
    }

    for _, child in ipairs(inst:GetChildren()) do
        local ok, childData = pcall(serializeInstance, child, depth + 1)
        if ok and childData then
            table.insert(data.Children, childData)
        end
    end

    return data
end

local services = {
    "Workspace", "Lighting", "ReplicatedStorage",
    "ServerStorage", "StarterGui", "StarterPack",
    "StarterPlayer", "SoundService", "Teams",
    "ReplicatedFirst", "Chat",
}

local gameData = {
    PlaceId = game.PlaceId,
    GameId = game.GameId,
    Version = 2,
    Services = {}
}

for i, svc in ipairs(services) do
    local ok, service = pcall(function() return game:GetService(svc) end)
    if ok and service then
        print("[save_game] (" .. i .. "/" .. #services .. ") " .. svc)
        local ok2, data = pcall(serializeInstance, service, 0)
        if ok2 and data then
            gameData.Services[svc] = data
        end
    end
end

local json = HttpService:JSONEncode(gameData)
local fileName = "game_" .. game.PlaceId .. ".json"
writefile(fileName, json)
print("[save_game] Concluido! " .. count .. " objetos salvos em: " .. fileName)
print("[save_game] Use json_to_rbxlx.py pra converter pra .rbxlx")
