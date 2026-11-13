# C5 — Execução autoritativa das operações de reparo

**Data:** 12/11/2026  
**Branch de desenvolvimento:** `work/oficina24h-c5-repair-actions-server-2026-11-12` (criada a partir da `main` já atualizada pelo PR #20).  
**Status:** código e testes versionados; execução no Roblox Studio pendente.

## Problema corrigido

Até C4, o servidor validava o conteúdo do plano e o tempo final, mas aceitava um formulário completo `FinishRepair.Presses` produzido integralmente no cliente. Um cliente adulterado poderia enviar respostas corretas e aguardar o tempo mínimo sem realizar os gestos mecânicos.

C5 introduz um **protocolo incremental** para as operações dos 15 serviços.

## Fluxo

1. `StartRepair` cria sessão única por jogador com `Token` GUID, `StartedAt`, plano secreto e `Progress` server-side.
2. A UI recebe apenas plano público e token. Cada botão (escolha de componente, ajuste, passo, reset) envia **`RepairAction`** com `JobId`, `Token`, `Revision`, `Kind`, `Id` e `Value`.
3. `WorkshopService.RepairAction` confirma dono/responsável, proximidade, equipamento, estoque, tempo, limite de comandos e revisão. `RepairActionRules.Apply` aceita somente a próxima ação válida e atualiza o estado do servidor.
4. Servidor responde `RepairActionAck` com `Accepted`, `Revision` e `Token`. A UI só atualiza seus valores após a confirmação. Em perda da confirmação, cancela a sessão para evitar divergência.
5. Em `FinishRepair`, o token deve ser o da sessão atual. **Para operações, o servidor ignora todos os campos de nota/resposta do cliente**, reconstrói o input de `RepairActionRules.FinalInput` e usa `RepairOperations.Evaluate`. Peças/pagamento/XP continuam na cadeia server-side original.
6. A sessão é consumida uma única vez. Um token antigo não cancela um reparo atual.

## Suporte por especialização

| Família | Ações confirmadas |
|---|---|
| Pneu | Selecionar região do vazamento; alterar pressão em passos de 2 psi |
| Bateria | 4 terminais únicos e botão de reinício |
| Arrefecimento | Ajustar fluido em 0,25 L; sangria em ciclos; testar ventoinha |
| Montagem | Selecionar cada etapa distinta na sequência; reiniciar ordem |
| Calibração | Ajustar cada campo nos incrementos definidos pelo plano |
| Circuito | Selecionar um circuito real e uma intervenção existente |
| Carroceria | Ajustar as três regiões em níveis discretos de 0 a 3 |

O protocolo limita o total de operações por sessão (64) e impõe intervalo mínimo de 70 ms no servidor. O contador de revisão impede repetições, salto de número e ações fora de ordem.

## Arquivos

- `src/shared/RepairActionRules.lua`: estado, protocolo, limites, validação e reconstrução de input, em código puro.
- `src/server/WorkshopService.lua`: token/sessão, `RepairAction` server-side, término baseado somente no estado registrado.
- `src/server/Main.server.lua`: roteamento de ação com confirmação dedicada, sem descartar cliques pelo rate limit global.
- `src/client/UI/Store.lua`: distribui `RepairActionAck`.
- `src/client/UI/OperationRepairGame.lua`: todos os 7 modos agora aguardam confirmação do servidor antes de atualizar a interface.
- `tools/RepairActionRulesTest.luau`: regressões de pressão, sequência, reajuste, tipos, limites, replay e comandos incorretos.
- `tools/RunAllTests.luau` e `tools/ci/verify_contracts.py`: registros de teste e verificação estrutural do protocolo.

## Critérios de aceitação — pendentes no Studio

- [ ] Executar `RunAllTests` e confirmar zero falhas.
- [ ] Jogar os 15 serviços com os botões da UI. Cada ação deve confirmar antes da próxima e a qualidade depender da sequência executada.
- [ ] Simular 200 ms e 600 ms de ping, reconexão e pacote atrasado; verificar nenhum avanço fantasma.
- [ ] Atacar `FinishRepair` sem `RepairAction`; deve recusar sem pagar.
- [ ] Enviar revisões repetidas, IDs falsos e valores fora dos passos; recusar sem alterar progresso.
- [ ] Enviar token antigo depois de reiniciar: não alterar nem cancelar o reparo novo.
- [ ] Tentar ações longe do carro ou do equipamento; o servidor deve recusar.
- [ ] Testar dois jogadores, colaboração e cancelamento de OS sem pagamento duplicado.
- [ ] Testar 320×568, 390×844, paisagem, teclado e gamepad: nenhum toque perdido sem feedback.
- [ ] Testar a duração máxima (90s), limite de 64 comandos, queda de rede, timeout de confirmação.
- [ ] Conferir o minijogo `RepairGame.lua` legado para não quebrar compatibilidade com defeitos futuros.

## Limites honestos

Este protocolo **não prova que uma pessoa real executou os comandos**: automações ainda podem enviar sequências válidas com intervalos plausíveis. Ele impede, no entanto, a aprovação apenas com um pacote final arbitrário e mantém uma sequência server-side verificável. O minijogo antigo de timing continua usando a validação anterior. Não foi possível observar a execução real em Studio nesta sessão; validações de Luau, latência e game feel permanecem abertas.
