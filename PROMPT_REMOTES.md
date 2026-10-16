# Prompt: usar remotes de um jogo a partir de um dump

Cole isto junto com o dump (.zip) e o script quando for pedir código que chama uma remote.

---

Vou te mandar um dump de scripts do cliente (decompilados) e um script meu com uma parte vazia que precisa chamar uma remote. Siga estas regras:

1. **Ache a chamada original.** Procure no dump o controller/módulo que já chama essa remote (ex.: `TradeController.SendInvite`). Me mostre o trecho com o arquivo e a linha, incluindo o `InvokeServer`/`FireServer` exato.

2. **Reuse a instância que o jogo já tem. Não resolva a remote por conta própria.**
   - Não chame `Net:RemoteFunction(...)`, `Net:RemoteEvent(...)` nem nenhuma função de criar ou procurar remote do pacote de rede do jogo. Esses módulos podem ter anti-cheat, nomes ofuscados ou criar remotes falsas.
   - Faça `require` do módulo do jogo que já guarda a remote e leia ela com `debug.getupvalues` / `getupvalue` na função que a usa. O comentário `-- upvalues: (copy) v_u_40, ...` do dump mostra a ordem dos upvalues (índice 1 = primeiro da lista).
   - Prefira `getupvalues` e escolha o valor que for `Instance` e `IsA("RemoteFunction")` (ou `RemoteEvent`). Não confie só no índice fixo.

3. **Valide antes de usar.** Confira `typeof(remote) == "Instance"` e a classe certa. Se não achar, pare e mostre "Remote não encontrada". Nunca chame uma remote "parecida".

4. **Fallback só por nome exato.** Se fizer busca nas `GetChildren()`, compare o nome exato (ou o final exato, ex.: `"TradeService/Invite"`). Nunca use `find("invite")` genérico, porque pega `AcceptInvite`, `DeclineInvite` ou remotes-isca. Não varra o `ReplicatedStorage` inteiro com `GetDescendants`.

5. **Copie a chamada idêntica à do jogo.**
   - Mesmo método (`InvokeServer` vs `FireServer`).
   - Mesmo GUID/token como primeiro argumento, com o valor literal do dump.
   - Mesmos tipos e mesma ordem dos argumentos (ex.: `userId` como number, não string).
   - Nada de argumentos a mais.

6. **Respeite as condições do jogo.** Veja o que o código original checa antes de chamar (ex.: `canInvite`, `inGame`, cooldown, flags) e faça as mesmas checagens. Não dispare a remote em loop nem várias vezes por clique.

7. **Leia o retorno.** Trate o retorno do servidor do mesmo jeito que o jogo trata (ex.: `ok, err, id`). `pcall` ter dado certo não significa que o servidor aceitou.

8. **Procure anti-cheat no dump.** Busque `Kick(`, `FireServer(0/0)`, checagens de GUI/propriedades, `debug.info`, `getfenv` e checagens de quem chamou nos módulos envolvidos. Me avise se algo puder ser acionado pelo meu código.

9. **Não rode código do jogo a partir da thread do executor.** Alguns jogos varrem `getfenv(1..10)` procurando `cloneref`/`getrenv`/`getupvalues`/`getnamecallmethod` (no Steal a Brainrot: `PlotController.lua:94-117`). Qualquer função do jogo chamada pelo meu script (ex.: `Net:RemoteFunction(...)`, flags, helpers) pode achar o ambiente do executor na pilha e me denunciar. Só leia instâncias/upvalues e chame `InvokeServer`/`FireServer` diretamente. Em hooks, use `task.defer` antes de mexer em GUI ou chamar qualquer coisa.

10. **Diga o que não dá pra confirmar.** Se um módulo necessário não estiver no dump (ex.: `Packages/Net` faltando), diga isso. Não suponha como ele funciona.

11. **Explique na resposta:** de onde veio a remote (arquivo:linha), o GUID, os argumentos, e o que pode quebrar quando o jogo atualizar.
