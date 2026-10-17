# Prompt — Proteger um script com Luraph (sistema de atributos)

Cole o texto abaixo pra uma IA (ou use como checklist manual) pra aplicar a mesma
proteção que foi usada no `jumpforeggs.lua`. Vale pro Luraph **moderno**, que usa
`LPH_ATTRIBUTES(VM(...), PRESET(...))` — o mesmo que valida os presets
`FAST` / `BALANCED` / `SECURE`.

---

## PROMPT (copiar daqui pra baixo)

> Você vai adicionar proteção do **Luraph** ao meu script Lua/Luau, SEM mudar o
> comportamento dele. Siga exatamente estas regras:
>
> **1. No topo do arquivo**, antes de qualquer código, adicione o bloco de
> fallback (pra o script rodar normal quando NÃO está ofuscado):
>
> ```lua
> -- ─── LURAPH (proteção) ───────────────────────────────────────────────
> -- Fora do Luraph estas macros são no-op, então dá pra rodar/testar o
> -- script. Depois de passar pelo Luraph viram a proteção de verdade.
> if not LPH_OBFUSCATED then
>     LPH_ATTRIBUTES = function(...) end
>     VM = function(...) end
>     PRESET = function(...) end
> end
> ```
>
> **2. Em cada função que NÃO pode vazar**, coloque como **primeira instrução
> dentro do corpo** da função:
>
> ```lua
> LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
> ```
>
> Exemplos de como fica:
>
> ```lua
> -- função normal
> local function minhaFuncao(a, b)
>     LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
>     -- ... resto igual ...
> end
>
> -- função de tabela
> function Fly.travel(getTarget, opts)
>     LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
>     -- ...
> end
>
> -- função anônima (ex.: dentro de task.spawn)
> task.spawn(function()
>     LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))
>     -- ...
> end)
> ```
>
> **3. O que proteger** (só o sensível, pra não pesar): remotes (resolução e
> `:FireServer`), lógica importante, visualização 3D / fly / pathfinding, ESP e
> previews 3D. **NÃO** proteja loops muito quentes (coisas chamadas centenas de
> vezes por frame ou por cálculo, tipo raycast/spherecast em laço apertado, ou
> callbacks de `RenderStepped`) — virtualizar isso trava o jogo.
>
> **4. REGRAS QUE NÃO PODEM SER QUEBRADAS:**
> - **NÃO** use `LPH_ENCFUNC(fn, chave, get_key())` nem chaves/`get_key`. Essa
>   forma antiga faz o Luraph moderno dar `Expected 'end' (got 'EOF')`. Use só
>   `LPH_ATTRIBUTES`.
> - `PRESET` só aceita: **FAST**, **BALANCED** ou **SECURE**. Nunca `STRONG`.
>   (`SECURE` = mais forte.)
> - Não mude a lógica, nomes, ordem das funções nem nada além de adicionar a
>   linha `LPH_ATTRIBUTES(...)` e o bloco do topo.
> - Não adicione nada que apague arquivos, trave a máquina (`while true do end`),
>   dê kick/shutdown, ou "retalie" quem inspeciona. Só proteção, nada destrutivo.
>
> **5. No final**, confira que a sintaxe Lua continua válida (quantidade de
> `function`/`end` e parênteses batendo) e me diga quais funções você protegeu.

---

## Resumo rápido (pra você)

| Quero… | Faço… |
|---|---|
| Rodar sem ofuscar pra testar | O bloco `if not LPH_OBFUSCATED` já deixa tudo no-op |
| Proteger uma função | 1ª linha dentro dela: `LPH_ATTRIBUTES(VM(ONYX), PRESET(SECURE))` |
| Mais velocidade | `PRESET(FAST)` ou `PRESET(BALANCED)` |
| Mais segurança | `PRESET(SECURE)` |

### Presets
- `FAST` — proteção leve, roda rápido.
- `BALANCED` — meio-termo.
- `SECURE` — mais forte, mais pesado (usado no jumpforeggs).

### Erros comuns do Luraph e causa
- `attribute PRESET must be one of FAST, BALANCED, SECURE` → você usou `STRONG`
  (ou outro nome). Troque por um dos três.
- `Expected 'end' (got 'EOF')` → provável uso de `LPH_ENCFUNC(... , chave, ...)`.
  Remova e use só `LPH_ATTRIBUTES`.
- `attempt to call a nil value (global 'VM')` ao rodar SEM ofuscar → faltou o
  bloco `if not LPH_OBFUSCATED` com os stubs de `VM`/`PRESET`.

> Obs.: os nomes de VM disponíveis (ex.: `ONYX`) podem variar conforme a sua
> licença/versão do Luraph. Se o Luraph reclamar do `VM(ONYX)`, troque pelo VM
> que a sua conta oferece.
