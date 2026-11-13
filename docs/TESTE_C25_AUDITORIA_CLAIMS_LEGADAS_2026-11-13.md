# Oficina 24H — V1 C25 | Auditoria segura de reivindicações históricas

**Data:** 13/11/2026. **Situação:** código e documentação integráveis ao GitHub; testes do Roblox Studio e execução das suítes LuaU **não foram realizados** nesta rodada.

## Falha encontrada

Até a C24, `SettlementClaimRules.Authorized` tentava usar uma linha do `RepairLedger` do proprietário quando não encontrava `OwnerSettlementProofs` com JobId/token correspondentes. Essa compatibilidade atendia pagamentos antigos C12/C13, mas **a linha de ledger não identifica o WorkerUserId beneficiário**. Coincidência de JobId/token, valor, serviço e veículo não é comprovação suficiente para creditar o mecânico correto.

**C25 muda a política para falhar de forma segura:** nenhuma reivindicação é quitada automaticamente apenas por essa evidência incompleta. A reivindicação permanece, com motivo privado de auditoria. Não presumir quitação nem excluir a dívida.

## Alterações implementadas

1. **Regra rigorosa:** `SettlementClaimRules.EvidenceStatus` diferencia `Verified`, `LegacyUnverified`, `Conflict`, `Missing` e `Invalid`. Só `Verified` autoriza pagamento, exigindo prova válida do dono com **WorkerUserId exato** e JobId, token, parcelas, serviço e veículo iguais aos da reivindicação.
2. **Schema v11** adiciona `PendingClaimAudits` ao perfil privado do contratado, com no máximo 64 anotações por reivindicações ainda pendentes: JobId, token, proprietário, estado e data da checagem. Nada disso é enviado ao cliente.
3. **Reconciliação C25:** ao recuperar uma reivindicação, consulta `GetAsync` da conta do dono. Salva estados de conflito, falta de crédito, falha de leitura e legado sem prova vinculada. Não paga nem remove a reivindicação; status é atualizado após futuras verificações. Quando o crédito correto já existe ou a claim é descartada internamente, o registro de auditoria correspondente é removido no mesmo perfil.
4. **Contadores seguros:** `PendingClaimSummary` oferece apenas `NeedsReview`, `LegacyUnverified` e `Conflicts` para a interface, além das contagens anteriores de pendências. Nenhum token, ID de OS ou ID do proprietário é replicado. Logs do servidor alertam para casos antigos com contagens agregadas, sem divulgar os detalhes da reivindicação.
5. **Migração:** `SettlementClaimAuditRules.Sanitize` só preserva auditorias associadas a claims ainda existentes com mesmo proprietário. Campos inválidos e auditorias órfãs são descartados **sem apagar a própria claim**.
6. **Regressões:** `SettlementClaimRulesTest` testa vínculo correto/incorreto e ausência de proof; `SettlementClaimAuditRulesTest` testa marcação, mudança de status, persistência lógica, resumo e remoção. `PersistenceTest` inclui perfil v11, migração, falso destinatário, ledger legado sem proof, reconexão e falha `GetAsync`. `RunAllTests` e `verify_contracts.py` atualizados.

## Protocolo de auditoria operacional (manual, seguro)

- **1. Confirmar a existência da pendência:** em ambiente autorizado, verificar os registros privados da `PendingClaim` e o status `PendingClaimAudits`, sem expor tokens ao jogador ou copiar IDs para canais públicos.
- **2. Comparar evidências reais:** conferir o perfil persistido do dono (`OwnerSettlementProofs`, `RepairLedger`) e do trabalhador (`WorkerSettlementProofs`, `WorkerPaidTombstones`, `RepairLedger`, `PendingClaims`), com serviço, valor, token e identidade.
- **3. Classificar:** se a prova do dono identifica o beneficiário e o crédito do trabalhador não existe, a reconciliação normal pode tratar a operação. Se só houver ledger legado, **marcar para investigação**; não inferir beneficiário nem ressarcir sem prova independente.
- **4. Evitar intervenção não auditada:** não editar saldos DataStore manualmente, não descartar claims e não emitir pagamento fora do fluxo idempotente. **Não foi criada uma ferramenta administrativa de concessão nesta fase.**
- **5. Proteger privacidade:** registros detalhados só para suporte autorizado; resumos do cliente contêm apenas contagens.

## Homologação Roblox Studio ainda pendente

- [ ] Worker A e dono B com prova correta: recuperação uma vez, recibo e XP corretos, claim e auditoria removidas após `Save`.
- [ ] Owner tem apenas linha antiga de ledger: **sem crédito**, claim permanece e auditoria `LegacyUnverified` persiste após reconexão.
- [ ] Owner tem prova de OS/token correto, mas WorkerUserId de outra pessoa: **sem crédito**, auditoria `Conflict`.
- [ ] Sem evidência no dono: `Missing`. `GetAsync` falha: `ReadError`. Ambos sem pagamentos falsos.
- [ ] Sob dois servidores e falhas `UpdateAsync`, claims/auditorias permanecem consistentes, sem duplicar saldo ou XP.
- [ ] Abrir painéis de ordens em PC/mobile; dados de `PendingClaimAudits` e tokens nunca devem aparecer no cliente.
- [ ] Rodar `tools/RunAllTests.luau` e `StudioPlaceAudit` no Studio com assets reais.

## Limitações

- **Pagamentos legados sem prova vinculada não são reconstruíveis automaticamente.** C25 reduz risco de pagamento incorreto, mas mantém possível crédito legítimo pendente até auditoria com evidência externa confiável.
- Não há atomicidade distribuída entre duas chaves de usuário no DataStore. Tombstones e arquivos de prova possuem capacidade finita.
- A suíte Luau foi **escrita**, não executada no Studio; CI faz contratos estáticos e build Rojo.
- Os pacotes de assets já estão baixados e organizados, **aguardando importação** pelo proprietário. Nenhuma mecânica V2 foi implementada.

**Próxima pendência V1:** protocolo administrativo auditável de resolução de casos genuinamente ambíguos (com dupla evidência e sem pagamentos duplicados), além dos testes Studio e da integração/licença de assets.
