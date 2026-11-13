# C12/C13 — reivindicação durável e recuperação de pagamento colaborativo

Data: 13/11/2026. Código em `main` após validação do CI (não equivale a QA em Roblox Studio).

## C12 — preparar reivindicação antes de consumir peças
- Nova `shared/SettlementClaimRules.lua`: validação, sanitização, deduplicação e lista privada de até **64** reivindicações por contratado.
- `DataService` schema **v6** migra perfis legados e persiste `PendingClaims`. Cada claim contém UserId do proprietário, JobId/token, partes a pagar, serviço/veículo, XP e qualidade esperados. Não é replicada no snapshot.
- Em OS colaborativa com token, `WorkshopService.FinishRepair` **salva a reivindicação do mecânico antes** de consumir peças e distribuir créditos. Se o salvamento falhar, retorna falha sem consumir as peças nem pagar. A liquidação segue a sequência dono primeiro, contratado depois.
- Essa preparação não é uma dívida paga automaticamente: a autorização depende de crédito do proprietário no DataStore, nunca somente da palavra do contratado.

## C13 — recuperação após queda entre gravações
- No carregamento da conta e no ciclo de autosave, `ReconcileWorkerClaims` consulta o perfil **persistido do proprietário** via `GetAsync` para verificar a existência do mesmo JobId/token, papel Owner, valor, serviço e veículo.
- Só com essa prova faz `CreditRepairOnce` do contratado e `AddSkillXP` no mesmo perfil, com recibo mínimo. Persistência concluída antes de limpar a claim. Repetir ou reconectar não repete saldo/XP.
- O scanner é limitado a 8 claims por passagem; falha de leitura não é tratada como prova de pagamento.
- Testes escritos para: queda após salvar o dono, ausência de confirmação, valor/papel/serviço divergentes, leitura do DataStore falhando, repetição, migração v5→v6, limites e dados corrompidos. Conectados ao runner Luau e verificação estática do CI.

## Gates ainda obrigatórios (não executados neste ciclo)
1. Executar `RunAllTests` e `StudioPlaceAudit` com place real (e confirmar compilação Luau).
2. Teste servidor/cliente com duas contas: salvar claim → salvar dono → simular falha no salvamento do contratado → encerrar servidor → reconectar contratado. Conferir valor/XP/recibo/extrato e ausencia de duplicação.
3. Em outra execução, falhar **antes** de salvar dono: claim não pode render crédito, peças não devem ser consumidas.
4. Testar perda de lock, concorrência de autosave, latência e Budget/DataStore real; medir leitura de provas e fila de claims.
5. Verificar dispositivos móveis, 15 serviços, interação física/sons/artes e QA de publicação.

## Limites e riscos reais
- O mecanismo é **recuperação eventual**, não uma transação atômica entre duas chaves do DataStore. Se o proprietário só tiver parte da OS salva em memória, não existe prova válida de pagamento para o contratado. Não se pode afirmar atomicidade.
- Provas são baseadas no `RepairLedger` do dono (últimos 64 registros); se mais de 64 créditos novos substituírem a prova antes do mecânico reconectar, a reivindicação poderá ficar sem confirmação. Precisamos de arquivo de provas durável com retenção apropriada e política de limpeza/auditoria.
- XP/receita do contratado são reconciliados; efeitos auxiliares (missões, achievements, feedback visual, avaliação e consumíveis) ainda não são transacionados entre todos os serviços. O minijogo legado de timing ainda não usa GUID/claim.
- Preparações sem crédito do dono não autorizam pagamento e continuam na fila (máximo 64): exigem rotina administrativa de investigação/expiração para evitar acúmulo.
- Não houve execução no Studio, multiplayer real nem DataStore de produção.
