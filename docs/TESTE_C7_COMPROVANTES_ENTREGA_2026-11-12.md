# C7 — Comprovante de entrega e reconciliação de pagamentos

**Data:** 12/11/2026  
**Base:** `main` com C6 integrado  
**Branch:** `work/oficina24h-c7-conciliacao-entrega-2026-11-12`

## Falha de UX encontrada

Antes da C7, o servidor consumia a sessão de reparo antes de aplicar o pagamento, impedindo pagamentos duplicados, mas a interface só sabia se a OS havia terminado ao receber o evento `RepairDone`. Com a perda desse evento, a HUD podia encerrar a sessão sem apresentar o resultado, mesmo após creditar dinheiro e XP. Um reenvio de `FinishRepair` apenas recebia "Nenhum reparo em andamento", sem informar que a operação havia sido liquidada.

## Solução implementada

### Protocolo de entrega

1. `FinishRepair` valida a sessão de uso único, o token e o reparo; consome peças, atribui valores, XP, reputação e avaliação normalmente.
2. **Depois de aplicar os efeitos econômicos e antes do `RepairDone`**, o servidor registra um comprovante com `JobId`, `Token`, `Quality`, `Price`, `XP`, `Breakdown`, `Stars`, `Tip` e outros campos já produzidos pelo jogo.
3. `CheckRepairResult` é uma ação **somente leitura**, com limite de consultas. O servidor devolve um de quatro estados, sempre apenas para o próprio jogador e sessão:
   - `Completed`: comprovante disponível; HUD exibe o mesmo resultado original;
   - `Processing`: servidor já consumiu a sessão e está finalizando a entrega;
   - `Active`: sessão ainda está aberta; o cliente pode reenviar o **mesmo** `FinishRepair`;
   - `Unknown`: não há prova da liquidação na memória atual; não presumir pagamento nem falha.
4. Se `FinishRepair` chegar novamente após uma conclusão, o servidor procura o comprovante **antes** de qualquer outra operação; se o encontrar, retransmite `RepairDone` com os valores antigos e não adiciona moedas nem retira peças outra vez.
5. Ao enviar `FinishRepair`, a UI mantém a janela aberta e, após cinco segundos sem confirmação, consulta o comprovante. Consulta manual permanece disponível pelo botão "VERIFICAR ENTREGA". Em `Processing`, consulta novamente; em `Active`, retransmite o pacote original com limite de duas tentativas. Em `Unknown`, informa a incerteza sem alegar pagamento e mantém acesso ao painel de Ordens.

### Isolamento e memória

- `RepairReceiptRules` não permite leitura por `JobId` isolado: é preciso também o **token completo**, sob o `UserId` autenticado pela Roblox.
- Máximo de **oito** comprovantes recentes por jogador, com **15 minutos** de retenção no servidor atual; resultados são copiados para que o cliente não altere dados na cache.
- Consultas incorretas não retornam informação de outro mecânico, inclusive em OS delegada.
- `SettlingRepairs` mantém estado transitório de processamento e expira em 60 segundos em caso de falha inesperada.
- O sistema não muda o preço, o consumo de peças, o pagamento do contratado, a avaliação ou o fluxo de progressão existente.

### Alterações

| Arquivo | Função |
|---|---|
| `src/shared/RepairReceiptRules.lua` | Criação, consulta, expiração, cópia e limitação dos comprovantes |
| `src/server/WorkshopService.lua` | Registra comprovante após liquidação, reenvia comprovante e oferece `CheckRepairOutcome` |
| `src/server/Main.server.lua` | Rota de consulta com limite de frequência, sem alterar economia |
| `src/client/UI/Store.lua` | Evento `RepairOutcome` |
| `src/client/UI/OperationRepairGame.lua` | Recuperação da entrega sem reiniciar o pagamento cegamente |
| `tools/RepairReceiptTest.luau` | Regressão de conteúdo, imutabilidade, isolamento por token, TTL e limite |
| `tools/RunAllTests.luau`, `tools/ci/verify_contracts.py` | Registro e verificações estáticas em CI |

## Portões obrigatórios antes de publicação

- [ ] Executar todos os testes Luau no Studio, inclusive `RepairReceiptTest`.
- [ ] Testar pneu, bateria, motor e carroceria: concluir, receber pagamento e comprovante uma única vez.
- [ ] Simular perda apenas de `RepairDone`: `CheckRepairResult` deve recuperar os valores idênticos.
- [ ] Simular perda de `FinishRepair`: consulta retorna `Active`, retransmissão conclui **uma** vez.
- [ ] Simular interrupção durante o pagamento: consultar `Processing`, seguido de `Completed` ou `Unknown` com orientação consistente.
- [ ] Reenviar `FinishRepair` dezenas de vezes com token válido: não alterar saldo, estoque, XP e reputação após o primeiro pagamento.
- [ ] Usar token de outro jogador/OS: nenhuma informação financeira ou de sessão deve vazar.
- [ ] Testar contratos com 2 jogadores, repartição de moedas, saída do contratado e aviso ao proprietário.
- [ ] Validar consulta quando há uma nova sessão em andamento: comprovante antigo não pode cancelar a atual.
- [ ] Testar tela touch e gamepad, textos de incerteza e botão "VERIFICAR ENTREGA".
- [ ] Medir memória e limpar comprovantes após 15 min e saída de jogadores.

## Limites conhecidos

- **Comprovantes ficam em memória do servidor**, não são gravados no DataStore. Eles podem ser recuperados na mesma instância do servidor durante 15 minutos, mas **não sobrevivem à queda do processo nem garantem consulta entre servidores**. Uma garantia durável transacional de ponta a ponta exigirá contabilização de entrega no armazenamento persistente com estratégia de idempotência no DataStore.
- O histórico já persistido de ordens e transações ajuda uma investigação manual, mas não equivale a comprovante seguro para reexecutar pagamentos.
- CI Rojo não executa a física, multiplayer, remotes ou o DataStore real. Não marcar esses testes como aprovados sem resultados do Studio.

**Meta da fase:** reduzir entregas ambíguas na rede sem introduzir pagamentos repetidos ou novas ações financeiras no cliente.
