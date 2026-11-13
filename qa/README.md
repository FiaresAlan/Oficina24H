# Harness de QA no Roblox Studio (homologação V1)

Scripts de apoio usados via MCP do Studio (`execute_luau`). **Não fazem parte do jogo**: a pasta `qa/` fica fora do
`default.project.json` e nada aqui é sincronizado pelo Rojo.

| Arquivo | Onde roda | O que faz |
|---|---|---|
| `sync.luau` | Edit | Copia arquivos do repositório para o place aberto (`FILES = {...}`), lendo de `http://127.0.0.1:34999/` (`python -m http.server 34999 --bind 127.0.0.1` na raiz do repo). Só cria/atualiza scripts; **nunca apaga**. Módulos movidos/removidos precisam ser apagados à mão. |
| `run.luau` | Edit | Roda `SUITES` em sequência, cada uma com limite de `PERSUITE` s, numa cópia nova de `ReplicatedStorage.Shared` (mesmo método do `RunAllTests`). Resultados em `ServerStorage.QAResults`. Uma suíte travada vira `TIMEOUT` em vez de travar o runner. |
| `collect.luau` | Edit | Resume `ServerStorage.QAResults` (falhas por suíte; `FULL = "<suíte>"` devolve a saída inteira). |
| `setup_server.luau` | Server (Play) | ModuleScript. Conta de QA: moedas, oficina no nível máximo e XP nas 5 especializações, pelo `ServerStorage.QA` (só existe no Studio). |
| `drive_shop.luau` | Client (Play) | ModuleScript. Compra as 10 máquinas e as peças dos 15 serviços na Loja de Autopeças pelos remotes reais. |
| `drive_job.luau` | Client (Play) | ModuleScript. Joga uma OS inteira pelos remotes reais do HUD: aceite na TV, conversa, 9 exames, diagnóstico, preparo físico (ProximityPrompts), reparo na máquina, comandos com revisão/ACK, entrega e replay (não pode pagar duas vezes). |

`loadstring` e HTTP só funcionam no datamodel **Edit**. Para usar os módulos no Play, crie-os no Edit antes
(`ReplicatedStorage.QAScripts.drive_job`, `drive_shop`; `ServerStorage.setup_server`) e depois inicie o Play.
Os gabaritos dentro de `drive_job.luau` são conhecimento de QA copiado de `src/server/WorkshopProcedures.lua` e
`src/server/RepairOperations.lua`. Se o servidor recusar um comando, o relatório mostra a etapa que falhou.

Use **somente em place de QA** (cópia do place ou build só de código). Os comandos de QA (`ForceJob`, `SkillXP`,
`Coins`...) não existem fora do Studio.
