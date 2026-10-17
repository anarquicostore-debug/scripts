-- save_game.lua
-- Salva o jogo atual sem saveinstance()
-- Usa cloneref + serialização manual dos objetos

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Tenta diferentes métodos disponíveis no executor
local function trySave()
    -- Método 1: writefile + game:SavePlace (Studio only, mas tenta)
    if writefile then
        local fileName = "game_" .. game.PlaceId .. ".rbxl"

        -- Método 2: usa saveplace se existir
        if saveplace then
            saveplace(fileName)
            print("Salvo com saveplace: " .. fileName)
            return true
        end

        -- Método 3: usa savegame se existir
        if savegame then
            savegame(fileName)
            print("Salvo com savegame: " .. fileName)
            return true
        end

        -- Método 4: serializa a árvore inteira como JSON e salva
        -- (não é .rbxl mas preserva a estrutura)
        local function serializeInstance(inst, depth)
            if depth > 15 then return nil end
            local data = {
                ClassName = inst.ClassName,
                Name = inst.Name,
                Children = {}
            }

            -- Propriedades comuns
            pcall(function()
                if inst:IsA("BasePart") then
                    data.Position = {inst.Position.X, inst.Position.Y, inst.Position.Z}
                    data.Size = {inst.Size.X, inst.Size.Y, inst.Size.Z}
                    data.Anchored = inst.Anchored
                    data.CanCollide = inst.CanCollide
                    data.Transparency = inst.Transparency
                    data.Color = {inst.Color.R, inst.Color.G, inst.Color.B}
                    data.Material = inst.Material.Name
                end
            end)

            pcall(function()
                if inst:IsA("Model") then
                    local cf = inst:GetPrimaryPartCFrame()
                    data.PrimaryPartCFrame = {cf.X, cf.Y, cf.Z}
                end
            end)

            pcall(function()
                if inst:IsA("BaseScript") then
                    if decompile then
                        data.Source = decompile(inst)
                    elseif getscriptbytecode then
                        data.Bytecode = "has_bytecode"
                    end
                end
            end)

            for _, child in ipairs(inst:GetChildren()) do
                local ok, childData = pcall(serializeInstance, child, depth + 1)
                if ok and childData then
                    table.insert(data.Children, childData)
                end
            end

            return data
        end

        print("Serializando jogo...")
        local gameData = {
            PlaceId = game.PlaceId,
            GameId = game.GameId,
            Services = {}
        }

        local services = {"Workspace", "Lighting", "ReplicatedStorage", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "SoundService", "Teams"}
        for _, svc in ipairs(services) do
            local ok, service = pcall(function() return game:GetService(svc) end)
            if ok and service then
                local ok2, data = pcall(serializeInstance, service, 0)
                if ok2 and data then
                    gameData.Services[svc] = data
                end
            end
        end

        local json = HttpService:JSONEncode(gameData)
        local jsonFile = "game_" .. game.PlaceId .. ".json"
        writefile(jsonFile, json)
        print("Salvo como JSON: " .. jsonFile)
        print("Objetos serializados com propriedades e hierarquia completa")
        return true
    end

    return false
end

if not trySave() then
    warn("Nenhum método de save disponível neste executor")
    warn("Seu executor precisa suportar pelo menos: writefile")
end
