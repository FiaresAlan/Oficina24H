# C8 — Ledger persistente de créditos e recibos por perfil

**Estado:** código versionado, testes Luau e contrato CI escritos; testes Roblox Studio/servidor real ainda pendentes.
**Base:** `main` após C7, 12/11/2026.

## Meta
A C7 mantinha comprovantes por 15 minutos na memória de um servidor; após a troca de servidor ou reinício não havia como consultar um comprovante antigo. A C8 guarda no próprio perfil persistente a chave **JobId + token**, o valor pago, papel do recebedor, serviço/veículo e recibo sanitizado.

## Entrega implementada
- `SettlementLedgerRules`: chave por OS + GUID de sessão; no máximo 64 créditos por perfil; recibo anexado uma vez, cópias defensivas, rejeição de valores inválidos, saneamento ao carregar e lista pública sem GUID nem JobId.
- `DataService` schema v5: campo `RepairLedger` com reconcile. `CreditRepairOnce` só adiciona moedas quando o crédito da sessão ainda não existe no **mesmo perfil**. `AttachRepairReceipt` anexa o comprovante sem duplicação. `GetRepairReceipt`, `HasRepairCredit` e `RecentRepairSettlements` suportam consultas.
- `WorkshopService.FinishRepair`: checa previamente chaves já pagas; após a confirmação do serviço usa crédito protegido em vez do `AddCoins` direto; anexa os comprovantes de executor e proprietário conforme contrato. Tenta salvar os perfis envolvidos antes de emitir `RepairDone`.
- `CheckRepairOutcome` e repetição de `FinishRepair` consultam primeiro o recibo na memória e depois o perfil persistido, permitindo recuperar resultados após reconexão se o salvamento havia sido confirmado.
- `PersistenceTest` simula dois jogadores, dois servidores e novo carregamento de ambos os perfis, checando saldo, recibo e ausência de pagamento duplicado.
- `SettlementLedgerTest` cobre integridade, limites, retenção por quantidade, tipos inválidos e isolamento. `RunAllTests` e o CI incluem os contratos novos.

## Limites e riscos não resolvidos
1. **Não há transação atômica multi-jogador.** Um serviço com contratado credita dois perfis em chaves separadas do DataStore. Queda extrema entre salvamentos pode deixar um deles pendente. A C8 faz os melhores esforços de salvar ambos, mas **não oferece exactly-once durável de ponta a ponta**.
2. A tentativa `DataService.Save` pode falhar por indisponibilidade ou perda de lock. O jogo informa ao jogador para evitar sair; o autosave fará novas tentativas. Se o processo cair antes da confirmação de escrita, o resultado em memória pode ser perdido.
3. O histórico mantém **as últimas 64 chaves**, suficiente para sessão recente, não para auditoria financeira ilimitada. O cache de C7 continua com oito recibos/15 minutos para recuperação rápida.
4. Histórico anterior ao schema v5 não possui recibos retroativos. Nenhuma migração cria créditos históricos falsos.
5. O modo legado de timing continua usando crédito anterior, mas os 15 serviços normais têm planos Operations com token.

## QA / aceite pendente
- [ ] Rodar `RunAllTests` em Studio, incluindo `PersistenceTest` e `SettlementLedgerTest`.
- [ ] Reparar e salvar, sair do servidor, entrar em outro, recuperar comprovante da mesma sessão.
- [ ] Enviar `FinishRepair` repetido após salvar: saldo, estoque e XP não podem aumentar pela segunda vez.
- [ ] Validar contrato: dono e executor recebem somente sua parte, cada um com seu registro.
- [ ] Simular falha de `UpdateAsync`, perda de lock e desligamento do servidor no intervalo do pagamento.
- [ ] Testar dois jogadores executando e salvando simultaneamente; conferir ausência de corrupção.
- [ ] Validar clientes em Studio, touch e gamepad depois do salvamento síncrono.
- [ ] Verificar limites de DataStore, latência e orçamento de gravações; medir custo de salvamento por OS.
- [ ] Projetar mecanismo de compensação/recuperação multi-conta antes de declarar garantia financeira total.

**Integração de código ≠ homologação.** O CI de Rojo verifica estrutura, não os efeitos reais de falhas da plataforma.
