-- save_game.lua
-- Executa no Delta Executor para salvar o jogo atual como .rbxl
-- O arquivo salva na pasta workspace/ do Delta

local saveinstance = saveinstance or save_instance
if not saveinstance then
    warn("Seu executor nao suporta saveinstance()")
    return
end

local options = {
    Mode = "full",
    NilInstances = true,
    DecompileScripts = true,
    RemovePlayerCharacters = true,
    SavePlayers = false,
    IsolateLocalPlayer = false,
    IgnoreDefaultProperties = true,
}

local gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "game"
gameName = gameName:gsub("[^%w%s%-_]", ""):gsub("%s+", "_")
local fileName = gameName .. "_" .. game.PlaceId .. ".rbxl"

print("Salvando: " .. fileName .. " ...")
saveinstance(options)
print("Salvo na pasta workspace do Delta!")
