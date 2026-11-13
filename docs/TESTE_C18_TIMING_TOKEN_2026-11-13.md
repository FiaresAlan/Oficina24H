# V1 / C18 — token e liquidação durável para o minijogo de timing

Data: 13/11/2026. Código foi escrito no GitHub; **nenhum teste Luau foi executado no Studio nesta rodada**. CI verifica contratos estáticos, existência de suites e build Rojo, mas não simula a rede Roblox.

## Problema anterior
- `WorkshopService.StartRepair` fornecia GUID somente para planos do tipo `Operations`. O minijogo `Timing` tinha `Token=nil`.
- `FinishRepair` validava token somente para `Operations` e, em `Timing`, creditava diretamente sem ledger/comprovante durável, fazendo save “único” sem a proteção de reconciliação e replay.
- `RepairGame` (UI timing) enviava apenas tempos, cancelava sem JobId/token, fechava o painel após 4s de espera e aceitava eventos de resultado sem vincular à sessão.

## Ajustes C18
1. Toda sessão de reparo recebe GUID único do servidor e o mesmo é enviado à UI.
2. `RepairSessionRules.MatchesFinish` exige JobId/token para QUALQUER modalidade antes de consumir peças ou iniciar créditos. Cancelamento segue a mesma proteção.
3. `RepairGame` anexa `Token` ao pacote de tempos, sem alterar os índices numéricos; `RepairRules.Evaluate` continua avaliando os mesmos tempos.
4. A confirmação de reparos timing agora passa por `CreditRepairOnce`, `AttachRepairReceipt`, `SettlementDeliveryRules` e `persistDelivery`, incluindo reivindicação/reconciliação de contratado. **Removida a transferência direta** que não possuía idempotência.
5. UI timing correlaciona `RepairDone` ao JobId/token e consulta `CheckRepairResult` diante de atraso/erro. Não encerra automaticamente por 4s, o que poderia esconder uma entrega em processamento.
6. `RepairSessionTest` e `RepairTest` ganharam casos de GUID errado, sessão antiga/ausente, cancelamento protegido e preservação da pontuação de timing com token.

## Verificações para o Studio do proprietário (PENDENTES)
- Forçar plano timing num serviço de teste (sem alterar os 15 serviços oficiais que já possuem `Operations`).
- Realizar timing por PC/touch/gamepad e confirmar qualidade/idêntica, saldo único, consumo único, XP, avaliação, recibo e extrato após reconexão.
- Enviar `FinishRepair` com token antigo/ausente e cancelar com `JobId` errado; verificar que a sessão ativa não muda e nenhuma peça é consumida.
- Simular perda de `RepairDone`/ACK, atraso de 1s/5s, falha `UpdateAsync`, desconexão durante liquidação e recuperação de resultado por consulta com token.
- Testar um proprietário e um mecânico contratado: cada parcela deve ser salva e reconstituível, sem dupla concessão.
- Confirmar que nenhuma regressão ocorreu no UI `OperationRepairGame`, que já usava token.

## Riscos remanescentes V1
- A conta do proprietário e a do contratado permanecem chaves DataStore distintas. **Não existe atomicidade multi-perfil**; a reivindicação persistente tenta recuperar após falhas, mas provas têm retenção finita.
- Os 15 serviços do catálogo atual usam planos `Operations`; o caminho timing foi mantido para compatibilidade, não é uma experiência já homologada.
- Ainda precisam de auditoria os efeitos auxiliares do reparo, NPCs e compensações se o `Save` retornar falso após mutação em memória.
- As respostas de UI para conexão extremamente ruim exigem QA em dispositivo e atualização dos textos conforme o resultado.
