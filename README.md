# scripts

| Script | O que faz | Saída (pasta `workspace` do executor) |
| --- | --- | --- |
| `ScriptDumper.lua` | Decompila LocalScripts/ModuleScripts e salva cada um como `.lua` | `<Jogo> Dump/` e/ou `<Jogo> Dump.zip` |
| `PlaceSaver.lua` | Salva o jogo inteiro (mapa, GUIs, modelos, scripts decompilados) | `<Jogo> (<PlaceId>).rbxlx` — abre no Roblox Studio |

## PlaceSaver

- `Mode = "builtin"` (padrão) usa o salvador embutido em Lua puro.
- `Mode = "auto"` usa o `saveinstance()` do executor quando existe e cai no embutido se falhar. Em alguns executores esse arquivo dá "Invalid NetAsset type" no Studio.
- No modo embutido não dá para salvar Terrain, e Unions/alguns MeshParts podem vir incompletos (o cliente não expõe esses dados).
- Scripts de servidor não existem no cliente: aparecem só com um comentário.
- Para abrir: copie o `.rbxlx` para o PC e abra com **Arquivo > Abrir** no Roblox Studio (ou dois cliques).
